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
  - status: Estado de la ronda (0: pending, 1: confirmed, 2: skipped, 3: rejected, 4: timeout)
  - timestamp: Marca de tiempo de creación
  - blocks: Lista de hashes de bloques incluidos en la ronda
  - vsn: Versión del formato de la ronda
  """
  alias Hashpay.Variable
  alias Hashpay.Round
  import Hashpay, only: [hash: 1]

  @trdb :rounds
  @round_version Application.compile_env(:hashpay, :round_version, 1)

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
    %{
      round_without_hash
      | hash: hash,
        signature: signature,
        reward: calc_reward(round_without_hash)
    }
  end

  def new_cancelled(round = %Round{}) do
    %{round | status: 3}
  end

  def new_timeout(round_id, prev_round_hash, creator_id) do
    round = %__MODULE__{
      id: round_id,
      prev: prev_round_hash,
      creator: creator_id,
      reward: 0,
      count: 0,
      txs: 0,
      size: 0,
      status: 4,
      timestamp: System.os_time(:millisecond),
      blocks: [],
      vsn: @round_version
    }

    hash = calculate_hash(round)
    %{round | hash: hash}
  end

  def new_skipped(round_id, prev_round_hash, creator_id, privkey) do
    %{
      id: round_id,
      prev: prev_round_hash,
      creator: creator_id,
      reward: 0,
      count: 0,
      txs: 0,
      size: 0,
      status: 2,
      blocks: [],
      vsn: @round_version
    }
    |> new(privkey)
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
    <<hash::binary-24, _rest::binary>> = hash(Enum.join(fields ++ block_hashes, "|"))

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

  def dbopts do
    [
      name: @trdb,
      handle: ~c"rounds",
      exp: true
    ]
  end

  def fetch(tr, id) do
    ThunderRAM.fetch_from_db(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = round) do
    ThunderRAM.put_db(tr, @trdb, Integer.to_string(round.id), round)
    ThunderRAM.put_db(tr, @trdb, "$last", round)
    ThunderRAM.count_one(tr, @trdb)
  end

  def delete(tr, %__MODULE__{} = round) do
    ThunderRAM.delete_db(tr, @trdb, round.id)
    ThunderRAM.discount_one(tr, @trdb)
  end

  def delete(tr, id) do
    ThunderRAM.delete_db(tr, @trdb, id)
  end

  def last(tr) do
    case fetch(tr, "$last") do
      {:ok, round} -> round
      _ -> nil
    end
  end

  def total(tr) do
    case ThunderRAM.fetch(tr, @trdb, "$count") do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def to_struct(data = %__MODULE__{}), do: data

  def to_struct(data) do
    struct(__MODULE__, data)
  end
end
