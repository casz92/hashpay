defmodule Hashpay.Payday do
  @moduledoc """
  Estructura y funciones para los saldos de los paydays de la blockchain de Hashpay.

  Un payday contiene:
  - id: Identificador único del payday
  - account_id: Identificador de la cuenta a la que pertenece el payday
  - currency_id: Identificador de la moneda del payday
  - last_payday: Último payday procesado
  - last_withdraw: Último retiro procesado
  - creation: Marca de tiempo de creación del payday
  """

  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          last_payday: non_neg_integer(),
          last_withdraw: non_neg_integer(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :last_payday,
    :last_withdraw,
    creation: 0
  ]

  @prefix "pdy_"
  @regex ~r/^pdy_[a-zA-Z0-9]*$/
  @trdb :paydays

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def generate_id(account_id, currency_id) do
    hash =
      [account_id, currency_id]
      |> IO.iodata_to_binary()
      |> Hashpay.hash()
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  # def new(
  #       _attrs = %{
  #         "account_id" => account_id,
  #         "currency_id" => currency_id,
  #         "last_payday" => last_payday,
  #         "last_withdraw" => last_withdraw
  #       }
  #     ) do
  #   last_round_id = Hashpay.get_last_round_id()

  #   %__MODULE__{
  #     id: generate_id(account_id, currency_id),
  #     account_id: account_id,
  #     currency_id: currency_id,
  #     last_payday: last_payday,
  #     last_withdraw: last_withdraw,
  #     creation: last_round_id
  #   }
  # end

  def new(account_id, currency_id) do
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(account_id, currency_id),
      account_id: account_id,
      currency_id: currency_id,
      last_payday: 0,
      last_withdraw: 0,
      creation: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"paydays",
      exp: true
    ]
  end

  def fetch(tr, id) do
    ThunderRAM.fetch(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = payday) do
    ThunderRAM.put(tr, @trdb, payday.id, payday)
  end

  def exists?(tr, id) do
    ThunderRAM.exists?(tr, @trdb, id)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
