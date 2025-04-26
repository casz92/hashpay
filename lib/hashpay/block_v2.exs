defmodule Hashpay.BlockV2 do
  @moduledoc """
  Estructura y funciones para los bloques de la blockchain de Hashpay (versión simplificada).

  Un bloque contiene:
  - id: Identificador único del bloque (opcional)
  - creator: Dirección del creador del bloque
  - channel: Canal al que pertenece el bloque
  - height: Altura del bloque en la cadena
  - round: Ronda de consenso (opcional)
  - hash: Hash del bloque
  - filehash: Hash del archivo asociado (opcional)
  - prev: Hash del bloque anterior (opcional para el bloque génesis)
  - signature: Firma digital del creador
  - timestamp: Marca de tiempo de creación
  - count: Contador de transacciones
  - rejected: Contador de transacciones rechazadas
  - size: Tamaño del bloque en bytes
  - status: Estado del bloque (entero)
  - vsn: Versión del formato de bloque
  """

  use Hashpay.Serializable
  @behaviour Hashpay.Storable

  alias Hashpay.DB

  # Definir atributos del módulo para la tabla
  @table_name "blocks_v2"
  @primary_key :id
  @fields [
    id: "bigint",
    creator: "text",
    channel: "text",
    height: "bigint",
    round: "bigint",
    hash: "blob",
    filehash: "blob",
    prev: "blob",
    signature: "blob",
    timestamp: "bigint",
    count: "int",
    rejected: "int",
    size: "int",
    status: "int",
    vsn: "int"
  ]
  @indices [:hash, :creator, :round]

  @enforce_keys [
    :creator,
    :channel,
    :height,
    :hash,
    :signature,
    :timestamp,
    :count,
    :rejected,
    :size,
    :status,
    :vsn
  ]

  defstruct [
    :id,
    :creator,
    :channel,
    :height,
    :round,
    :hash,
    :filehash,
    :prev,
    :signature,
    :timestamp,
    :count,
    :rejected,
    :size,
    :status,
    :vsn
  ]

  @type t :: %__MODULE__{
    id: non_neg_integer() | nil,
    creator: String.t(),
    channel: String.t(),
    height: non_neg_integer(),
    round: non_neg_integer() | nil,
    hash: binary(),
    filehash: binary() | nil,
    prev: binary() | nil,
    signature: binary(),
    timestamp: non_neg_integer(),
    count: non_neg_integer(),
    rejected: non_neg_integer(),
    size: non_neg_integer(),
    status: integer(),
    vsn: non_neg_integer()
  }

  @doc """
  Crea un nuevo bloque con los valores proporcionados.

  ## Parámetros

  - `attrs`: Mapa con los atributos del bloque
  - `private_key`: Clave privada para firmar el bloque

  ## Ejemplos

      iex> Hashpay.BlockV2.new(%{
      ...>   creator: "ac_123456",
      ...>   channel: "main",
      ...>   height: 1,
      ...>   prev: nil,
      ...>   timestamp: System.os_time(:second),
      ...>   count: 10,
      ...>   rejected: 0,
      ...>   size: 1024,
      ...>   status: 1,
      ...>   vsn: 1
      ...> }, private_key)
      %Hashpay.BlockV2{...}
  """
  def new(attrs, private_key) when is_map(attrs) do
    # Asegurarse de que timestamp esté presente
    attrs = Map.put_new_lazy(attrs, :timestamp, fn -> System.os_time(:second) end)

    # Crear un bloque sin hash ni firma
    block_without_hash = struct!(__MODULE__, attrs)

    # Calcular el hash del bloque
    hash = calculate_hash(block_without_hash)

    # Firmar el hash con la clave privada
    {:ok, signature} = Cafezinho.Impl.sign(hash, private_key)

    # Añadir hash y firma al bloque
    %{block_without_hash | hash: hash, signature: signature}
  end

  @doc """
  Calcula el hash de un bloque basado en sus atributos.
  """
  def calculate_hash(block) do
    # Extraer los campos relevantes para el hash
    fields = [
      block.creator,
      block.channel,
      Integer.to_string(block.height),
      block.prev,
      Integer.to_string(block.timestamp),
      Integer.to_string(block.count),
      Integer.to_string(block.rejected),
      Integer.to_string(block.size),
      Integer.to_string(block.status),
      Integer.to_string(block.vsn)
    ]

    # Unir los campos y calcular el hash
    :crypto.hash(:sha256, Enum.join(fields, "|"))
  end

  @doc """
  Verifica la firma de un bloque.

  ## Parámetros

  - `block`: El bloque a verificar
  - `public_key`: Clave pública del creador

  ## Retorno

  - `true` si la firma es válida
  - `false` si la firma no es válida
  """
  def verify_signature(block, public_key) do
    Cafezinho.Impl.verify(block.signature, block.hash, public_key)
  end

  @doc """
  Valida un bloque completo.

  ## Parámetros

  - `block`: El bloque a validar
  - `prev_block`: El bloque anterior (opcional)
  - `public_key`: Clave pública del creador

  ## Retorno

  - `{:ok, block}` si el bloque es válido
  - `{:error, reason}` si el bloque no es válido
  """
  def validate(block, prev_block \\ nil, public_key) do
    with :ok <- validate_hash(block),
         :ok <- validate_prev_hash(block, prev_block),
         :ok <- validate_height(block, prev_block),
         :ok <- validate_signature(block, public_key) do
      {:ok, block}
    end
  end

  defp validate_hash(block) do
    calculated_hash = calculate_hash(block)

    if calculated_hash == block.hash do
      :ok
    else
      {:error, :invalid_hash}
    end
  end

  defp validate_prev_hash(block, nil) do
    # Si no hay bloque anterior, no hay que validar el hash previo
    :ok
  end

  defp validate_prev_hash(block, prev_block) do
    if block.prev == prev_block.hash do
      :ok
    else
      {:error, :invalid_prev_hash}
    end
  end

  defp validate_height(block, nil) do
    # Si no hay bloque anterior, la altura debe ser 0 o 1 (génesis)
    if block.height == 0 || block.height == 1 do
      :ok
    else
      {:error, :invalid_height_for_genesis}
    end
  end

  defp validate_height(block, prev_block) do
    if block.height == prev_block.height + 1 do
      :ok
    else
      {:error, :invalid_height}
    end
  end

  defp validate_signature(block, public_key) do
    if verify_signature(block, public_key) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # Implementaciones del behaviour Storable

  @doc """
  Crea la tabla en la base de datos.
  """
  def create_table(conn, keyspace \\ nil) do
    if keyspace do
      DB.use_keyspace(conn, keyspace)
    end

    statement = """
    CREATE TABLE IF NOT EXISTS #{@table_name} (
      id bigint,
      creator text,
      channel text,
      height bigint,
      round bigint,
      hash blob,
      filehash blob,
      prev blob,
      signature blob,
      timestamp bigint,
      count int,
      rejected int,
      size int,
      status int,
      vsn int,
      PRIMARY KEY ((channel), height, hash)
    ) WITH CLUSTERING ORDER BY (height DESC);
    """

    # Crear índices para búsquedas eficientes
    indices = [
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (hash);",
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (creator);",
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (round);"
    ]

    with {:ok, _} <- DB.execute(conn, statement),
         {:ok, _} <- create_indices(conn, indices) do
      {:ok, :table_created}
    end
  end

  defp create_indices(conn, indices) do
    Enum.reduce_while(indices, {:ok, nil}, fn index, _acc ->
      case DB.execute(conn, index) do
        {:ok, result} -> {:cont, {:ok, result}}
        error -> {:halt, error}
      end
    end)
  end

  @doc """
  Elimina la tabla de la base de datos.
  """
  def drop_table(conn, keyspace \\ nil) do
    if keyspace do
      DB.use_keyspace(conn, keyspace)
    end

    statement = "DROP TABLE IF EXISTS #{@table_name};"
    DB.execute(conn, statement)
  end

  @doc """
  Guarda un bloque en la base de datos.
  """
  def save(conn, %__MODULE__{} = block) do
    # Extraer valores de los campos
    values = Enum.map(@fields, fn {field, _} -> Map.get(block, field) end)

    # Construir placeholders para la consulta
    placeholders = Enum.map_join(1..length(@fields), ", ", fn _ -> "?" end)

    # Construir nombres de campos
    field_names = Enum.map_join(@fields, ", ", fn {field, _} -> "#{field}" end)

    statement = """
    INSERT INTO #{@table_name} (#{field_names})
    VALUES (#{placeholders});
    """

    # Construir parámetros con tipos
    params = Enum.zip(Enum.map(@fields, fn {_, type} -> type end), values)

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, block}
      error -> error
    end
  end

  @doc """
  Actualiza un bloque en la base de datos.
  """
  def update(conn, %__MODULE__{} = block) do
    # Extraer valores de los campos
    values = Enum.map(@fields, fn {field, _} -> Map.get(block, field) end)

    # Construir cláusula SET
    set_clause = Enum.map_join(Enum.with_index(@fields), ", ", fn {{field, _}, i} ->
      "#{field} = ?#{i+1}"
    end)

    statement = """
    UPDATE #{@table_name}
    SET #{set_clause}
    WHERE channel = ? AND height = ? AND hash = ?;
    """

    # Construir parámetros con tipos
    params = Enum.zip(Enum.map(@fields, fn {_, type} -> type end), values)
    params = params ++ [
      {"text", block.channel},
      {"bigint", block.height},
      {"blob", block.hash}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, block}
      error -> error
    end
  end

  @doc """
  Elimina un bloque de la base de datos por su ID.
  """
  def delete(conn, id) do
    statement = "DELETE FROM #{@table_name} WHERE id = ? ALLOW FILTERING;"
    params = [{"bigint", id}]

    DB.execute(conn, statement, params)
  end

  @doc """
  Obtiene un bloque por su ID.
  """
  def get(conn, id) do
    statement = "SELECT * FROM #{@table_name} WHERE id = ? ALLOW FILTERING;"
    params = [{"bigint", id}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> {:ok, row_to_struct(row)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end
      error -> error
    end
  end

  @doc """
  Obtiene un bloque por su hash.
  """
  def get_by_hash(conn, hash) do
    statement = "SELECT * FROM #{@table_name} WHERE hash = ? ALLOW FILTERING;"
    params = [{"blob", hash}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> {:ok, row_to_struct(row)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end
      error -> error
    end
  end

  @doc """
  Obtiene todos los bloques que cumplen con ciertos parámetros.
  """
  def all(conn, params \\ %{}) do
    {statement, query_params} = build_all_query(params)

    case DB.execute(conn, statement, query_params) do
      {:ok, %Xandra.Page{} = page} ->
        structs = Enum.map(page, &row_to_struct/1)
        {:ok, structs}
      error -> error
    end
  end

  defp build_all_query(params) do
    base_query = "SELECT * FROM #{@table_name}"
    {where_clauses, query_params} = build_where_clauses(params)

    statement =
      if where_clauses == [] do
        base_query
      else
        base_query <> " WHERE " <> Enum.join(where_clauses, " AND ")
      end

    statement =
      if Map.has_key?(params, :limit) do
        statement <> " LIMIT ?"
      else
        statement
      end

    query_params =
      if Map.has_key?(params, :limit) do
        query_params ++ [{"int", params.limit}]
      else
        query_params
      end

    {statement, query_params}
  end

  defp build_where_clauses(params) do
    clauses = []
    query_params = []

    {clauses, query_params} =
      if Map.has_key?(params, :channel) do
        {clauses ++ ["channel = ?"], query_params ++ [{"text", params.channel}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params} =
      if Map.has_key?(params, :creator) do
        {clauses ++ ["creator = ?"], query_params ++ [{"text", params.creator}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params} =
      if Map.has_key?(params, :round) do
        {clauses ++ ["round = ?"], query_params ++ [{"bigint", params.round}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params} =
      if Map.has_key?(params, :status) do
        {clauses ++ ["status = ?"], query_params ++ [{"int", params.status}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params}
  end

  defp row_to_struct(row) do
    # Convertir una fila de la base de datos a una estructura
    fields = Enum.map(@fields, fn {field, _} -> {field, row[Atom.to_string(field)]} end)
    struct!(__MODULE__, Map.new(fields))
  end
end
