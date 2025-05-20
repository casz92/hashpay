defmodule Hashpay.Roundchain do
  @moduledoc false

  use GenServer
  require Logger

  alias Hashpay.{PubSub, Blockfile}

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

  @round_time Application.compile_env(:hashpay, :round_time)
  @default_channel Application.compile_env(:hashpay, :default_channel)
  @default_currency Application.compile_env(:hashpay, :default_currency)
  @supply "@supply"

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
      :candidates,
      :validators,
      :pubkey,
      :privkey,
      :replicants,
      :sync_state,
      :me,
      :commands,
      :vrounds,
      :myheight,
      :myturn
    ]

    def new(db, vid, seed) do
      me =
        case Validator.get(db, vid) do
          {:ok, validator} -> validator
          _not_found -> nil
        end

      {:ok, {pubkey, privkey}} = Cafezinho.Impl.keypair_from_seed(seed)
      last_round = Round.last(db) || %{id: -1, hash: nil}

      # Load active validators
      validators = :ets.new(:validators, [:ordered_set])

      Validator.foreach(db, fn id, validator ->
        if String.first(id) != "$" and validator.active do
          :ets.insert(validators, {id, validator})
        end
      end)

      %__MODULE__{
        id: last_round.id + 1,
        prev: last_round,
        turnof: nil,
        db: db,
        candidates: :ets.new(:candidates, [:set, :named_table, :public]),
        validators: validators,
        me: me,
        pubkey: pubkey,
        privkey: privkey,
        replicants: :ets.new(:replicants, [:set, :named_table, :public]),
        sync_state: :syncing,
        vrounds: :ets.new(:virtual_rounds, [:bag]),
        commands: :ets.new(:commands, [:ordered_set])
      }
    end

    def next_round(state = %__MODULE__{id: id}, round) do
      %{state | id: id + 1, prev: round}
    end

    def put_next_validator(
          state = %__MODULE__{db: db, id: round_id, me: me, validators: validators}
        ) do
      total = Validator.total(db)
      if total == 0, do: raise("No validators")
      hash = Hashpay.hash("the next round ##{round_id} goes to") |> :binary.decode_unsigned()
      i = rem(hash, total)
      [{_validator_id, validator}] = :ets.slot(validators, i)

      %{state | turnof: validator, myturn: me != nil and validator.id == me.id}
    end

    def has_virtual_round(state, round) do
      key = {round.id, round.hash}
      :ets.member(state.vrounds, key)
    end

    def add_virtual_round(
          %__MODULE__{validators: validators, vrounds: vrounds, turnof: turnof},
          round,
          from_id
        )
        when round.creator == turnof.id do
      key = {round.id, round.hash}

      result =
        :ets.lookup(vrounds, round.id)
        |> case do
          [] ->
            :ets.insert(vrounds, {key, round, MapSet.new([from_id]), 1})
            1

          [{^key, _, unique_voters, count}] ->
            if not MapSet.member?(unique_voters, from_id) do
              result = count + 1

              :ets.update_element(vrounds, key, [
                {3, MapSet.put(unique_voters, from_id)},
                {4, result}
              ])

              result
            else
              count
            end
        end

      # check votes
      total = :ets.info(validators, :size)
      min_votes = quorum_fn(total)

      if result >= min_votes do
        Logger.debug("Round ##{round.id} has enough votes")
        :ok
      else
        :skip
      end
    end

    def add_virtual_round(_state, _round, _from), do: :skip

    def clean_vrounds(state = %__MODULE__{vrounds: vrounds, id: round_id}) do
      :ets.foldl(
        fn
          {key = {rid, _rhash}, _round, _voters, _count}, acc when rid <= round_id ->
            :ets.delete(vrounds, key)
            acc

          _, acc ->
            acc
        end,
        [],
        vrounds
      )

      state
    end

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

    @max_block_size 4 * 1024 * 1024
    def get_commands(%__MODULE__{commands: commands}) do
      do_get_commands(commands, :ets.first(commands), 0, [])
    end

    defp do_get_commands(ets, key, size, acc) do
      case :ets.lookup(ets, key) do
        [{^key, item}] ->
          new_size = size + item.size
          :ets.delete(ets, key)

          if new_size >= @max_block_size do
            {acc, new_size}
          else
            do_get_commands(ets, :ets.next(ets, key), new_size, [item | acc])
          end

        _ ->
          {acc, size}
      end
    end

    @quorum_config Application.compile_env(:hashpay, :quorum)
    @quorum_type Keyword.get(@quorum_config, :type, "majority")
    @quorum_limit Keyword.get(@quorum_config, :limit, 20_000)

    case @quorum_type do
      "1/3" ->
        def quorum_fn(total), do: min(div(total, 3), @quorum_limit)

      "majority" ->
        def quorum_fn(total), do: min(div(total, 2) + 1, @quorum_limit)

      "relative" ->
        def quorum_fn(total), do: min(div(total, 3) + 1, @quorum_limit)

      "2/3" ->
        def quorum_fn(total), do: min(div(total, 3) * 2, @quorum_limit)

      "3/4" ->
        def quorum_fn(total), do: min(div(total, 4) * 3, @quorum_limit)

      "absolute" ->
        def quorum_fn(total), do: total

      _ ->
        raise("Invalid quorum type")
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
         :round_received,
         :round_published,
         :round_verified,
         :round_failed,
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

    load_replicants()

    {:ok, state, {:continue, :start}}
  end

  def load_replicants do
    replicants =
      if File.exists?("replicants.hosts") do
        File.read!("replicants.hosts")
        |> String.split("\n")
        |> Enum.map(&String.trim/1)
        |> Enum.filter(&(&1 != ""))
        |> Enum.uniq()
      else
        Logger.warning("No replicants.hosts file found")
        []
      end

    :ets.delete_all_objects(:replicants)

    replicants
    |> Enum.each(fn hostname ->
      :ets.insert(:replicants, {hostname, %{}})
    end)

    Logger.info("Replicants loaded: #{length(replicants)}")
  end

  @impl true
  def handle_continue(:start, state) do
    {:noreply, on_round_start(state)}
  end

  @doc false
  @impl true
  def handle_cast({:event, event_shadow = {topic, id}}, state) do
    # Fetch event
    event_data = EventBus.fetch_event_data(event_shadow)

    new_state =
      case topic do
        :round_start ->
          on_round_start(state)

        :round_published ->
          on_round_published(event_data, state)

        :round_received ->
          from = event_data["from"]
          round = event_data["round"] |> Round.to_struct()
          from_signature = event_data["signature"]
          on_round_received(round, from, from_signature, state)

        :round_verified ->
          round = Round.to_struct(event_data)
          on_round_verified(round, state)

        :round_failed ->
          round = Round.to_struct(event_data)
          on_round_failed(round, state)

        :round_timeout ->
          on_round_timeout(state)

        :round_skipped ->
          on_round_skipped(state)

        :round_ended ->
          round = Round.to_struct(event_data)
          on_round_ended(round, state)

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
    Logger.debug("Roundchain terminated: #{inspect(reason)}")
    EventBus.unsubscribe(__MODULE__)
  end

  defp on_round_start(state = %State{db: db, privkey: privkey}) do
    Logger.debug("Round start: ##{inspect(state.id)}")

    new_state =
      state
      |> State.put_next_validator()

    if new_state.myturn do
      {commands, _size} = State.get_commands(new_state)
      cmds_count = length(commands)

      if cmds_count == 0 do
        :timer.sleep(@round_time - 100)
        on_round_skipped(new_state)
      else
        Blockfile.build(new_state.id, commands)

        blocks = [
          Block.new(
            %{
              id: new_state.myheight,
              creator: new_state.turnof.id,
              channel: @default_channel,
              height: new_state.myheight,
              prev: new_state.prev.hash,
              count: cmds_count,
              rejected: 0,
              size: Enum.sum(Enum.map(commands, & &1.size)),
              status: 1
            },
            privkey
          )
        ]

        round =
          Round.new(
            %{
              id: new_state.id,
              prev: new_state.prev.hash,
              creator: new_state.turnof.id,
              count: length(blocks),
              txs: Enum.sum(Enum.map(blocks, & &1.count)),
              size: Enum.sum(Enum.map(blocks, & &1.size)),
              status: 0,
              blocks: Enum.map(blocks, & &1.hash)
            },
            privkey
          )

        db = ThunderRAM.new_batch(db)
        round = round_reward(db, round)
        Round.put(db, round)

        for block <- blocks do
          Block.put(db, block)
        end

        # EventBus.notify(%Event{
        #   id: :round_created,
        #   topic: :round_created,
        #   data: round
        # })

        publish_round_created(round)

        %{new_state | db: db}
      end
    else
      RoundTimer.start_round_time()
      new_state
    end
  end

  defp on_round_published(event_data, _state) do
    Logger.debug("Round published: #{inspect(event_data)}")
  end

  defp on_round_received(
         round = %Round{creator: creator_id},
         from_id,
         from_signature,
         %State{db: db, prev: prev_round, me: me} = state
       )
       when creator_id != me.id do
    Logger.debug("Round received: ##{inspect(round.id)} | #{inspect(round.creator)}")
    RoundTimer.finish_round_timeout()

    try do
      {:ok, creator} = Validator.get(db, creator_id)
      {:ok, from} = Validator.get(db, from_id)

      case Cafezinho.Impl.verify(from_signature, round.hash, from.pubkey) do
        true ->
          publish_round_received(round)

          if not State.has_virtual_round(state, round) do
            round =
              case Round.validate(round, prev_round, creator.pubkey) do
                {:ok, round} ->
                  on_round_verified(round, state)

                _error ->
                  on_round_failed(round, state)
              end

            if State.add_virtual_round(state, round, from_id) == :ok do
              on_round_accepted(round, state)
            end
          end

        _error ->
          :ok
      end
    rescue
      _ ->
        :ok
    end
  end

  defp on_round_received(_round, _from_id, _signature, _state), do: :ok

  defp on_round_accepted(round, state = %State{db: db}) do
    # Logger.debug("Round accepted: ##{inspect(round.id)}")
    db = ThunderRAM.new_batch(db)
    round = %{round | status: 1}
    Round.put(db, round)
    new_state = %{state | db: db}
    on_round_ended(round, new_state)
  end

  defp on_round_verified(round, _state) do
    Logger.debug("Round verified: #{inspect(round.id)}")
    # db = ThunderRAM.new_batch(db)
    # Round.put(db, round)
    # new_state = %{state | db: db}
    # on_round_ended(round, new_state)
    round
  end

  defp on_round_failed(round, _state) do
    Logger.debug("Round failed: ##{inspect(round.id)}")
    Round.new_cancelled(round)
  end

  defp on_round_timeout(state = %State{db: db}) do
    Logger.debug("Round timeout: ##{inspect(state.id)}")

    db = ThunderRAM.new_batch(db)
    round = Round.new_timeout(state.id, state.prev.hash, state.turnof.id)
    Round.put(db, round)
    new_state = %{state | db: db}
    publish_round_timeout(round)
    on_round_ended(round, new_state)
  end

  defp on_round_skipped(state = %State{db: db, me: me}) do
    # Logger.debug("Round skipped: ##{inspect(state.id)}")

    db = ThunderRAM.new_batch(db)
    round = Round.new_skipped(state.id, state.prev.hash, state.turnof.id, state.privkey)
    Round.put(db, round)
    new_state = %{state | db: db}

    publish_round_created(round)

    if State.add_virtual_round(new_state, round, me.id) == :ok do
      on_round_accepted(round, new_state)
    end
  end

  defp on_round_ended(round, state = %State{db: db}) do
    Logger.info("Round ended: \e[31m##{inspect(state.id)}\e[0m")

    new_state =
      %{state | db: ThunderRAM.sync(db)}
      |> State.next_round(round)
      |> State.clean_vrounds()

    on_round_start(new_state)
  end

  defp on_validator_created(event_data, _state) do
    Logger.debug("Validator created: #{inspect(event_data)}")
  end

  defp on_validator_updated(event_data, _state) do
    Logger.debug("Validator updated: #{inspect(event_data)}")
  end

  defp on_validator_deleted(event_data, _state) do
    Logger.debug("Validator deleted: #{inspect(event_data)}")
  end

  defp publish_round_created(round) do
    PubSub.broadcast_from(@default_channel, %{"event" => "round_created", "data" => round})
  end

  defp publish_round_received(round) do
    PubSub.broadcast_from(@default_channel, %{"event" => "round_received", "data" => round})
  end

  defp publish_round_timeout(round) do
    PubSub.broadcast_from(@default_channel, %{"event" => "round_timeout", "data" => round})
  end

  defp round_reward(_db, round) when round.reward == 0 do
    round
  end

  defp round_reward(db, round) do
    Logger.debug("Round reward: #{inspect(round.reward)}")

    case Currency.get(db, @default_currency) do
      {:ok, currency} ->
        max_supply = currency.max_supply
        amount = round.reward

        case Balance.incr_limit(db, currency.id, @supply, amount, max_supply) do
          {:ok, _new_amount} ->
            Balance.incr(db, round.creator, @default_currency, round.reward)
            round

          _error ->
            %{round | reward: 0}
        end

      _error ->
        %{round | reward: 0}
    end
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
