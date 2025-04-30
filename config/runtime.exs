import Config

# Configuración en tiempo de ejecución
# Este archivo se ejecuta después de la compilación cuando la aplicación se inicia

config :hashpay, :s3_endpoint, System.get_env("S3_ENDPOINT", "")

if config_env() == :prod do
  # Configuración de puertos HTTP/HTTPS para producción
  http_port = String.to_integer(System.get_env("HTTP_PORT", "8080"))
  https_port = String.to_integer(System.get_env("HTTPS_PORT", "8443"))

  config :hashpay,
    http_port: http_port,
    https_port: https_port

  # Configuración de certificados SSL para producción
  ssl_key_path = System.get_env("SSL_KEY_PATH")
  ssl_cert_path = System.get_env("SSL_CERT_PATH")

  if ssl_key_path && ssl_cert_path do
    config :hashpay, :ssl,
      keyfile: ssl_key_path,
      certfile: ssl_cert_path
  end

  # Configuración de ScyllaDB/Cassandra para producción
  scylla_nodes =
    System.get_env("SCYLLA_NODES", "localhost:9042")
    |> String.split(",")

  scylla_username = System.get_env("SCYLLA_USERNAME")
  scylla_password = System.get_env("SCYLLA_PASSWORD")

  if scylla_username && scylla_password do
    config :hashpay, :scylla, authentication: {scylla_username, scylla_password}
  end

  config :hashpay, :scylla,
    nodes: scylla_nodes,
    keyspace: System.get_env("SCYLLA_KEYSPACE", "hashpay_dev")
end

# Configuración de la carpeta de datos
config :hashpay, :data_folder, System.get_env("DATA_FOLDER", "priv/data")

s3_scheme = "https://"
s3_host = "localhost"
s3_region = "lon"

config :ex_aws,
  access_key_id: "DOM",
  secret_access_key: "secret",
  region: "lon",
  s3: [
    scheme: s3_scheme,
    host: s3_host,
    region: s3_region
  ]

config :hashpay, :s3_endpoint, [s3_scheme, s3_region, ".", s3_host] |> IO.iodata_to_binary()
config :hashpay, :s3_bucket, System.get_env("S3_BUCKET", "my-bucket")

config :hashpay,
       :deny_function,
       System.get_env("DENY_FUNCTION", "") |> String.split(",", trim: true)
