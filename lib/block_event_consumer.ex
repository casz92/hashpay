defmodule BlockEventConsumer do
  @moduledoc false

  use GenServer
  require Logger

  ## Public API

  @doc """
  Read data from cache.
  """
  def process({_topic, _id} = event_shadow) do
    :poolboy.transaction(:event_consumer_pool, fn worker ->
      GenServer.cast(worker, {:event, event_shadow})
    end)
  end

  ## Callbacks

  @doc false
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  @doc false
  def init(_opts) do
    {:ok, []}
  end

  @doc false
  def handle_cast({:event, {topic, id}}, state) do
    # Fetch event
    event = EventBus.fetch_event({topic, id})

    # Do sth with the event
    # Or just log for the sample
    Logger.info("I am handling the event with :poolboy #{__MODULE__}")
    Logger.info(fn -> inspect(event) end)

    EventBus.mark_as_completed({MyFifthConsumer, topic, id})
    {:noreply, state}
  end
end
