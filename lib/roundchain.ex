defmodule Hashpay.Roundchain do
  @moduledoc false

  use GenServer
  require Logger

  alias Hashpay.{
    Variable,
    Currency,
    Validator,
    ValidatorName,
    Account,
    AccountName,
    Merchant,
    MerchantName,
    Balance,
    Member,
    Plan,
    Payday,
    Paystream,
    Holding,
    Lottery,
    LotteryTicket,
    Round,
    Block,
    Property,
    GovProposal
  }

  @round_time Application.compile_env(:hashpay, :round_time, 500)
  @round_timeout Application.compile_env(:hashpay, :round_timeout, 1_500)

  ## Public API

  @doc """
  Read data from cache.
  """
  def process(event_shadow) do
    GenServer.cast(__MODULE__, {:event, event_shadow})
  end

  ## Callbacks

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  defmodule State do
    defstruct [
      :id,
      :prev,
      :turnof,
      :db,
      :blocks,
      :pubkey,
      :privkey,
      :sync_state,
      :me,
      :commands,
      :tref,
      :vrounds
    ]

    def new(db, vid, seed) do
      me =
        case Validator.get(db, vid) do
          {:ok, validator} -> validator
          _not_found -> nil
        end

      {:ok, {pubkey, privkey}} = Cafezinho.Impl.keypair_from_seed(seed)
      last_round = Round.last(db) || %{id: -1}

      %__MODULE__{
        id: last_round.id + 1,
        prev: last_round,
        turnof: nil,
        db: db,
        blocks: [],
        me: me,
        pubkey: pubkey,
        privkey: privkey,
        sync_state: :syncing,
        tref: nil,
        vrounds: :ets.new(:virtual_rounds, [:bag]),
        commands: :ets.new(:commands, [:ordered_set])
      }

      # |> put_next_validator()
    end

    def next_round(state = %__MODULE__{id: id}, round) do
      %{state | id: id + 1, prev: round}
    end

    def put_next_validator(state = %__MODULE__{db: db, id: round_id}) do
      total = Validator.total(db)
      hash = Hashpay.hash("the next round ##{round_id} goes to") |> :binary.decode_unsigned()
      i = rem(hash, total)
      validator = Validator.slot(db, i)

      %{state | turnof: validator}
    end

    def add_virtual_round(%__MODULE__{vrounds: vrounds, turnof: turnof}, round)
        when round.creator == turnof.id do
      key = {round.id, round.hash}

      :ets.lookup(vrounds, round.id)
      |> case do
        [] -> :ets.insert(vrounds, {key, round, 1})
        [{^key, _, count}] -> :ets.update_element(vrounds, key, {3, count + 1})
      end
    end

    def add_virtual_round(state, _round), do: state

    def get_most_voted_round(%__MODULE__{vrounds: vrounds, id: round_id}) do
      result =
        :ets.foldl(
          fn
            {key = {rid, _rhash}, round, count}, acc when rid == round_id ->
              :ets.delete(vrounds, key)

              if count > acc.count do
                %{round: round, count: count}
              else
                acc
              end

            _, acc ->
              acc
          end,
          %{round: nil, count: 0},
          vrounds
        )

      result.round
    end
  end

  @doc false
  @impl true
  def init(_opts) do
    vid = Application.get_env(:hashpay, :id)
    seed = Application.get_env(:hashpay, :privkey)

    EventBus.subscribe(
      {__MODULE__,
       [
         :round_start,
         :round_created,
         :round_received,
         :round_published,
         :round_verified,
         :round_failed,
         :round_started,
         :round_timeout,
         :round_skipped,
         :round_ended,
         :validator_created,
         :validator_updated,
         :validator_deleted
       ]}
    )

    tr = load_db()
    state = State.new(tr, vid, seed)

    {:ok, state, {:continue, :start}}
  end

  @impl true
  def handle_continue(:start, state) do
    tref = Process.send_after(self(), :round_time, @round_time)

    {:noreply, %{state | tref: tref}}
  end

  @impl true
  def handle_info(:round_time, state) do
    tref = Process.send_after(self(), :round_timeout, @round_timeout)

    {:noreply, %{state | tref: tref}}
  end

  @impl true
  def handle_info(:round_timeout, state) do
    tref = Process.send_after(self(), :round_time, @round_time)

    {:noreply, %{state | tref: tref}}
  end

  @doc false
  @impl true
  def handle_cast({:event, event_shadow = {topic, id}}, state) do
    # Fetch event
    event_data = EventBus.fetch_event_data(event_shadow)

    new_state =
      case topic do
        :round_start ->
          on_round_start(event_data, state)

        :round_created ->
          on_round_created(event_data, state)

        :round_published ->
          on_round_published(event_data, state)

        :round_received ->
          round = Round.to_struct(event_data)
          on_round_received(round, state)

        :round_verified ->
          round = Round.to_struct(event_data)
          on_round_verified(round, state)

        :round_failed ->
          round = Round.to_struct(event_data)
          on_round_failed(round, state)

        :round_started ->
          on_round_started(event_data, state)

        :round_timeout ->
          on_round_timeout(event_data, state)

        :round_skipped ->
          on_round_skipped(event_data, state)

        :round_ended ->
          on_round_ended(event_data, state)

        :validator_created ->
          on_validator_created(event_data, state)

        :validator_updated ->
          on_validator_updated(event_data, state)

        :validator_deleted ->
          on_validator_deleted(event_data, state)
      end

    EventBus.mark_as_completed({__MODULE__, topic, id})
    {:noreply, if(is_map(new_state), do: new_state, else: state)}
  end

  @doc false
  @impl true
  def terminate(reason, _state) do
    IO.puts("Roundchain terminated: #{inspect(reason)}")
    EventBus.unsubscribe(__MODULE__)
  end

  defp on_round_start(event_data, state) do
    Logger.info("Round start: #{inspect(event_data)}")

    new_state =
      state
      |> State.put_next_validator()

    RoundTimer.start_round_time()

    new_state
  end

  defp on_round_created(event_data, _state) do
    Logger.info("Round created: #{inspect(event_data)}")
    RoundTimer.finish_round_timeout()
  end

  defp on_round_published(event_data, _state) do
    Logger.info("Round published: #{inspect(event_data)}")
  end

  defp on_round_received(
         round = %Round{creator: creator_id},
         %State{db: _db, prev: prev_round} = state
       ) do
    Logger.info("Round received: #{inspect(round)}")
    RoundTimer.finish_round_timeout()

    try do
      case Validator.get(creator_id, prev_round) do
        {:ok, validator} ->
          case Round.validate(round, validator.pubkey) do
            {:ok, round} ->
              on_round_verified(round, state)

            _error ->
              on_round_failed(round, state)
          end

        error ->
          error
      end
    rescue
      _ ->
        on_round_failed(round, state)
    end
  end

  defp on_round_verified(%{blocks: _blocks} = round, _state) do
    Logger.info("Round verified: #{inspect(round)}")
  end

  defp on_round_failed(event_data, _state) do
    Logger.info("Round failed: #{inspect(event_data)}")
  end

  defp on_round_started(event_data, _state) do
    Logger.info("Round started: #{inspect(event_data)}")
  end

  defp on_round_timeout(event_data, _state) do
    Logger.info("Round timeout: #{inspect(event_data)}")
  end

  defp on_round_skipped(event_data, _state) do
    Logger.info("Round skipped: #{inspect(event_data)}")
  end

  defp on_round_ended(event_data, _state) do
    Logger.info("Round ended: #{inspect(event_data)}")
  end

  defp on_validator_created(event_data, _state) do
    Logger.info("Validator created: #{inspect(event_data)}")
  end

  defp on_validator_updated(event_data, _state) do
    Logger.info("Validator updated: #{inspect(event_data)}")
  end

  defp on_validator_deleted(event_data, _state) do
    Logger.info("Validator deleted: #{inspect(event_data)}")
  end

  defp load_db do
    tr =
      ThunderRAM.new(
        name: :blockchain,
        filename: ~c"priv/data/blockchain",
        modules: [
          Variable,
          Round,
          Block,
          Account,
          AccountName,
          Balance,
          Currency,
          Validator,
          ValidatorName,
          Merchant,
          MerchantName,
          Member,
          Plan,
          Payday,
          Paystream,
          Holding,
          Lottery,
          LotteryTicket,
          Property,
          GovProposal
        ]
      )

    Variable.init(tr)
    Currency.init(tr)
    Validator.init(tr)

    tr
  end
end
