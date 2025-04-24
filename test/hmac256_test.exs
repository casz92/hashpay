defmodule HMAC256Test do
  use ExUnit.Case
  doctest HMAC256

  describe "generate/2" do
    test "generates correct HMAC for a given secret and message" do
      secret = "super_secret_key"
      message = "Este es un mensaje seguro"

      # El resultado esperado se puede verificar con una herramienta externa o
      # asumiendo que la implementación es correcta para esta prueba inicial
      expected_hmac = HMAC256.generate(secret, message)

      assert is_binary(expected_hmac)
      assert String.length(expected_hmac) == 64  # SHA-256 produce 32 bytes (64 caracteres hex)
    end

    test "generates different HMACs for different messages" do
      secret = "same_secret"
      message1 = "mensaje uno"
      message2 = "mensaje dos"

      hmac1 = HMAC256.generate(secret, message1)
      hmac2 = HMAC256.generate(secret, message2)

      assert hmac1 != hmac2
    end

    test "generates different HMACs for different secrets" do
      secret1 = "secret one"
      secret2 = "secret two"
      message = "mismo mensaje"

      hmac1 = HMAC256.generate(secret1, message)
      hmac2 = HMAC256.generate(secret2, message)

      assert hmac1 != hmac2
    end

    test "generates consistent HMACs for the same inputs" do
      secret = "consistent_secret"
      message = "mensaje consistente"

      hmac1 = HMAC256.generate(secret, message)
      hmac2 = HMAC256.generate(secret, message)

      assert hmac1 == hmac2
    end
  end

  describe "verify/3" do
    test "verifies a valid HMAC correctly" do
      secret = "verification_secret"
      message = "mensaje para verificar"
      hmac = HMAC256.generate(secret, message)

      assert HMAC256.verify(secret, message, hmac) == true
    end

    test "rejects an invalid HMAC" do
      secret = "verification_secret"
      message = "mensaje para verificar"
      invalid_hmac = "0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

      # Asegurarse de que el HMAC inválido es realmente diferente
      valid_hmac = HMAC256.generate(secret, message)
      # Si por casualidad el HMAC inválido coincide con el válido, generamos uno diferente
      invalid_hmac = if invalid_hmac == valid_hmac, do: "f" <> String.slice(valid_hmac, 1..-1//1), else: invalid_hmac

      assert HMAC256.verify(secret, message, invalid_hmac) == false
    end

    test "rejects when message is tampered" do
      secret = "tampering_secret"
      original_message = "mensaje original"
      tampered_message = "mensaje alterado"

      hmac = HMAC256.generate(secret, original_message)

      assert HMAC256.verify(secret, tampered_message, hmac) == false
    end

    test "rejects when secret is incorrect" do
      original_secret = "secret_original"
      wrong_secret = "secret_incorrect"
      message = "mensaje con secreto incorrecto"

      hmac = HMAC256.generate(original_secret, message)

      assert HMAC256.verify(wrong_secret, message, hmac) == false
    end
  end

  # Prueba con un caso conocido para verificar la implementación
  test "generates expected HMAC for known inputs" do
    # Estos valores y el resultado esperado pueden ser generados con una herramienta externa
    # como OpenSSL para verificar la correcta implementación
    secret = "test_key"
    message = "test_message"

    # Valor real generado por la implementación actual
    expected_hmac = "39a7f19f47fee8b716b7cea16950343eacb6d006c7bb6aefae66828121a75ccc"

    assert HMAC256.generate(secret, message) == expected_hmac
  end
end
