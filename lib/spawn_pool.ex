defmodule SpawnPool.Supervisor do
  use DynamicSupervisor

  def start_link(name, opts) do
    DynamicSupervisor.start_link(__MODULE__, opts, name: name)
  end

  def init(_opts) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end

defmodule SpawnPool do
  require Logger
  @supervisor_name SpawnPool.Supervisor

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor,
      restart: :permanent,
      shutdown: 500
    }
  end

  def start_link(name: name, size: pool_size, worker: worker_module) do
    Registry.start_link(keys: :unique, name: name)

    case DynamicSupervisor.start_link(SpawnPool.Supervisor, [], name: @supervisor_name) do
      {:ok, sup} ->
        # Start the pool of workers
        for i <- 0..(pool_size - 1) do
          DynamicSupervisor.start_child(sup, {worker_module, {name, i}})
        end

        {:ok, sup}

      {:error, reason} ->
        Logger.error("Failed to start pool ❌: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def call(pool_name, process_number, msg) do
    GenServer.call(via_tuple(pool_name, process_number), msg)
  end

  def cast(pool_name, process_number, msg) do
    GenServer.cast(via_tuple(pool_name, process_number), msg)
  end

  def stop(pool_name) do
    DynamicSupervisor.stop(pool_name)
  end

  defp via_tuple(name, id), do: {:via, Registry, {name, id}}
end
