import Config

# Configuración para el entorno de producción

# Configuración para el servidor HTTP/HTTPS
config :hashpay,
  http_port: 8080,
  https_port: 8443

# No imprimir logs de depuración en producción
config :logger, level: :info

# Configuración para ScyllaDB/Cassandra usando Xandra
config :hashpay, :scylla,
  nodes: ["scylla-node1:9042", "scylla-node2:9042", "scylla-node3:9042"],
  keyspace: "hashpay_prod",
  pool_size: 20,
  authentication: nil,  # Se debe configurar en runtime.exs
  retry_count: 5,
  retry_delay: 2000

# Configuración para el pool de procesos
config :hashpay, :poolboy,
  size: 10,
  max_overflow: 5

# Configuración para Broadway
config :hashpay, :broadway,
  producer_module: nil,  # Módulo productor a definir
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
