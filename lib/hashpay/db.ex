defmodule Hashpay.DB do
  use GenServer
  require Logger

  @connection_key :db_connection
  @module_name Module.split(__MODULE__) |> Enum.join(".")
  @adapter Postgrex

  @doc """
  Inicia el proceso supervisado para manejar conexiones a ScyllaDB.
  """
  def start_link(opts) do
    version = Application.spec(Postgrex, :vsn)

    case @adapter.start_link(opts) do
      {:ok, pid} ->
        Logger.debug("Running #{@module_name} with Postgrex v#{version} ✅")
        :persistent_term.put(@connection_key, pid)
        {:ok, pid}

      {:error, reason} ->
        Logger.error(
          "Failed to start #{@module_name} with Postgrex v#{version} ❌: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  def get_conn do
    :persistent_term.get(@connection_key, :undefined)
  end

  def get_conn_with_retry do
    case :persistent_term.get(@connection_key, :undefined) do
      :undefined ->
        opts = Application.get_env(:hashpay, :postgres)
        {:ok, conn} = start_link(opts)
        conn

      conn ->
        if Process.alive?(conn) do
          conn
        else
          opts = Application.get_env(:hashpay, :postgres)
          {:ok, conn} = start_link(opts)
          conn
        end
    end
  end

  @doc """
  Verifica si hay una conexión activa a ScyllaDB.
  """
  def connection_active? do
    case :persistent_term.get(@connection_key, :undefined) do
      :undefined -> false
      conn -> Process.alive?(conn)
    end
  end

  def get_batch do
    :persistent_term.get(:batch, nil)
  end

  def new_batch(type \\ :unlogged) do
    batch = PostgrexBatch.new(type)
    :persistent_term.put(:batch, batch)
    batch
  end

  @doc """
  Ejecuta una consulta CQL.

  ## Parámetros

  - `conn`: Conexión a ScyllaDB
  - `statement`: Consulta CQL
  - `params`: Parámetros para la consulta (opcional)
  - `options`: Opciones para la ejecución (opcional)

  ## Retorno

  - `{:ok, result}` si la consulta se ejecuta correctamente
  - `{:error, reason}` si hay un error
  Xandra.execute(:xandra_pool, "DESCRIBE TABLES;", [])
  """

  def execute(conn, statement, params \\ [], options \\ []) do
    @adapter.query(conn, statement, params, options)
  end

  @doc """
  Ejecuta una consulta CQL y devuelve el resultado o lanza una excepción en caso de error.
  """
  def execute!(conn, statement, params \\ [], options \\ []) do
    @adapter.query!(conn, statement, params, options)
  end

  @doc """
  Crea el keyspace si no existe.

  ## Parámetros

  - `conn`: Conexión a ScyllaDB
  - `keyspace`: Nombre del keyspace
  - `replication`: Configuración de replicación
  """
  def create_space(conn, name) do
    statement = """
    CREATE SCHEMA IF NOT EXISTS #{name}
    """

    execute!(conn, statement)
  end

  def drop_space(conn, name) do
    statement = """
    DROP SCHEMA IF EXISTS #{name}
    """

    execute!(conn, statement)
  end

  @doc """
  Usa un keyspace/schema específico.
  """
  def use_space(conn, name) do
    execute!(conn, "USE #{name}")
  end

  @doc """
  Prepara una consulta CQL.
  """
  def prepare(conn, name, statement) do
    @adapter.prepare(conn, name, statement)
  end

  def prepare!(conn, name, statement) do
    @adapter.prepare!(conn, name, statement)
  end

  def execute_prepared(conn, name, params \\ []) do
    @adapter.execute(conn, name, params)
  end

  def execute_prepared!(conn, name, params \\ []) do
    @adapter.execute!(conn, name, params)
  end

  def stop(conn) do
    if Process.alive?(conn) do
      GenServer.stop(conn)
    end
  end

  def to_keyword(%Postgrex.Result{columns: columns, rows: [rows]}) do
    Enum.zip(columns, rows)
  end

  def to_list(%Postgrex.Result{columns: columns, rows: rows}, fun) do
    Enum.map(rows, fn row ->
      Enum.zip(columns, row) |> fun.()
    end)
  end
end
