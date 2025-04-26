defmodule Hashpay.DB do
  use GenServer

  @connection_key :scylla_connection

  @doc """
  Inicia el proceso supervisado para manejar conexiones a ScyllaDB.
  """
  def start_link(opts) do
    IO.puts("Starting DB2")
    {:ok, pid} = Xandra.start_link(opts)
    :persistent_term.put(@connection_key, pid)
    {:ok, pid}
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
        opts = Application.get_env(:hashpay, :scylla)
        {:ok, conn} = start_link(opts)
        conn

      conn ->
        if Process.alive?(conn) do
          conn
        else
          opts = Application.get_env(:hashpay, :scylla)
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
    Xandra.execute(conn, statement, params, options)
  end

  @doc """
  Ejecuta una consulta CQL y devuelve el resultado o lanza una excepción en caso de error.
  """
  def execute!(conn, statement, params \\ [], options \\ []) do
    Xandra.execute!(conn, statement, params, options)
  end

  @doc """
  Crea el keyspace si no existe.

  ## Parámetros

  - `conn`: Conexión a ScyllaDB
  - `keyspace`: Nombre del keyspace
  - `replication`: Configuración de replicación
  """
  def create_keyspace(
        conn,
        keyspace,
        replication \\ "{'class': 'SimpleStrategy', 'replication_factor': 1}"
      ) do
    statement = """
    CREATE KEYSPACE IF NOT EXISTS #{keyspace}
    WITH REPLICATION = #{replication}
    """

    execute(conn, statement)
  end

  @doc """
  Usa un keyspace específico.
  """
  def use_keyspace(conn, keyspace) do
    execute(conn, "USE #{keyspace}")
  end

  @doc """
  Prepara una consulta CQL.
  """
  def prepare(conn, statement) do
    Xandra.prepare(conn, statement)
  end

  def prepare!(conn, statement) do
    Xandra.prepare!(conn, statement)
  end
end

defmodule Hashpay.DB.Cluster do
  @pool_name :xandra_pool

  def execute(statement, params \\ [], options \\ []) do
    Xandra.execute(@pool_name, statement, params, options)
  end

  def execute!(statement, params \\ [], options \\ []) do
    Xandra.execute!(@pool_name, statement, params, options)
  end

  def prepare(statement) do
    Xandra.prepare(@pool_name, statement)
  end

  def prepare!(statement) do
    Xandra.prepare!(@pool_name, statement)
  end

  @doc """
  Cierra la conexión a ScyllaDB y elimina la referencia de persistent_term.
  """
  def stop do
    Xandra.Cluster.stop(@pool_name)
  end
end
