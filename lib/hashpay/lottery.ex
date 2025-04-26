defmodule Lottery do
  require :crypto

  def generate_ticket(id, secret) do
    :crypto.mac(:hmac, :sha256, secret, Integer.to_string(id))
    |> Base.encode16()
  end

  @doc """
  Calcula el número ganador de la lotería.

  ## Parámetros

  - `codes`: Lista de códigos de los tickets vendidos

  ## Retorno

  - Número ganador de la lotería
  """
  @spec calculate_winner([binary()]) :: String.t()
  def calculate_winner(codes, digits \\ 3) when digits > 0 do
    divisor = :math.pow(10, digits) |> trunc()

    codes
    # Convierte los códigos a enteros
    |> Enum.map(&:binary.decode_unsigned(&1))
    |> Enum.sum()
    # Calcula el módulo para obtener el número ganador
    |> Kernel.rem(divisor)
    |> Kernel.to_string()
    |> String.pad_leading(digits, "0")
  end
end
