defmodule Hashpay.CLI do
  def main(args) do
    case args do
      ["run"] ->
        Mix.Tasks.Run.run(["--no-halt", "--no-compile"])

      _ ->
        IO.puts("Usage: hashpay run")
    end
  end
end
