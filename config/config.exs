import Config

# Configuración común para todos los entornos
config :hashpay,
  ecto_repos: []

# Configuración para el logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Importar configuraciones específicas del entorno
import_config "#{config_env()}.exs"
