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

  def run([direction | args]) do
    {opts, _, _} = OptionParser.parse(args, switches: [version: :integer])
    :application.ensure_all_started(:telemetry)
    :application.ensure_all_started(:xandra)
    conn = Hashpay.DB.get_conn_with_retry()
    version = opts[:version] || 1

    case {direction, version} do
      {"up", version} when is_integer(version) ->
        IO.puts("Create migration version #{version}")
        up(conn, version)
        IO.puts("Migration version #{version} created")

      {"down", version} when is_integer(version) ->
        IO.puts("Delete migration version #{version}")
        down(conn, version)
        IO.puts("Migration version #{version} deleted")

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
