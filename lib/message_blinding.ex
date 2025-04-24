defmodule MessageBlinding do
  @moduledoc """
  Módulo para cegar y descegar mensajes utilizando un factor aleatorio.
  """
  require :crypto
  @hash_algorithm :sha256
  @size 32

  @doc """
  Cega un mensaje utilizando un factor aleatorio.
  Retorna el mensaje cegado y el factor de cegado.
  """
  @spec blind(binary()) :: {binary(), binary()}
  def blind(message) do
    # Generar un factor aleatorio de cegado (32 bytes)
    blinding_factor = :crypto.strong_rand_bytes(@size)
    # Calcular el hash del mensaje
    message_hash = :crypto.hash(@hash_algorithm, message)
    # Aplicar cegado usando XOR
    blinded_message = :crypto.exor(message_hash, blinding_factor)

    {blinded_message, blinding_factor}
  end

  @doc """
  Descega un mensaje cegado utilizando el factor de cegado.
  Retorna el mensaje original.
  """
  @spec unblind({binary(), binary()}) :: binary()
  def unblind({blinded_message, blinding_factor}) do
    # Revertir el efecto del cegado utilizando XOR
    :crypto.exor(blinded_message, blinding_factor)
  end

  def unblind(_), do: raise(FunctionClauseError, message: "Invalid blinded message format")

  @spec unblind(binary(), binary()) :: binary()
  def unblind(blinded_message, blinding_factor) do
    # Revertir el efecto del cegado utilizando XOR
    :crypto.exor(blinded_message, blinding_factor)
  end
end
