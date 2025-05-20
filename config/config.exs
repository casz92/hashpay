import Config

# Configuración para el logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :blake3,
  simd_mode: :neon,
  rayon: true

# Importar configuración genesis
import_config "genesis.exs"

# Configuración del validador
config :hashpay, :channel, "first"
config :hashpay, :threads, System.schedulers_online()
config :hashpay, :quorum, type: "1/3", limit: 10

# ID del validador
config :hashpay, :id, "v_1UmjkVzfksJHu4UqEohMFB"

# Clave privada del validador
config :hashpay,
       :privkey,
       <<2, 193, 110, 47, 245, 211, 89, 165, 52, 151, 77, 240, 214, 234, 196, 83, 224, 67, 72,
         113, 134, 254, 250, 189, 206, 42, 16, 74, 91, 86, 232, 153>>

config :hashpay, :event_consumer_pool,
  name: {:local, :event_consumer_pool},
  worker_module: BlockEventConsumer,
  # Número de consumidores activos
  size: 5,
  # Procesos adicionales si el pool está lleno
  max_overflow: 2

config :event_bus,
  topics: [
    :block_created,
    :block_uploaded,
    :block_published,
    :block_received,
    :block_downloaded,
    :block_verifying,
    :block_failed,
    :block_completed,
    :round_start,
    :round_received,
    :round_published,
    :round_verified,
    :round_failed,
    :round_timeout,
    :round_skipped,
    :round_ended,
    :validator_created,
    :validator_updated,
    :validator_deleted
  ]

config :ex_aws, json_codec: Jason

# Configuración de Ecto y SQLite3
config :hashpay, ecto_repos: [Hashpay.Repo]

config :hashpay, Hashpay.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: Path.expand("../priv/data/tasks.db", Path.dirname(__ENV__.file)),
  pool_size: 5

# Configuración de Oban
config :hashpay, Oban,
  repo: Hashpay.Repo,
  engine: Oban.Engines.Lite,
  plugins: [
    # 7 días
    {Oban.Plugins.Pruner, max_age: 60 * 60 * 24 * 7},
    {Oban.Plugins.Cron,
     crontab: [
       # Diariamente a medianoche
       {"0 0 * * *", Hashpay.Workers.DailyCleanup}
       # Cada 15 minutos
       #  {"*/15 * * * *", Hashpay.Workers.PeriodicCheck}
     ]}
  ],
  queues: [default: 10, background: 5, critical: 3],
  peer: false

# Importar configuraciones específicas del entorno
import_config "#{config_env()}.exs"
