defmodule Mix.Tasks.Migrate do
  use Mix.Task
  alias Hashpay.ClusterNode
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
  alias Hashpay.Validator
  alias Hashpay.Variable
  alias Hashpay.Currency
  alias Hashpay.Lottery

  @shortdoc "Ejecuta la migración de la base de datos"
  @not_matched "Usage: mix migrate [up|down] --version <number>"

  def run([cmd | args]) do
    :application.ensure_all_started(:telemetry)
    :application.ensure_all_started(:xandra)

    db_opts =
      Application.get_env(:hashpay, :scylla)
      |> Keyword.put(:keyspace, "system")

    {:ok, conn} =
      Xandra.Cluster.start_link(db_opts)

    case cmd do
      "db.create" ->
        {opts, _, _} = OptionParser.parse(args, switches: [name: :string])
        name = opts[:name] || throw("--name is required")
        Hashpay.DB.create_keyspace(conn, name)
        IO.puts("Keyspace #{name} created")

      "db.drop" ->
        {opts, _, _} = OptionParser.parse(args, switches: [name: :string])
        name = opts[:name] || throw("--name is required")
        Hashpay.DB.drop_keyspace(conn, name)
        IO.puts("Keyspace #{name} dropped")

      "up" ->
        {opts, _, _} = OptionParser.parse(args, switches: [name: :string, version: :integer])
        name = opts[:name] || throw("--name is required")
        version = opts[:version] || 1
        Hashpay.DB.use_keyspace(conn, name)
        IO.puts("Migration version #{version} creating...")
        up(conn, version)
        IO.puts("Migration version #{version} created")

      "down" ->
        {opts, _, _} = OptionParser.parse(args, switches: [name: :string, version: :integer])
        name = opts[:name] || throw("--name is required")
        version = opts[:version] || 1
        Hashpay.DB.use_keyspace(conn, name)
        IO.puts("Migration version #{version} deleting...")
        down(conn, version)
        IO.puts("Migration version #{version} deleted")

      "help" ->
        IO.puts("""
        Usage: mix migrate [db.create|db.drop|up|down|help]
        - db.create: Crea el keyspace en ScyllaDB
        - db.drop: Elimina el keyspace en ScyllaDB
        - up: Aplica las migraciones
        - down: Deshace las migraciones
        - help: Muestra esta ayuda
        """)

      _ ->
        IO.puts(@not_matched)
    end
  end

  def run(_) do
    IO.puts(@not_matched)
  end

  defp up(conn, _version) do
    Round.up(conn)
    Block.up(conn)
    Variable.up(conn)
    Validator.up(conn)
    Currency.up(conn)
    Account.up(conn)
    Merchant.up(conn)
    Balance.up(conn)
    Member.up(conn)
    Plan.up(conn)
    Payday.up(conn)
    Paystream.up(conn)
    Holding.up(conn)
    Lottery.up(conn)
    LotteryTicket.up(conn)
    ClusterNode.up(conn)
  end

  defp down(conn, _version) do
    Round.down(conn)
    Block.down(conn)
    Variable.down(conn)
    Validator.down(conn)
    Currency.down(conn)
    Account.down(conn)
    Merchant.down(conn)
    Balance.down(conn)
    Member.down(conn)
    Plan.down(conn)
    Payday.down(conn)
    Paystream.down(conn)
    Holding.down(conn)
    Lottery.down(conn)
    LotteryTicket.down(conn)
    ClusterNode.down(conn)
  end
end
