defmodule Hashpay.Application do
  @moduledoc """
  Módulo de aplicación para Hashpay.
  """
  alias Hashpay.Block
  alias Hashpay.Round
  alias Hashpay.Member
  alias Hashpay.Plan
  alias Hashpay.Balance
  alias Hashpay.Payday
  alias Hashpay.Paystream
  alias Hashpay.Holding
  alias Hashpay.LotteryTicket
  alias Hashpay.Merchant
  alias Hashpay.Account
  alias Hashpay.DB
  alias Hashpay.Validator
  alias Hashpay.Variable
  alias Hashpay.Currency
  alias Hashpay.Lottery
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # Obtener configuración del entorno
    make_folders()

    version = vsn()
    http_port = get_env(:http_port, 4000)
    https_port = get_env(:https_port, 4001)
    threads = get_env(:threads, 2)

    db_opts = get_env(:scylla, nil)

    # Inicializar la conexión a ScyllaDB
    # init_scylla_connection()

    # Configuración para HTTP
    children = [
      {SpawnPool, name: :worker_pool, size: threads, worker: Hashpay.Worker},
      # PubSub para comunicación entre procesos
      Hashpay.Hits,
      Hashpay.PubSub,
      {Hashpay.Cluster, name: :cluster},
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
    ]

    # Mostrar información de inicio
    Logger.info("Starting Hashpay v#{version} ⌛")

    # Ver https://hexdocs.pm/elixir/Supervisor.html
    # para otras estrategias y opciones
    opts = [strategy: :one_for_one, name: Hashpay.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        conn = DB.get_conn()
        load_objects(conn)
        Logger.info("Hashpay v#{version} started ✨")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Hashpay 💥: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp load_objects(conn) do
    Round.init(conn)
    Block.init(conn)
    Variable.init(conn)
    Currency.init(conn)
    Validator.init(conn)
    Account.init(conn)
    Merchant.init(conn)
    Balance.init(conn)
    Member.init(conn)
    Plan.init(conn)
    Payday.init(conn)
    Paystream.init(conn)
    Holding.init(conn)
    Lottery.init(conn)
    LotteryTicket.init(conn)
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

  defp make_folders do
    data_folder = Application.get_env(:hashpay, :data_folder)

    [
      Path.join(data_folder, "blocks")
    ]
    |> Enum.each(&File.mkdir_p!/1)
  end

  defp vsn do
    Application.spec(:hashpay, :vsn) |> to_string()
  end
end
