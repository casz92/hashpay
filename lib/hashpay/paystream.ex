defmodule Hashpay.Paystream do
  @moduledoc """
  Estructura y funciones para los saldos de los paystreams de la blockchain de Hashpay.

  Un paystream contiene:
  - id: Identificador único del paystream
  - account_id: Identificador de la cuenta a la que pertenece el paystream
  - currency_id: Identificador de la moneda del paystream
  - merchant_id: Identificador del comercio al que pertenece el paystream
  - last_paystream: Último paystream procesado
  - creation: Marca de tiempo de creación del paystream
  """
  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          merchant_id: String.t(),
          last_paystream: non_neg_integer(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :merchant_id,
    :last_paystream,
    creation: 0
  ]

  @prefix "pstr_"
  @regex ~r/^pstr_[a-zA-Z0-9]*$/
  @trdb :paystreams

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def generate_id(account_id, currency_id, merchant_id) do
    hash =
      [account_id, currency_id, merchant_id]
      |> IO.iodata_to_binary()
      |> Hashpay.hash()
      |> :binary.part(0, 20)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(
        account_id,
        currency_id,
        merchant_id
      ) do
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(account_id, currency_id, merchant_id),
      account_id: account_id,
      currency_id: currency_id,
      merchant_id: merchant_id,
      last_paystream: 0,
      creation: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      exp: true
    ]
  end

  def fetch(tr, id) do
    ThunderRAM.fetch(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = paystream) do
    ThunderRAM.put(tr, @trdb, paystream.id, paystream)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
