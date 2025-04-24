# Script para generar certificados SSL de desarrollo
# Ejecutar con: mix run priv/certs/generate_certs.exs

# Directorio donde se guardarán los certificados
cert_dir = Path.expand("../certs", __DIR__)
File.mkdir_p!(cert_dir)

# Generar un certificado autofirmado para localhost
{:ok, key} = :public_key.generate_key({:rsa, 2048, 65537})
key_pem = :public_key.pem_encode([:public_key.pem_entry_encode(:RSAPrivateKey, key)])

# Crear un certificado válido para localhost
otp_cert = :public_key.pkix_test_root_cert(
  {"CN", "localhost"},
  [{:extensions, [
    {:subject_alt_name, ["localhost", "127.0.0.1"]}
  ]}],
  key
)

cert_der = :public_key.der_encode(:OTPCertificate, otp_cert)
cert_pem = :public_key.pem_encode([:public_key.pem_entry_encode(:Certificate, cert_der)])

# Guardar los archivos
File.write!(Path.join(cert_dir, "key.pem"), key_pem)
File.write!(Path.join(cert_dir, "cert.pem"), cert_pem)

IO.puts("Certificados SSL generados en #{cert_dir}")
IO.puts("- key.pem: Clave privada")
IO.puts("- cert.pem: Certificado autofirmado para localhost")
IO.puts("NOTA: Estos son certificados autofirmados para desarrollo.")
IO.puts("      En un entorno de producción, deberías usar certificados reales.")
