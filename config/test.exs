import Config

# Configuración para el entorno de pruebas

# Configuración para el logger en pruebas
config :logger, level: :warning

# Configuración para ScyllaDB/Cassandra usando Xandra
config :hashpay, :scylla,
  nodes: ["127.0.0.1:9042"],
  keyspace: "hashpay_test",
  pool_size: 5,
  authentication: nil,
  retry_count: 1,
  retry_delay: 500

# Configuración para el pool de procesos
config :hashpay, :poolboy,
  size: 2,
  max_overflow: 1

# Configuración para Broadway
config :hashpay, :broadway,
  producer_module: nil,  # Módulo productor a definir
  processors: [
    default: [concurrency: 1]
  ],
  batchers: [
    default: [concurrency: 1, batch_size: 5]
  ]

# Configuración para HMAC
config :hashpay, :hmac,
  default_secret: "test_secret_key",
  algorithm: :sha256
