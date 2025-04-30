defmodule Hashpay.Round do
  @moduledoc """
  Estructura y funciones para las rondas de la blockchain de Hashpay.

  Una ronda es una agrupación de bloques que se validan conjuntamente.
  Contiene:
  - id: Identificador único de la ronda
  - hash: Hash de la ronda
  - prev: Hash de la ronda anterior (opcional para la ronda génesis)
  - creator: Dirección del creador de la ronda
  - signature: Firma digital del creador
  - reward: Recompensa por la creación de la ronda
  - count: Contador de bloques en la ronda
  - txs: Contador total de transacciones en la ronda
  - size: Tamaño de la ronda en bytes
  - status: Estado de la ronda (0: pendiente, 1: confirmada, 2: rechazada, 3: finalizada)
  - timestamp: Marca de tiempo de creación
  - blocks: Lista de hashes de bloques incluidos en la ronda
  - vsn: Versión del formato de la ronda
  """
  @behaviour Hashpay.MigrationBehaviour

  use Hashpay.Serializable

  alias Hashpay.DB
  alias Hashpay.Variable
  alias Hashpay.Round

  @enforce_keys [
    :id,
    :hash,
    :creator,
    :reward,
    :count,
    :txs,
    :size,
    :status,
    :timestamp,
    :vsn
  ]

  defstruct [
    :id,
    :hash,
    :prev,
    :creator,
    :signature,
    :reward,
    :count,
    :txs,
    :size,
    :status,
    :timestamp,
    :blocks,
    :vsn
  ]

  @type t :: %__MODULE__{
          id: non_neg_integer(),
          hash: binary(),
          prev: binary() | nil,
          creator: String.t(),
          signature: binary() | nil,
          reward: non_neg_integer(),
          count: non_neg_integer(),
          txs: non_neg_integer(),
          size: non_neg_integer(),
          status: 0 | 1 | 2 | 3,
          timestamp: non_neg_integer(),
          blocks: [binary()] | nil,
          vsn: pos_integer()
        }

  @doc """
  Crea una nueva ronda con los valores proporcionados.

  ## Parámetros

  - `attrs`: Mapa con los atributos de la ronda
  - `private_key`: Clave privada para firmar la ronda

  ## Ejemplos

      iex> Hashpay.Round.new(%{
      ...>   id: 1,
      ...>   prev: nil,
      ...>   creator: "ac_123456",
      ...>   reward: 100,
      ...>   count: 5,
      ...>   txs: 20,
      ...>   size: 5120,
      ...>   status: 0,
      ...>   timestamp: 1_500_123_456_789,
      ...>   blocks: blocks_list
      ...> }, private_key)
      %Hashpay.Round{...}
  """
  def new(attrs, private_key) when is_map(attrs) do
    # Asegurarse de que timestamp y vsn estén presentes
    attrs =
      attrs
      |> Map.put_new_lazy(:timestamp, fn -> System.os_time(:millisecond) end)
      |> Map.put_new(:vsn, 1)

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
      round.prev,
      round.creator,
      Integer.to_string(round.reward),
      Integer.to_string(round.count),
      Integer.to_string(round.txs),
      Integer.to_string(round.vsn)
    ]

    # Si hay bloques, incluir sus hashes en el cálculo
    block_hashes =
      if round.blocks do
        # Ahora blocks es una lista de binarios (hashes)
        round.blocks
      else
        []
      end

    # Unir los campos y calcular el hash
    <<hash::192, _rest::binary>> = :crypto.hash(:sha256, Enum.join(fields ++ block_hashes, "|"))

    [<<round.timestamp::64>>, hash] |> IO.iodata_to_binary()
  end

  @doc """
  Calcula la recompensa de una ronda basado en sus atributos.
  Devuelve un entero representa las ganancias del round.
  """
  def calc_reward(%Round{} = round) do
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

  defp validate_prev_hash(round, nil) when round.id == 0, do: :ok
  defp validate_prev_hash(_round, nil), do: {:error, :missing_prev_round}

  defp validate_prev_hash(round, prev_round) do
    if round.prev == prev_round.hash do
      :ok
    else
      {:error, :invalid_prev_hash}
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
    if round.blocks && length(round.blocks) == round.count do
      :ok
    else
      {:error, :invalid_block_count}
    end
  end

  # Sobrescribir funciones específicas del behaviour Storable

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def init(conn) do
    prepare_statements!(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS rounds (
      id bigint,
      hash blob,
      prev blob,
      creator text,
      signature blob,
      reward bigint,
      count int,
      txs int,
      size int,
      status tinyint,
      timestamp bigint,
      blocks frozen<list<blob>>,
      vsn int,
      PRIMARY KEY (id)
    );
    """

    DB.execute!(conn, statement)

    # Crear índices para búsquedas eficientes
    indices = [
      "CREATE INDEX IF NOT EXISTS ON rounds (hash);",
      "CREATE INDEX IF NOT EXISTS ON rounds (creator);"
    ]

    Enum.each(indices, fn index ->
      DB.execute!(conn, index)
    end)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS rounds;"
    DB.execute!(conn, statement)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO rounds (id, hash, prev, creator, signature, reward, count, txs, size, status, timestamp, blocks, vsn)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    insert_prepared = Xandra.prepare!(conn, insert_prepared)

    :persistent_term.put({:stmt, "rounds_insert"}, insert_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "rounds_insert"})
  end

  def batch_save(batch, round) do
    Xandra.Batch.add(batch, insert_prepared(), [
      round.id,
      round.hash,
      round.prev,
      round.creator,
      round.signature,
      round.reward,
      round.count,
      round.txs,
      round.size,
      round.status,
      round.timestamp,
      round.blocks,
      round.vsn
    ])
  end

  def get(conn, id) do
    statement = "SELECT * FROM rounds WHERE id = ?;"
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

  def get_last(conn, limit \\ 1) do
    statement = "SELECT * FROM rounds ORDER BY id DESC LIMIT ?;"
    params = [{"int", limit}]

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
  Sobrescribe la función row_to_struct para manejar la deserialización de bloques.
  """
  def row_to_struct(row) do
    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{
      id: row["id"],
      hash: row["hash"],
      prev: row["prev"],
      creator: row["creator"],
      signature: row["signature"],
      reward: row["reward"],
      count: row["count"],
      txs: row["txs"],
      size: row["size"],
      status: row["status"],
      timestamp: row["timestamp"],
      blocks: row["blocks"],
      vsn: row["vsn"]
    })
  end
end
