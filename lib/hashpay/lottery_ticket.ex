defmodule Hashpay.LotteryTicket do
  @moduledoc """
  Estructura y funciones para los tickets de lotería de la blockchain de Hashpay.
  Un ticket de lotería contiene:
  - id: Identificador único del ticket
  - lottery_id: Identificador de la lotería a la que pertenece el ticket
  - account_id: Identificador de la cuenta que compró el ticket
  - number: Número del ticket
  - creation: Marca de tiempo de creación del ticket
  """
  import Hashpay, only: [hash: 1]

  @type t :: %__MODULE__{
          id: String.t(),
          lottery_id: String.t(),
          account_id: String.t(),
          number: String.t(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :lottery_id,
    :account_id,
    :number,
    creation: 0
  ]

  @prefix "ltt_"
  @regex ~r/^ltt_[a-zA-Z0-9]$/
  @trdb :lottery_tickets

  def generate_id(lottery_id, account_id, number) do
    hash =
      [lottery_id, account_id, number]
      |> Enum.join("|")
      |> hash()
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(attrs) do
    lottery_id = attrs[:lottery_id]
    account_id = attrs[:account_id]
    number = attrs[:number]
    creation = attrs[:creation]

    %__MODULE__{
      id: generate_id(lottery_id, account_id, number),
      lottery_id: lottery_id,
      account_id: account_id,
      number: number,
      creation: creation
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"lottery_tickets",
      exp: true
    ]
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = ticket) do
    ThunderRAM.put(tr, @trdb, ticket.id, ticket)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
