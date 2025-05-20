defmodule Hashpay.Lottery do
  @moduledoc """
  Estructura y funciones para las loterías de la blockchain de Hashpay.
  Una lotería contiene:
  - id: Identificador único de la lotería
  - description: Descripción de la lotería
  - prize_amount: Monto del premio de la lotería
  - prize_currency: Moneda del premio de la lotería
  - issuer: Emisor de la lotería
  - start_date: Fecha de inicio de la lotería
  - end_date: Fecha de finalización de la lotería
  - status: Estado de la lotería (0: active, 1: pending_to_claim, 2: finished, 3: cancelled)
  - match_digits: Número de dígitos que coinciden para ganar la lotería
  - number_winner: Número ganador de la lotería
  - channel: Canal donde se opera la lotería
  - claim_deadline: Fecha límite para reclamar el premio de la lotería
  - has_accumulated: Indica si la lotería acumula premios si no hay ganadores
  - min_participants: Número mínimo de participantes para que la lotería se considere válida
  - ticket_price: Precio de cada ticket de la lotería
  - max_winners: Número máximo de ganadores de la lotería
  - verification_url: URL de verificación de la lotería
  - creation: Marca de tiempo de creación de la lotería
  """
  import Hashpay, only: [hash: 1]

  @prefix "lt_"
  @regex ~r/^lt_[a-zA-Z0-9]$/
  @trdb :lotteries

  defstruct [
    :id,
    :description,
    :issuer,
    :prize_amount,
    :prize_currency,
    :start_date,
    :end_date,
    :status,
    :match_digits,
    :number_winner,
    :channel,
    :claim_deadline,
    :has_accumulated,
    :min_participants,
    :ticket_price,
    :max_winners,
    :verification_url,
    creation: 0
  ]

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def generate_id(account_id, hash) do
    hash =
      [account_id, hash]
      |> Enum.join("|")
      |> hash()
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(
        account_id,
        hash,
        attrs = %{
          "channel" => channel,
          "prize_amount" => prize_amount,
          "prize_currency" => prize_currency,
          "start_date" => start_date,
          "end_date" => end_date,
          "ticket_price" => ticket_price
        }
      ) do
    %__MODULE__{
      id: generate_id(account_id, hash),
      description: Map.get(attrs, "description", ""),
      issuer: account_id,
      prize_amount: prize_amount,
      prize_currency: prize_currency,
      start_date: start_date,
      end_date: end_date,
      status: Map.get(attrs, "status", 0),
      match_digits: Map.get(attrs, "match_digits", 3),
      number_winner: Map.get(attrs, "number_winner", "3"),
      channel: channel,
      claim_deadline: Map.get(attrs, "claim_deadline", 0),
      has_accumulated: Map.get(attrs, "has_accumulated", false),
      min_participants: Map.get(attrs, "min_participants", 0),
      ticket_price: ticket_price,
      max_winners: Map.get(attrs, "max_winners", 1),
      verification_url: Map.get(attrs, "verification_url", ""),
      creation: Hashpay.get_last_round_id()
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"lotteries",
      exp: true
    ]
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = lottery) do
    ThunderRAM.put(tr, @trdb, lottery.id, lottery)
  end

  def delete(tr, %__MODULE__{} = lottery) do
    ThunderRAM.delete(tr, @trdb, lottery.id)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end

  def change_status(tr, id, status) do
    case ThunderRAM.get(tr, @trdb, id) do
      {:ok, lottery} ->
        ThunderRAM.put(tr, @trdb, lottery.id, %{lottery | status: status})

      _ ->
        {:error, :not_found}
    end
  end

  # def generate_ticket(id, secret) do
  #   :crypto.mac(:hmac, :sha256, secret, Integer.to_string(id))
  #   |> Base.encode16()
  # end

  # @doc """
  # Calcula el número ganador de la lotería.

  # ## Parámetros

  # - `codes`: Lista de códigos de los tickets vendidos

  # ## Retorno

  # - Número ganador de la lotería
  # """
  # @spec calculate_winner([binary()]) :: String.t()
  # def calculate_winner(codes, digits \\ 3) when digits > 0 do
  #   divisor = :math.pow(10, digits) |> trunc()

  #   codes
  #   # Convierte los códigos a enteros
  #   |> Enum.map(&:binary.decode_unsigned(&1))
  #   |> Enum.sum()
  #   # Calcula el módulo para obtener el número ganador
  #   |> Kernel.rem(divisor)
  #   |> Kernel.to_string()
  #   |> String.pad_leading(digits, "0")
  # end
end
