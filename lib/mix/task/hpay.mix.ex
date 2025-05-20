defmodule Mix.Tasks.Hpay do
  use Mix.Task

  def run([first | rest]) do
    case first do
      "run" ->
        Mix.Tasks.Run.run(["--no-halt", "--no-compile"])

      "db.create" ->
        Mix.Tasks.Migrate.run(["db.create" | rest])

      "db.drop" ->
        Mix.Tasks.Migrate.run(["db.drop" | rest])

      "migrate" ->
        Mix.Tasks.Migrate.run(rest)

      "rollback" ->
        Mix.Tasks.Migrate.run(["down" | rest])

      "certs" ->
        Mix.Tasks.Certs.run(rest)

      "replicants" ->
        Mix.Tasks.Replicants.run(rest)

      x when x == "version" or x == "v" ->
        IO.puts("""
        Hashpay version v#{Application.spec(:hashpay, :vsn)}
        Copyright (C) 2019-2025 Hashpay developers team
        """)

      x when x == "help" or x == "h" ->
        IO.puts("""
        Usage: mix hpay [run|migrate|rollback|version|help]
        """)

      _ ->
        IO.puts("""
        Usage: mix hpay [run|migrate|rollback|version|help]
        """)
    end
  end

  def run(_) do
    IO.puts("""
    Usage: mix hpay [run|migrate|rollback|version|help]
    """)
  end
end
