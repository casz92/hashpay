defmodule Hashpay.Command do
  @moduledoc """
  Estructura y funciones para los comandos de la blockchain de Hashpay.

  Un comando contiene:
  - hash: Hash del comando
  - fun: Nombre de la función a ejecutar
  - args: Argumentos de la función
  - from: Identificador del emisor del comando
  - timestamp: Marca de tiempo de creación del comando
  - signature: Firma digital del emisor
  """
  @type t :: %__MODULE__{
      hash: binary() | nil,
      fun: String.t() | pos_integer(),
      args: list() | nil,
      from: String.t() | nil,
      signature: binary() | nil,
      timestamp: non_neg_integer()
  }

  defstruct [
    :hash,
    :fun,
    :args,
    :from,
    :signature,
    :timestamp
  ]

  def new(attrs) do
    %__MODULE__{
      hash: attrs[:hash],
      fun: attrs[:fun],
      args: attrs[:args],
      from: attrs[:from],
      signature: attrs[:signature],
      timestamp: attrs[:timestamp]
    }
  end

  def encode(%__MODULE__{} = command) do
    Jason.encode!(command)
  end

  def decode(json) do
    Jason.decode!(json, keys: :atoms)
  end

  def hash(command) do
    :crypto.hash(:sha256, encode(command))
  end

  def verify_hash(command, hash) do
    hash(command) == hash
  end

  def sign(command, private_key) do
    {:ok, signature} = Cafezinho.Impl.sign(hash(command), private_key)
    %{command | signature: signature}
  end

  def verify_signature(command, public_key) do
    Cafezinho.Impl.verify(command.signature, command.hash, public_key)
  end


end

defmodule Hashpay.Function do
 @moduledoc """
 Estructura para las funciones de la blockchain de Hashpay.

  Una función contiene:
  - id: Identificador único de la función
  - name: Nombre de la función
  - mod: Módulo que contiene la función
  - fun: Nombre de la función
  - auth_type: Tipo de autenticación requerida (0: ninguna, 1: firma digital)
  - segment: Segmento de la blockchain donde se ejecuta la función
 """

  defstruct [
    :id,
    :name,
    :mod,
    :fun,
    :auth_type,
    segment: 0
  ]

  @type t :: %__MODULE__{
    id: pos_integer(),
    name: String.t(),
    mod: module(),
    fun: atom(),
    auth_type: 0 | 1,
    segment: number()
  }

  alias Hashpay.Function

  def list do
    [
      %Function{id: 1, name: "createAccount", mod: Hashpay.Account.Commands, fun: :create, auth_type: 0},
      %Function{id: 2, name: "changePubkeyAccount", mod: Hashpay.Account.Commands, fun: :change_pubkey, auth_type: 1},
      %Function{id: 3, name: "changeNameAccount", mod: Hashpay.Account.Commands, fun: :change_name, auth_type: 1},
      %Function{id: 4, name: "changeChannelAccount", mod: Hashpay.Account.Commands, fun: :change_channel, auth_type: 1},
      %Function{id: 5, name: "verifyAccount", mod: Hashpay.Account.Commands, fun: :verify, auth_type: 1},

      %Function{id: 10, name: "createCurrency", mod: Hashpay.Currency.Commands, fun: :create, auth_type: 1},
      %Function{id: 11, name: "changePubkeyCurrency", mod: Hashpay.Currency.Commands, fun: :change_pubkey, auth_type: 1},
      %Function{id: 12, name: "changeNameCurrency", mod: Hashpay.Currency.Commands, fun: :change_name, auth_type: 1},




    ]
  end



end
