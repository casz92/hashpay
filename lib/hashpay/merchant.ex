defmodule Hashpay.Merchant do
  @moduledoc """
  Estructura y funciones para los comercios de la blockchain de Hashpay.

  Un comercio contiene:
  - id: Identificador único del comercio
  - name: Nombre del comercio
  - channel: Canal donde opera el comercio
  - pubkey: Clave pública del comercio
  - picture: URL de la imagen del comercio
  - active: Estado del comercio (activo o no)
  - creation: Marca de tiempo de creación del comercio
  - updated: Marca de tiempo de última actualización del comercio
  """
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          channel: String.t(),
          pubkey: binary(),
          picture: String.t() | nil,
          active: boolean(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :channel,
    :pubkey,
    :picture,
    :active,
    :creation,
    :updated
  ]

  alias Hashpay.MerchantName

  @prefix "mc_"
  @regex ~r/^mc_[a-zA-Z0-9]*$/
  @trdb :merchants

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base62.encode(first16bytes)])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(attrs = %{"pubkey" => pubkey, "name" => name, "channel" => channel}) do
    last_round_id = Hashpay.get_last_round_id()
    pubkey = Base.decode64!(pubkey)

    %__MODULE__{
      id: generate_id(pubkey),
      name: name,
      channel: channel,
      pubkey: pubkey,
      picture: Map.get(attrs, "picture", nil),
      active: true,
      creation: last_round_id,
      updated: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"merchants",
      exp: true
    ]
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = merchant) do
    ThunderRAM.put(tr, @trdb, merchant.id, merchant)
  end

  def put_new(tr, %__MODULE__{} = merchant) do
    ThunderRAM.put(tr, @trdb, merchant.id, merchant)
    MerchantName.put(tr, merchant.name, merchant.id)
  end

  def exists?(tr, id) do
    ThunderRAM.exists?(tr, @trdb, id)
  end

  def delete(tr, %__MODULE__{} = merchant) do
    ThunderRAM.delete(tr, @trdb, merchant.id)
    MerchantName.delete(tr, merchant.name)
  end

  def delete(tr, id) do
    merchant = get(tr, id)
    ThunderRAM.delete(tr, @trdb, id)
    MerchantName.delete(tr, merchant.name)
  end
end

defmodule Hashpay.MerchantName do
  @trdb :merchant_names_idx

  def dbopts do
    [
      name: @trdb,
      handle: ~c"merchant_names_idx",
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
