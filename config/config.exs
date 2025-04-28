import Config

# Configuración para el logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Importar configuración genesis
import_config "genesis.exs"

# Configuración del validador
config :hashpay, :channel, "first"
config :hashpay, :threads, System.schedulers_online()

# Importar configuraciones específicas del entorno
import_config "#{config_env()}.exs"
