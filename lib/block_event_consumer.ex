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
  def handle_cast({:event, event_shadow = {topic, id}}, state) do
    # Fetch event
    # event = EventBus.fetch_event({topic, id})
    event_data = EventBus.fetch_event_data(event_shadow)

    case topic do
      :block_creating ->
        on_block_creating(event_data, state)

      :block_created ->
        on_block_created(event_data, state)

      :block_uploaded ->
        on_block_uploaded(event_data, state)

      :block_published ->
        on_block_published(event_data, state)

      :block_received ->
        on_block_received(event_data, state)

      :block_downloaded ->
        on_block_downloaded(event_data, state)

      :block_verifying ->
        on_block_verifying(event_data, state)

      :block_failed ->
        on_block_failed(event_data, state)

      :block_completed ->
        on_block_completed(event_data, state)
    end

    EventBus.mark_as_completed({MyFifthConsumer, topic, id})
    {:noreply, state}
  end

  defp on_block_creating(event_data, _state) do
    Logger.info("Block creating: #{inspect(event_data)}")
  end

  defp on_block_created(event_data, _state) do
    Logger.info("Block created: #{inspect(event_data)}")
  end

  defp on_block_uploaded(event_data, _state) do
    Logger.info("Block uploaded: #{inspect(event_data)}")
  end

  defp on_block_published(event_data, _state) do
    Logger.info("Block published: #{inspect(event_data)}")
  end

  defp on_block_received(event_data, _state) do
    Logger.info("Block received: #{inspect(event_data)}")
  end

  defp on_block_downloaded(event_data, _state) do
    Logger.info("Block downloaded: #{inspect(event_data)}")
  end

  defp on_block_verifying(event_data, _state) do
    Logger.info("Block verifying: #{inspect(event_data)}")
  end

  defp on_block_failed(event_data, _state) do
    Logger.info("Block failed: #{inspect(event_data)}")
  end

  defp on_block_completed(event_data, _state) do
    Logger.info("Block completed: #{inspect(event_data)}")
  end
end
