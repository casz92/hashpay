defmodule RoundEventConsumer do
  @moduledoc false

  use GenServer
  require Logger

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

    {:ok, []}
  end

  @doc false
  @impl true
  def handle_cast({:event, event_shadow = {topic, id}}, state) do
    # Fetch event
    event_data = EventBus.fetch_event_data(event_shadow)
    Logger.info(fn -> inspect(event_data) end)

    EventBus.mark_as_completed({__MODULE__, topic, id})
    {:noreply, state}
  end

  @doc false
  @impl true
  def terminate(reason, _state) do
    IO.puts("RoundEventConsumer terminated: #{inspect(reason)}")
    EventBus.unsubscribe(__MODULE__)
  end
end
