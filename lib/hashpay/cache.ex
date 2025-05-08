defmodule Hashpay.Cache do
  @behaviour GenServer
  @moduledoc """
  Módulo para almacenar y gestionar hits (accesos) a objetos en una tabla ETS.

  Almacena información sobre objetos accedidos recientemente:
  - id: Identificador único del objeto
  - type: Tipo de objeto (Hashpay.object_type())
  - readed_at: Timestamp de la última lectura
  """
  alias Hashpay.Balance
  alias Hashpay.Merchant
  alias Hashpay.Account
  require Logger
  @module_name Module.split(__MODULE__) |> Enum.join(".")
  @table_name :hits
  @unit_time :millisecond
  @cleanup_interval :timer.minutes(15)
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
        Logger.debug("Running #{@module_name} ✅")
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

  @spec put(binary(), Hashpay.object_type()) :: boolean()
  def put(id, type) do
    timestamp = now()
    :ets.insert(@table_name, {id, type, timestamp})
  end

  @spec retrive_by_type(Hashpay.object_type()) :: [binary() | String.t()]
  def retrive_by_type(type) do
    # :ets.fun2ms(fn {id, 1, _readed_at} -> id end)
    match_spec =
      [{{:"$1", type, :"$2"}, [], [:"$1"]}]

    :ets.select(@table_name, match_spec)
  end

  @spec remove(any()) :: true
  def remove(id) do
    :ets.delete(@table_name, id)
  end

  @doc """
  Elimina los registros menos recientes de la tabla ETS.
  """
  @spec cleanup(older_than :: integer()) :: count :: integer()
  def cleanup(older_than) do
    tr = ThunderRAM.get_tr(:blockchain)

    :ets.foldl(
      fn {id, type, readed_at}, acc ->
        Logger.info("Removing #{inspect(id)} of type #{inspect(type)} at #{inspect(readed_at)}")

        if readed_at < older_than do
          case type do
            :accounts -> Account.delete(tr, id)
            :merchants -> Merchant.delete(tr, id)
            :balances -> Balance.delete(tr, id)
            _ -> remove(id)
          end

          acc + 1
        else
          acc
        end
      end,
      0,
      @table_name
    )
  end

  defp now do
    :os.system_time(@unit_time)
  end

  @impl true
  def handle_info(:cleanup, state) do
    cleanup(now() - @expiration_time)
    Process.send_after(self(), :cleanup, @cleanup_interval)
    {:noreply, state}
  end
end
