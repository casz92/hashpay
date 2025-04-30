defmodule Mix.Tasks.Gen.Certs do
  use Mix.Task

  @shortdoc "Genera certificados autofirmados para desarrollo"

  # def run(_) do
  #   cert_pem = File.read!("priv/certs/cert.pem")
  #   cert = X509.Certificate.from_pem!(cert_pem)

  #   # Ver el sujeto del certificado
  #   IO.inspect(X509.Certificate.subject(cert))
  #   # Ver quién lo emitió
  #   IO.inspect(X509.Certificate.issuer(cert))
  #   # Ver fechas de validez
  #   IO.inspect(X509.Certificate.validity(cert))
  #   IO.inspect(X509.Certificate.extensions(cert))
  #   IO.inspect(X509.Certificate.serial(cert))
  # end

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          rdn: :string,
          help: :boolean,
          validity: :integer,
          hostname: :string,
          dir: :string,
          keysize: :integer,
          eddsa: :boolean
        ]
      )

    case opts[:help] do
      true ->
        IO.puts("""
        Usage: mix gen.certs [options]
        Options:
          --help: Mostrar esta ayuda
          --rdn: RDN para el certificado root
          --rdnca: RDN para el certificado CA
          --validity: Número de días de validez del certificado
          --hostname: Nombre de host para el certificado
          --dir: Directorio donde se guardarán los archivos
          --keysize: Tamaño de la clave en bits
          --rsa: Usar RSA en lugar de EDDSA secp256r1
        """)

      _ ->
        rdn = Keyword.get(opts, :rdn, "/C=UK/L=London/O=Acme")
        rdnca = Keyword.get(opts, :rdnca, "/C=UK/L=London/O=Acme/CN=Sample")
        hostname = Keyword.get(opts, :hostname, "localhost") |> String.split(",", trim: true)
        validity = Keyword.get(opts, :validity, 365)
        certs_path = Keyword.get(opts, :dir, "priv/certs")
        rsa = Keyword.get(opts, :rsa, false)
        keysize = Keyword.get(opts, :keysize, 2048)

        ca_key =
          if rsa do
            X509.PrivateKey.new_rsa(keysize)
          else
            X509.PrivateKey.new_ec(:secp256r1)
          end

        ca =
          X509.Certificate.self_signed(
            ca_key,
            rdn,
            template: :root_ca,
            hash: :sha256,
            validity: validity
          )

        cert =
          ca_key
          |> X509.PublicKey.derive()
          |> X509.Certificate.new(
            rdnca,
            ca,
            ca_key,
            hash: :sha256,
            validity: validity,
            extensions: [
              subject_alt_name: X509.Certificate.Extension.subject_alt_name(hostname)
            ]
          )

        # Crear el directorio si no existe
        File.mkdir_p!(certs_path)

        # Guardar clave y certificado en archivos dentro de `priv/certs/`
        File.write!(Path.join(certs_path, "key.pem"), X509.PrivateKey.to_pem(ca_key))
        File.write!(Path.join(certs_path, "cert.pem"), X509.Certificate.to_pem(ca))
        File.write!(Path.join(certs_path, "cert.pem"), X509.Certificate.to_pem(cert), [:append])

        IO.puts("""
        Certificates generated in #{certs_path}
          Algorithm: #{if rsa, do: "RSA #{keysize} bits", else: "EDDSA secp256r1"}
          Validity: #{validity} days
          Hostnames: #{Enum.join(hostname, ", ")}
        """)
    end
  end
end
