defmodule RoundEventConsumer do
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
    Property
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
      :hash,
      :prev_hash,
      :db,
      :blocks,
      :tref
    ]
  end

  @doc false
  @impl true
  def init(_opts) do
    EventBus.subscribe(
      {__MODULE__,
       [
         :round_created,
         :round_published,
         :round_received,
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
    round_id = Hashpay.get_last_round_id()

    state = %State{
      id: round_id,
      hash: nil,
      prev_hash: nil,
      db: tr,
      blocks: []
    }

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

    case topic do
      :round_created ->
        on_round_created(event_data, state)

      :round_published ->
        on_round_published(event_data, state)

      :round_received ->
        on_round_received(event_data, state)

      :round_verified ->
        on_round_verified(event_data, state)

      :round_failed ->
        on_round_failed(event_data, state)

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
    {:noreply, state}
  end

  @doc false
  @impl true
  def terminate(reason, _state) do
    IO.puts("RoundEventConsumer terminated: #{inspect(reason)}")
    EventBus.unsubscribe(__MODULE__)
  end

  defp on_round_created(event_data, _state) do
    Logger.info("Round created: #{inspect(event_data)}")
  end

  defp on_round_published(event_data, _state) do
    Logger.info("Round published: #{inspect(event_data)}")
  end

  defp on_round_received(event_data, _state) do
    Logger.info("Round received: #{inspect(event_data)}")
  end

  defp on_round_verified(event_data, _state) do
    Logger.info("Round verified: #{inspect(event_data)}")
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
          Property
        ]
      )

    Variable.init(tr)
    Currency.init(tr)

    tr
  end
end
