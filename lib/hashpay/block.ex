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
  import Hashpay, only: [hash: 1]
  import ThunderRAM, only: [key_merge: 2]

  @trdb :blocks
  @block_version Application.compile_env(:hashpay, :block_version, 1)

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
    attrs =
      attrs
      |> Map.put_new_lazy(:timestamp, fn -> System.os_time(:millisecond) end)
      |> Map.put(:vsn, @block_version)

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
    <<hash::binary-24, _rest::binary>> = hash(Enum.join(fields, "|"))

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

  def dbopts do
    [
      name: @trdb,
      handle: ~c"blocks",
      exp: true
    ]
  end

  def fetch(tr, id) do
    ThunderRAM.fetch_from_db(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = block) do
    ThunderRAM.put_db(tr, @trdb, Integer.to_string(block.id), block)
    ThunderRAM.count_one(tr, @trdb)
  end

  def put_local(tr, %__MODULE__{} = block) do
    ThunderRAM.put_db(tr, @trdb, block.id, block)
    ThunderRAM.put_db(tr, @trdb, key_merge("$last", block.creator), block)
    ThunderRAM.count_one(tr, @trdb)
  end

  def last(tr, vid) do
    case fetch(tr, key_merge("$last", vid)) do
      {:ok, block} -> block
      _ -> nil
    end
  end

  def delete(tr, %__MODULE__{} = block) do
    ThunderRAM.delete_db(tr, @trdb, block.id)
  end

  def delete(tr, id) do
    ThunderRAM.delete_db(tr, @trdb, id)
  end

  def to_struct(data = %__MODULE__{}), do: data

  def to_struct(data) do
    struct(__MODULE__, data)
  end
end
