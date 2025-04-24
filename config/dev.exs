import Config

# Configuración para el entorno de desarrollo

# Configuración para el servidor HTTP/HTTPS
config :hashpay,
  http_port: 5000,
  https_port: 5001

# Configuración para ScyllaDB/Cassandra usando Xandra
config :hashpay, :scylla,
  nodes: ["127.0.0.1:9042"],
  keyspace: "hashpay_dev",
  pool_size: 10,
  authentication: nil,
  # authentication: {username, password}
  retry_count: 3,
  retry_delay: 1000

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
  producer_module: nil,  # Módulo productor a definir
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
