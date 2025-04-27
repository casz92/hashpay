defmodule Hashpay.Hits do
  @behaviour GenServer
  @moduledoc """
  Módulo para almacenar y gestionar hits (accesos) a objetos en una tabla ETS.

  Almacena información sobre objetos accedidos recientemente:
  - id: Identificador único del objeto
  - type: Tipo de objeto (Hashpay.object_type())
  - readed_at: Timestamp de la última lectura
  - written_at: Timestamp de la última escritura
  """
  require Logger
  @module_name Module.split(__MODULE__) |> Enum.join(".")
  @table_name :hits
  @unit_time :millisecond
  @cleanup_interval :timer.minutes(10)
  @expiration_time :timer.hours(1)

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Inicia el módulo de hits creando la tabla ETS.
  """
  def start_link(_opts) do
    # Crear tabla ETS con nombre del módulo, pública y con concurrencia de lectura
    :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])

    case GenServer.start_link(__MODULE__, [], name: __MODULE__) do
      {:ok, pid} ->
        Logger.info("Running #{@module_name} ✅")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start #{@module_name} ❌: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def init(args) do
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:ok, args}
  end

  @spec hit_read(binary(), Hashpay.object_type()) :: boolean()
  def hit_read(id, type) do
    timestamp = now()

    case :ets.lookup(@table_name, id) do
      [] ->
        # Nuevo registro: {id, readed_at, written_at}
        :ets.insert(@table_name, {id, type, timestamp, nil})

      [{^id, _old_read_at, _old_write_at}] ->
        # Actualizar registro existente
        :ets.update_element(@table_name, id, {2, timestamp})
    end
  end

  @spec hit_write(binary(), Hashpay.object_type()) :: boolean()
  def hit_write(id, type) do
    timestamp = now()

    case :ets.lookup(@table_name, id) do
      [] ->
        :ets.insert(@table_name, {id, type, nil, timestamp})

      [{^id, _old_read_at, _old_write_at}] ->
        # Actualizar registro existente
        :ets.update_element(@table_name, id, {3, timestamp})
    end
  end

  @spec retrive_by_type(Hashpay.object_type()) :: [binary() | String.t()]
  def retrive_by_type(type) do
    match_spec =
      :ets.fun2ms(fn {id, ^type, _readed_at, _written_at} ->
        id
      end)

    :ets.select(@table_name, match_spec)
  end

  @spec remove(any()) :: true
  def remove(id) do
    :ets.delete(@table_name, id)
  end

  def cleanup(older_than) do
    match_spec =
      :ets.fun2ms(fn {_id, readed_at, _written_at} ->
        readed_at != nil or readed_at < older_than
      end)

    :ets.select_delete(@table_name, match_spec)
  end

  defp now do
    :os.system_time(@unit_time)
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup(now() - @expiration_time)
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:ok, state}
  end
end
