defmodule Hashpay.Block do
  @moduledoc """
  Estructura y funciones para los bloques de la blockchain de Hashpay.

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
  @behaviour Hashpay.MigrationBehaviour

  alias Hashpay.{DB}

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

  ## Ejemplos

      iex> Hashpay.Block.new(%{
      ...>   creator: "ac_123456",
      ...>   channel: "main",
      ...>   height: 1,
      ...>   prev: nil,
      ...>   timestamp: System.os_time(:millisecond),
      ...>   count: 10,
      ...>   rejected: 0,
      ...>   size: 1024,
      ...>   status: 1,
      ...>   vsn: 1
      ...> }, private_key)
      %Hashpay.Block{...}
  """
  def new(attrs, private_key) when is_map(attrs) do
    # Asegurarse de que timestamp esté presente
    attrs = Map.put_new_lazy(attrs, :timestamp, fn -> System.os_time(:millisecond) end)

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
      block.prev,
      block.creator,
      block.channel,
      Base.decode16!(block.filehash),
      Integer.to_string(block.count),
      Integer.to_string(block.vsn)
    ]

    # Unir los campos y calcular el hash
    <<hash::192, _rest::binary>> = :crypto.hash(:sha256, Enum.join(fields, "|"))

    [<<block.timestamp::64>>, hash] |> IO.iodata_to_binary()
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
         :ok <- validate_size(block),
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

  defp validate_prev_hash(block, nil) when block.height == 0, do: :ok
  defp validate_prev_hash(_block, nil), do: {:error, :missing_prev_block}

  defp validate_prev_hash(block, prev_block) do
    if block.prev == prev_block.hash do
      :ok
    else
      {:error, :invalid_prev_hash}
    end
  end

  defp validate_height(block, nil) when block.height == 0, do: :ok
  defp validate_height(_block, nil), do: {:error, :missing_prev_block}

  defp validate_height(block, prev_block) do
    if block.height == prev_block.height + 1 do
      :ok
    else
      {:error, :invalid_height}
    end
  end

  defp validate_size(block) do
    if block.size > 0 do
      :ok
    else
      {:error, :invalid_size}
    end
  end

  defp validate_signature(block, public_key) do
    if verify_signature(block, public_key) do
      :ok
    else
      {:error, :invalid_signature}
    end
  end

  # Sobrescribir funciones específicas del behaviour Storable

  @doc """
  Sobrescribe la función create_table para usar una clave primaria compuesta.
  """
  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS blocks (
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
      PRIMARY KEY (id)
    ) WITH transactions = {'enabled': 'true'};
    """

    DB.execute!(conn, statement)

    # Crear índices para búsquedas eficientes
    indices = [
      "CREATE INDEX IF NOT EXISTS ON blocks (hash);",
      "CREATE INDEX IF NOT EXISTS ON blocks (creator);",
      "CREATE INDEX IF NOT EXISTS ON blocks (channel);",
      "CREATE INDEX IF NOT EXISTS ON blocks (round);"
    ]

    Enum.each(indices, fn index ->
      DB.execute!(conn, index)
    end)
  end

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  @impl true
  def init(conn) do
    prepare_statements!(conn)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS blocks;"
    DB.execute!(conn, statement)
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO blocks (id, creator, channel, height, round, hash, filehash, prev, signature, timestamp, count, rejected, size, status, vsn)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    insert_prepared = DB.prepare!(conn, insert_prepared)

    :persistent_term.put({:stmt, "blocks_insert"}, insert_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "blocks_insert"})
  end

  def batch_save(batch, block) do
    Xandra.Batch.add(batch, insert_prepared(), [
      block.id,
      block.creator,
      block.channel,
      block.height,
      block.round,
      block.hash,
      block.filehash,
      block.prev,
      block.signature,
      block.timestamp,
      block.count,
      block.rejected,
      block.size,
      block.status,
      block.vsn
    ])
  end

  def get(conn, channel, height) do
    statement = "SELECT * FROM blocks WHERE channel = ? AND height = ?;"
    params = [{"text", channel}, {"bigint", height}]

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

  def get_by_hash(conn, hash) do
    statement = "SELECT * FROM blocks WHERE hash = ? ALLOW FILTERING;"
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

  def get_last(conn, channel, limit \\ 1) do
    statement = "SELECT * FROM blocks WHERE channel = ? ORDER BY height DESC LIMIT ?;"
    params = [{"text", channel}, {"int", limit}]

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

  def row_to_struct(row) do
    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{
      id: row["id"],
      creator: row["creator"],
      channel: row["channel"],
      height: row["height"],
      round: row["round"],
      hash: row["hash"],
      filehash: row["filehash"],
      prev: row["prev"],
      signature: row["signature"],
      timestamp: row["timestamp"],
      count: row["count"],
      rejected: row["rejected"],
      size: row["size"],
      status: row["status"],
      vsn: row["vsn"]
    })
  end
end
