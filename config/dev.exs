import Config

# Configuración para el entorno de desarrollo

# Configuración para el servidor HTTP/HTTPS
config :hashpay,
  http_port: 5000,
  https_port: 5001

# Configuración para ScyllaDB/Cassandra usando Xandra
config :hashpay, :scylla,
  nodes: ["localhost:9042"],
  keyspace: "hashpay_dev",
  # authentication: {"username", "password"},
  connect_timeout: 5000,
  name: :xandra_pool,
  default_consistency: :one,
  encryption: false,
  max_concurrent_requests_per_connection: 100,
  protocol_version: :v4,
  show_sensitive_data_on_connection_error: true,
  transport_options: [
    # Tamaño del buffer en bytes
    buffer: 1_000_000
  ]

# Configuración para el logger en desarrollo
config :logger, :console,
  format: "[$level] $message\n",
  level: :debug

# Configuración para el pool de procesos
config :hashpay, :poolboy,
  size: 5,
  max_overflow: 2

# Configuración para Broadway
config :hashpay, :broadway,
  # Módulo productor a definir
  producer_module: nil,
  processors: [
    default: [concurrency: 2]
  ],
  batchers: [
    default: [concurrency: 2, batch_size: 10]
  ]

# Configuración para HMAC
config :hashpay, :hmac,
  default_secret: "dev_secret_key",
  algorithm: :sha256
