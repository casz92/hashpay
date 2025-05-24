defmodule Hashpay.Holding do
  @moduledoc """
  Estructura y funciones para los holdings de la blockchain de Hashpay.

  Un holding contiene:
  - id: Identificador único del holding
  - account_id: Identificador de la cuenta a la que pertenece el holding
  - currency_id: Identificador de la moneda del holding
  - amount: Cantidad de la moneda en el holding
  - apr: Tasa de rendimiento anual del holding
  - creation: Marca de tiempo de creación del holding
  """
  import Hashpay, only: [hash: 1]

  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          amount: non_neg_integer(),
          apr: number(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :amount,
    :apr,
    creation: 0
  ]

  @prefix "ho_"
  @regex ~r/^ho_[a-zA-Z0-9]*$/
  @trdb :holdings

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def generate_id(account_id, currency_id, apr) do
    hash =
      [account_id, currency_id, Float.to_string(apr)]
      |> Enum.join("|")
      |> hash()
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(account_id, currency_id, amount, apr) do
    %__MODULE__{
      id: generate_id(account_id, currency_id, apr),
      account_id: account_id,
      currency_id: currency_id,
      amount: amount,
      apr: apr,
      creation: Hashpay.get_last_round_id()
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

  def put(tr, %__MODULE__{} = holding) do
    ThunderRAM.put(tr, @trdb, holding.id, holding)
  end

  def delete(tr, %__MODULE__{} = holding) do
    ThunderRAM.delete(tr, @trdb, holding.id)
  end
end
