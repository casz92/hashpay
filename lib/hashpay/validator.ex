defmodule Hashpay.Validator do
  @moduledoc """
  Estructura y funciones para los validadores de la blockchain de Hashpay.

  Un validador contiene:
  - id: Identificador único del validador
  - hostname: Nombre de host del validador
  - port: Puerto de escucha del validador
  - name: Nombre del validador
  - channel: Canal al que pertenece el validador
  - pubkey: Clave pública del validador
  - picture: URL de la imagen del validador
  - factor_a: Factor de ajuste A
  - factor_b: Factor de ajuste B
  - active: Estado del validador (activo o no)
  - failures: Contador de fallos del validador
  - creation: Marca de tiempo de creación del validador
  - updated: Marca de tiempo de última actualización del validador
  """
  @type t :: %__MODULE__{
          id: String.t(),
          hostname: String.t(),
          port: integer(),
          name: String.t(),
          channel: String.t(),
          pubkey: binary(),
          picture: Path.t() | String.t() | nil,
          factor_a: number(),
          factor_b: non_neg_integer(),
          active: boolean(),
          failures: integer(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :hostname,
    :port,
    :name,
    :channel,
    :pubkey,
    :picture,
    :factor_a,
    :factor_b,
    :active,
    :failures,
    :creation,
    :updated
  ]

  alias Hashpay.ValidatorName

  @prefix "v_"
  @regex ~r/^v_[a-zA-Z0-9]*$/
  @trdb :validators

  @compile {:inline, [put: 2, put_new: 2, exists?: 2, delete: 2, total: 1]}

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base62.encode(first16bytes)])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(
        attrs = %{
          "pubkey" => pubkey,
          "hostname" => hostname,
          "port" => port,
          "name" => name,
          "channel" => channel
        }
      ) do
    pubkey = Base.decode64!(pubkey)
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(pubkey),
      hostname: hostname,
      port: port,
      name: name,
      channel: channel,
      pubkey: pubkey,
      picture: Map.get(attrs, "picture", nil),
      factor_a: Map.get(attrs, "factor_a", 1),
      factor_b: Map.get(attrs, "factor_b", 0),
      active: Map.get(attrs, "active", false),
      failures: 0,
      creation: last_round_id,
      updated: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"validators",
      exp: true
    ]
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = validator) do
    ThunderRAM.put(tr, @trdb, validator.id, validator)
  end

  def put_new(tr, %__MODULE__{} = validator) do
    ThunderRAM.put(tr, @trdb, validator.id, validator)
    ValidatorName.put(tr, validator.name, validator.id)
  end

  def exists?(tr, id) do
    ThunderRAM.exists?(tr, @trdb, id)
  end

  def merge(tr, id, attrs) do
    case get(tr, id) do
      {:ok, validator} ->
        validator = Map.merge(validator, struct(__MODULE__, attrs))
        ThunderRAM.put(tr, @trdb, validator.id, validator)

      _ ->
        {:error, :not_found}
    end
  end

  def delete(tr, id) do
    validator = get(tr, id)
    ThunderRAM.delete(tr, @trdb, id)
    ValidatorName.delete(tr, validator.name)
  end

  def total(tr) do
    ThunderRAM.count(tr, @trdb)
  end
end

defmodule Hashpay.ValidatorName do
  @trdb :validator_names_idx

  def dbopts do
    [
      name: @trdb,
      handle: ~c"validator_names_idx",
      exp: true
    ]
  end

  def put(tr, name, id) do
    ThunderRAM.put(tr, @trdb, name, id)
  end

  def exists?(tr, name) do
    ThunderRAM.exists?(tr, @trdb, name)
  end

  def delete(tr, name) do
    ThunderRAM.delete(tr, @trdb, name)
  end
end
