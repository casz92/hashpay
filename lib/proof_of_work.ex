defmodule ProofOfWork do
  @moduledoc """
  Implementación de Proof of Work en Elixir con ajuste de dificultad y validación de nonce.
  """

  def mine_block(data, difficulty) do
    target = :crypto.hash(:sha256, String.duplicate("0", difficulty)) |> Base.encode16()
    find_nonce(data, target, 0)
  end

  defp find_nonce(data, target, nonce) do
    hash = :crypto.hash(:sha256, "#{data}#{nonce}") |> Base.encode16()

    if valid_nonce?(hash, target) do
      IO.puts("Bloque minado con nonce: #{nonce}")
      IO.puts("Hash encontrado: #{hash}")
      {nonce, hash}
    else
      find_nonce(data, target, nonce + 1)
    end
  end

  defp valid_nonce?(hash, target) do
    # Compara si el hash cumple con la dificultad establecida
    String.starts_with?(hash, String.duplicate("0", String.length(target) - 56))
  end
end

# Prueba con datos del bloque y dificultad
# ProofOfWork.mine_block("BlockData", 5)
