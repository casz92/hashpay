defmodule Hashpay.Plan do
  @moduledoc """
  Estructura y funciones para los planes de pago de la blockchain de Hashpay.
  Un plan de pago contiene:
  - id: Identificador único del plan
  - merchant_id: Identificador del comercio al que pertenece el plan
  - currency_id: Identificador de la moneda del plan
  - amount: Cantidad de la moneda en el plan
  - status: Estado del plan (0: activo, 1: cancelado, 2: vencido)
  - period: Periodo de tiempo del plan (en días)
  - due_date: Fecha limite de vencimiento del plan (en timestamp)
  - description: Descripción del plan
  - creation: Marca de tiempo de creación del plan
  """

  @type t :: %__MODULE__{
          id: String.t(),
          merchant_id: String.t(),
          currency_id: String.t(),
          amount: non_neg_integer(),
          status: non_neg_integer(),
          period: non_neg_integer(),
          due_date: non_neg_integer(),
          description: String.t(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :merchant_id,
    :currency_id,
    :amount,
    :period,
    :due_date,
    :description,
    status: 0,
    creation: 0
  ]

  @prefix "plan_"
  @regex ~r/^plan_[a-zA-Z0-9]*$/
  @trdb :plans

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def generate_id(merchant_id, currency_id, amount, period) do
    hash =
      [merchant_id, currency_id, Integer.to_string(amount), Integer.to_string(period)]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(attrs) do
    merchant_id = attrs[:merchant_id]
    currency_id = attrs[:currency_id]
    amount = attrs[:amount]
    period = attrs[:period]

    %__MODULE__{
      id: generate_id(merchant_id, currency_id, amount, period),
      merchant_id: merchant_id,
      currency_id: currency_id,
      amount: amount,
      period: period,
      due_date: attrs[:due_date],
      description: attrs[:description],
      creation: Hashpay.get_last_round_id()
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"plans",
      exp: true
    ]
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = plan) do
    ThunderRAM.put(tr, @trdb, plan.id, plan)
  end

  def delete(tr, %__MODULE__{} = plan) do
    ThunderRAM.delete(tr, @trdb, plan.id)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
