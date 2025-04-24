defmodule HMAC256 do
  @moduledoc """
  Módulo para generar y verificar hashes HMAC-SHA256 en Elixir.
  """

  @spec generate(String.t(), String.t()) :: String.t()
  def generate(secret, message) do
    :crypto.mac(:hmac, :sha256, secret, message)
    |> Base.encode16(case: :lower)
  end

  @spec verify(String.t(), String.t(), String.t()) :: boolean()
  def verify(secret, message, expected_hmac) do
    generate(secret, message) == expected_hmac
  end
end
