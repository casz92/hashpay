defmodule Hashpay.RoundV2 do
  @moduledoc """
  Estructura y funciones para las rondas de la blockchain de Hashpay (versión simplificada).

  Una ronda es una agrupación de bloques que se validan conjuntamente.
  Contiene:
  - id: Identificador único de la ronda
  - hash: Hash de la ronda
  - prev: Hash de la ronda anterior (opcional para la ronda génesis)
  - creator: Dirección del creador de la ronda
  - signature: Firma digital del creador
  - reward: Recompensa por la creación de la ronda
  - count: Contador de bloques en la ronda
  - tx_count: Contador total de transacciones en la ronda
  - size: Tamaño de la ronda en bytes
  - status: Estado de la ronda (0: pendiente, 1: confirmada, 2: rechazada, 3: finalizada)
  - timestamp: Marca de tiempo de creación
  - blocks: Lista de bloques incluidos en la ronda
  - extra: Datos adicionales (opcional)
  """

  use Hashpay.Serializable
  @behaviour Hashpay.Storable

  alias Hashpay.DB

  # Definir atributos del módulo para la tabla
  @table_name "rounds_v2"
  # @primary_key :id
  @fields [
    id: "bigint",
    hash: "blob",
    prev: "blob",
    creator: "text",
    signature: "blob",
    reward: "bigint",
    count: "int",
    tx_count: "int",
    size: "int",
    status: "tinyint",
    timestamp: "bigint",
    blocks: "list<frozen<map<text, blob>>>",
    extra: "list<text>"
  ]
  # @indices [:hash, :creator, :status]

  alias Hashpay.Variable
  alias Hashpay.RoundV2
  alias Hashpay.BlockV2, as: Block

  @enforce_keys [
    :id,
    :hash,
    :creator,
    :reward,
    :count,
    :tx_count,
    :size,
    :status,
    :timestamp
  ]

  defstruct [
    :id,
    :hash,
    :prev,
    :creator,
    :signature,
    :reward,
    :count,
    :tx_count,
    :size,
    :status,
    :timestamp,
    :blocks,
    :extra
  ]

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          hash: binary(),
          prev: binary() | nil,
          creator: String.t(),
          signature: binary() | nil,
          reward: non_neg_integer(),
          count: non_neg_integer(),
          tx_count: non_neg_integer(),
          size: non_neg_integer(),
          status: 0 | 1 | 2 | 3,
          timestamp: non_neg_integer(),
          blocks: [Block.t()] | [map()] | nil,
          extra: [any()] | nil
        }

  @doc """
  Crea una nueva ronda con los valores proporcionados.

  ## Parámetros

  - `attrs`: Mapa con los atributos de la ronda
  - `private_key`: Clave privada para firmar la ronda

  ## Ejemplos

      iex> Hashpay.RoundV2.new(%{
      ...>   id: 1,
      ...>   prev: nil,
      ...>   creator: "ac_123456",
      ...>   reward: 100,
      ...>   count: 5,
      ...>   tx_count: 20,
      ...>   size: 5120,
      ...>   status: 0,
      ...>   timestamp: System.os_time(:second),
      ...>   blocks: blocks_list
      ...> }, private_key)
      %Hashpay.RoundV2{...}
  """
  def new(attrs, private_key) when is_map(attrs) do
    # Asegurarse de que timestamp esté presente
    attrs = Map.put_new_lazy(attrs, :timestamp, fn -> System.os_time(:second) end)

    # Crear una ronda sin hash ni firma
    round_without_hash = struct!(__MODULE__, attrs)

    # Calcular el hash de la ronda
    hash = calculate_hash(round_without_hash)

    # Firmar el hash con la clave privada
    {:ok, signature} = Cafezinho.Impl.sign(hash, private_key)

    # Añadir hash y firma a la ronda
    %{round_without_hash | hash: hash, signature: signature}
  end

  @doc """
  Calcula el hash de una ronda basado en sus atributos.
  """
  def calculate_hash(round) do
    # Extraer los campos relevantes para el hash
    fields = [
      Integer.to_string(round.id),
      round.prev,
      round.creator,
      Integer.to_string(round.reward),
      Integer.to_string(round.count),
      Integer.to_string(round.tx_count),
      Integer.to_string(round.size),
      Integer.to_string(round.status),
      Integer.to_string(round.timestamp)
    ]

    # Si hay bloques, incluir sus hashes en el cálculo
    block_hashes =
      if round.blocks do
        Enum.map(round.blocks, fn
          %Block{} = block -> block.hash
          block when is_map(block) -> block.hash
        end)
      else
        []
      end

    # Unir los campos y calcular el hash
    :crypto.hash(:sha256, Enum.join(fields ++ block_hashes, "|"))
  end

  @doc """
  Calcula la recompensa de una ronda basado en sus atributos.
  Devuelve un entero representa las ganancias del round.
  """
  def calc_reward(%RoundV2{} = round) do
    txs = round.count
    s_target = txs * 160

    Variable.get_round_rewarded_base() + trunc(txs * Variable.get_round_rewarded_transactions()) -
      trunc(max(0, (round.size - s_target) * Variable.get_round_size_target()))
  end

  @doc """
  Verifica la firma de una ronda.

  ## Parámetros

  - `round`: La ronda a verificar
  - `public_key`: Clave pública del creador

  ## Retorno

  - `true` si la firma es válida
  - `false` si la firma no es válida
  """
  def verify_signature(round, public_key) do
    Cafezinho.Impl.verify(round.signature, round.hash, public_key)
  end

  @doc """
  Valida una ronda completa.

  ## Parámetros

  - `round`: La ronda a validar
  - `prev_round`: La ronda anterior (opcional)
  - `public_key`: Clave pública del creador

  ## Retorno

  - `{:ok, round}` si la ronda es válida
  - `{:error, reason}` si la ronda no es válida
  """
  def validate(round, prev_round \\ nil, public_key) do
    with :ok <- validate_hash(round),
         :ok <- validate_prev_hash(round, prev_round),
         :ok <- validate_id(round, prev_round),
         :ok <- validate_signature(round, public_key),
         :ok <- validate_blocks(round) do
      {:ok, round}
    end
  end

  defp validate_hash(round) do
    calculated_hash = calculate_hash(round)

    if calculated_hash == round.hash do
      :ok
    else
      {:error, :invalid_hash}
    end
  end

  defp validate_prev_hash(_round, nil) do
    # Si no hay ronda anterior, no hay que validar el hash previo
    :ok
  end

  defp validate_prev_hash(round, prev_round) do
    if round.prev == prev_round.hash do
      :ok
    else
      {:error, :invalid_prev_hash}
    end
  end

  defp validate_id(round, nil) do
    # Si no hay ronda anterior, el id debe ser 0 o 1 (génesis)
    if round.id == 0 || round.id == 1 do
      :ok
    else
      {:error, :invalid_id_for_genesis}
    end
  end

  defp validate_id(round, prev_round) do
    if round.id == prev_round.id + 1 do
      :ok
    else
      {:error, :invalid_id}
    end
  end

  defp validate_signature(round, public_key) do
    if verify_signature(round, public_key) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  defp validate_blocks(round) do
    if round.blocks && length(round.blocks) > 0 do
      # Verificar que el número de bloques coincide con el contador
      if length(round.blocks) == round.count do
        :ok
      else
        {:error, :invalid_block_count}
      end
    else
      # Si no hay bloques, el contador debe ser 0
      if round.count == 0 do
        :ok
      else
        {:error, :invalid_block_count}
      end
    end
  end

  @doc """
  Implementación personalizada de to_map para manejar la serialización de bloques.
  """
  def to_map(%__MODULE__{} = round) do
    # Convertir bloques a formato adecuado para serialización
    blocks_list =
      if round.blocks do
        Enum.map(round.blocks, fn
          %Block{} = block -> Block.to_map(block)
          map when is_map(map) -> map
        end)
      else
        nil
      end

    # Crear un mapa base con todos los campos
    base_map = Map.from_struct(round)

    # Reemplazar la lista de bloques con la versión serializada
    Map.put(base_map, :blocks, blocks_list)
  end

  @doc """
  Implementación personalizada de from_map para manejar la deserialización de bloques.
  """
  def from_map(map) when is_map(map) do
    # Convertir claves string a átomos si es necesario
    map =
      if Hashpay.Serializable.map_has_string_keys?(map),
        do: Hashpay.Serializable.string_keys_to_atoms(map),
        else: map

    # Convertir bloques de formato serializado a estructuras Block
    blocks =
      if map[:blocks] do
        Enum.map(map[:blocks], fn block_map ->
          try do
            Block.from_map(block_map)
          rescue
            _ -> block_map
          end
        end)
      else
        nil
      end

    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{map | blocks: blocks})
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
      hash blob,
      prev blob,
      creator text,
      signature blob,
      reward bigint,
      count int,
      tx_count int,
      size int,
      status tinyint,
      timestamp bigint,
      blocks list<frozen<map<text, blob>>>,
      extra list<text>,
      PRIMARY KEY (id)
    );
    """

    # Crear índices para búsquedas eficientes
    indices = [
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (hash);",
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (creator);",
      "CREATE INDEX IF NOT EXISTS ON #{@table_name} (status);"
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
  Guarda una ronda en la base de datos.
  """
  def save(conn, %__MODULE__{} = round) do
    # Convertir bloques a formato adecuado para ScyllaDB
    blocks_list =
      if round.blocks do
        Enum.map(round.blocks, fn block ->
          block_map =
            case block do
              %Block{} -> Block.to_map(block)
              map when is_map(map) -> map
            end

          # Convertir a mapa de texto -> blob para ScyllaDB
          Map.new(block_map, fn {k, v} ->
            {Atom.to_string(k),
             case v do
               v when is_binary(v) -> v
               v -> :erlang.term_to_binary(v)
             end}
          end)
        end)
      else
        nil
      end

    # Crear una copia de la ronda con los bloques serializados
    serialized_round = %{round | blocks: blocks_list}

    # Extraer valores de los campos
    values = Enum.map(@fields, fn {field, _} -> Map.get(serialized_round, field) end)

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
      {:ok, _} -> {:ok, round}
      error -> error
    end
  end

  @doc """
  Actualiza una ronda en la base de datos.
  """
  def update(conn, %__MODULE__{} = round) do
    # Convertir bloques a formato adecuado para ScyllaDB
    blocks_list =
      if round.blocks do
        Enum.map(round.blocks, fn block ->
          block_map =
            case block do
              %Block{} -> Block.to_map(block)
              map when is_map(map) -> map
            end

          # Convertir a mapa de texto -> blob para ScyllaDB
          Map.new(block_map, fn {k, v} ->
            {Atom.to_string(k),
             case v do
               v when is_binary(v) -> v
               v -> :erlang.term_to_binary(v)
             end}
          end)
        end)
      else
        nil
      end

    # Crear una copia de la ronda con los bloques serializados
    serialized_round = %{round | blocks: blocks_list}

    # Extraer valores de los campos
    values = Enum.map(@fields, fn {field, _} -> Map.get(serialized_round, field) end)

    # Construir cláusula SET
    set_clause =
      Enum.map_join(Enum.with_index(@fields), ", ", fn {{field, _}, i} ->
        "#{field} = ?#{i + 1}"
      end)

    statement = """
    UPDATE #{@table_name}
    SET #{set_clause}
    WHERE id = ?;
    """

    # Construir parámetros con tipos
    params = Enum.zip(Enum.map(@fields, fn {_, type} -> type end), values)
    params = params ++ [{"bigint", round.id}]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, round}
      error -> error
    end
  end

  @doc """
  Elimina una ronda de la base de datos por su ID.
  """
  def delete(conn, id) do
    statement = "DELETE FROM #{@table_name} WHERE id = ?;"
    params = [{"bigint", id}]

    DB.execute(conn, statement, params)
  end

  @doc """
  Obtiene una ronda por su ID.
  """
  def get(conn, id) do
    statement = "SELECT * FROM #{@table_name} WHERE id = ?;"
    params = [{"bigint", id}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> {:ok, row_to_struct(row)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  @doc """
  Obtiene una ronda por su hash.
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

      error ->
        error
    end
  end

  @doc """
  Obtiene todas las rondas que cumplen con ciertos parámetros.
  """
  def all(conn, params \\ %{}) do
    {statement, query_params} = build_all_query(params)

    case DB.execute(conn, statement, query_params) do
      {:ok, %Xandra.Page{} = page} ->
        structs = Enum.map(page, &row_to_struct/1)
        {:ok, structs}

      error ->
        error
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
      if Map.has_key?(params, :creator) do
        {clauses ++ ["creator = ?"], query_params ++ [{"text", params.creator}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params} =
      if Map.has_key?(params, :status) do
        {clauses ++ ["status = ?"], query_params ++ [{"tinyint", params.status}]}
      else
        {clauses, query_params}
      end

    {clauses, query_params}
  end

  defp row_to_struct(row) do
    # Convertir bloques de formato ScyllaDB a formato Elixir
    blocks =
      if row["blocks"] do
        Enum.map(row["blocks"], fn block_map ->
          # Convertir claves de string a atom y deserializar valores binarios
          block_map =
            Map.new(block_map, fn {k, v} ->
              {String.to_atom(k),
               try do
                 :erlang.binary_to_term(v)
               rescue
                 _ -> v
               end}
            end)

          # Convertir a estructura Block si es posible
          try do
            Block.from_map(block_map)
          rescue
            _ -> block_map
          end
        end)
      else
        nil
      end

    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{
      id: row["id"],
      hash: row["hash"],
      prev: row["prev"],
      creator: row["creator"],
      signature: row["signature"],
      reward: row["reward"],
      count: row["count"],
      tx_count: row["tx_count"],
      size: row["size"],
      status: row["status"],
      timestamp: row["timestamp"],
      blocks: blocks,
      extra: row["extra"]
    })
  end
end
