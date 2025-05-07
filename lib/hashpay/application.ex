defmodule Hashpay.Application do
  @moduledoc """
  Módulo de aplicación para Hashpay.
  """
  # alias Hashpay.Block
  # alias Hashpay.Round
  # alias Hashpay.Member
  # alias Hashpay.Plan
  # alias Hashpay.Balance
  # alias Hashpay.Payday
  # alias Hashpay.Paystream
  # alias Hashpay.Holding
  # alias Hashpay.LotteryTicket
  # alias Hashpay.Merchant
  # alias Hashpay.Account
  # alias Hashpay.DB
  # alias Hashpay.Validator
  # alias Hashpay.Variable
  # alias Hashpay.Currency
  # alias Hashpay.Lottery
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
    # db_opts = get_env(:postgres, nil)

    # Inicializar estado
    init_state()

    # Configuración para HTTP
    children = [
      {SpawnPool, name: :worker_pool, size: threads, worker: Hashpay.Worker},
      :poolboy.child_spec(:event_consumer_pool, get_env(:event_consumer_pool, nil)),
      {RoundEventConsumer, []},
      Hashpay.Cache,
      # PubSub para comunicación entre procesos
      Hashpay.PubSub,
      {Hashpay.Cluster, name: :cluster},
      # Conexión a ScyllaDB
      # {Hashpay.DB, db_opts},
      # {Hashpay.Redis, get_env(:redis, [])},
      # Conexión a PostgreSQL
      # {Postgrex, get_env(:postgres, [])},
      # Servidor HTTP
      {Bandit, plug: Hashpay.Router, port: http_port, startup_log: :debug},

      # Servidor HTTPS
      {Bandit,
       plug: Hashpay.Router,
       scheme: :https,
       port: https_port,
       keyfile: cert_path("key.pem"),
       certfile: cert_path("cert.pem"),
       cipher_suite: :strong,
       startup_log: :debug,
       otp_app: :hashpay}
    ]

    # Mostrar información de inicio
    Logger.debug("Starting Hashpay v#{version} ⌛")

    # Ver https://hexdocs.pm/elixir/Supervisor.html
    # para otras estrategias y opciones
    opts = [strategy: :one_for_one, name: Hashpay.Supervisor]

    case Supervisor.start_link(children, opts) do
      {:ok, pid} ->
        # conn = DB.get_conn()
        setup_events()
        load_objects()
        Logger.info("Hashpay v#{version} started with #{threads} threads ✨")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Hashpay 💥\n#{inspect(reason)}")
        {:error, reason}
    end
  end

  defp init_state do
    ref = :counters.new(1, [:write_concurrency])
    :persistent_term.put(:thread_counter, ref)
  end

  defp load_objects do
    ThunderRAM.new(
      name: :blockchain,
      db: ~c"blockchain",
      cfs: [
        "variables",
        "rounds",
        "blocks",
        "accounts",
        "balances",
        "currencies",
        "merchants",
        "members",
        "plans",
        "paydays",
        "paystreams",
        "holdings",
        "lotteries",
        "lottery_tickets"
      ]
    )
    |> IO.inspect()

    # Round.init(conn)
    # Block.init(conn)
    # Variable.init(conn)
    # Currency.init(conn)
    # Validator.init(conn)
    # Account.init(conn)
    # Merchant.init(conn)
    # Balance.init(conn)
    # Member.init(conn)
    # Plan.init(conn)
    # Payday.init(conn)
    # Paystream.init(conn)
    # Holding.init(conn)
    # Lottery.init(conn)
    # LotteryTicket.init(conn)
  end

  defp setup_events do
    EventBus.subscribe(
      {BlockEventConsumer,
       [
         :block_creating,
         :block_created,
         :block_uploaded,
         :block_published,
         :block_received,
         :block_downloaded,
         :block_verifying,
         :block_failed,
         :block_completed
       ]}
    )
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
