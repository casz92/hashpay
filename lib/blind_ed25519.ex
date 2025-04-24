defmodule BlindEd25519 do
  @moduledoc """
  Implementación de firmas ciegas con Ed25519 utilizando Cafezinho.
  """

  alias Cafezinho.Impl
  require MessageBlinding

  # Generar clave privada y pública utilizando Cafezinho
  def generate do
    Impl.generate()
  end

  # Firmar el mensaje cegado utilizando Cafezinho
  def sign(message, private_key) do
    {blinded_message, blinding_factor} = MessageBlinding.blind(message)
    # Firmar el mensaje cegado
    {:ok, signature} = Impl.sign(blinded_message, private_key)

    {signature, blinded_message, blinding_factor}
  end

  # Verificar la firma con el mensaje cegado y clave pública
  def verify(signature, blinded_message, public_key) do
    Impl.verify(signature, blinded_message, public_key)
  end
end
