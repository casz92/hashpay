defmodule Hashpay.Application do
  @moduledoc """
  Módulo de aplicación para Hashpay.
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Obtener configuración del entorno
    http_port = get_env(:http_port, 4000)
    https_port = get_env(:https_port, 4001)

    db_opts = Application.get_env(:hashpay, :scylla)

    # Inicializar la conexión a ScyllaDB
    # init_scylla_connection()

    # Configuración para HTTP
    children = [
      # PubSub para comunicación entre procesos
      Hashpay.PubSub,
      # Conexión a ScyllaDB
      {Hashpay.DB, db_opts},
      # Servidor HTTP
      {Bandit, plug: Hashpay.Router, port: http_port, startup_log: :info},

      # Servidor HTTPS
      {Bandit,
       plug: Hashpay.Router,
       scheme: :https,
       port: https_port,
       keyfile: cert_path("key.pem"),
       certfile: cert_path("cert.pem"),
       cipher_suite: :strong,
       startup_log: :info,
       otp_app: :hashpay}

      # Otros servicios pueden agregarse aquí
      # {Hashpay.Broadway, []},
      # {Hashpay.WorkerSupervisor, []}
    ]

    # Mostrar información de inicio
    Logger.info("Iniciando Hashpay...")

    # Ver https://hexdocs.pm/elixir/Supervisor.html
    # para otras estrategias y opciones
    opts = [strategy: :one_for_one, name: Hashpay.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Función auxiliar para obtener configuración del entorno
  defp get_env(key, default) do
    case Application.get_env(:hashpay, key) do
      nil -> default
      value -> value
    end
  end

  # Función auxiliar para obtener la ruta de los certificados
  defp cert_path(file) do
    Path.join(Application.app_dir(:hashpay, "priv/certs"), file)
  end
end
