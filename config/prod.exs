import Config

# Configuración para el entorno de producción

# Configuración para el servidor HTTP/HTTPS
config :hashpay,
  http_port: 8080,
  https_port: 8443

# No imprimir logs de depuración en producción
config :logger, :console,
  level: :info,
  compile_time_purge_level: :info

# Configuración para ScyllaDB/Cassandra usando Xandra
config :hashpay, :scylla,
  nodes: ["localhost:9042"],
  keyspace: "hashpay_prod",
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

# Configuración para el pool de procesos
config :hashpay, :poolboy,
  size: 10,
  max_overflow: 5

# Configuración para Broadway
config :hashpay, :broadway,
  # Módulo productor a definir
  producer_module: nil,
  processors: [
    default: [concurrency: 10]
  ],
  batchers: [
    default: [concurrency: 5, batch_size: 20]
  ]

# Configuración para HMAC
config :hashpay, :hmac,
  # El secreto debe ser configurado en runtime.exs
  algorithm: :sha256
