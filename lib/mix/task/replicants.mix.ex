defmodule Mix.Tasks.Replicants do
  use Mix.Task
  @filename "replicants.hosts"

  def run(args) do
    opts = Application.get_env(:hashpay, Hashpay.UdpCLI)
    ip = Keyword.get(opts, :ip, {127, 0, 0, 1})
    port = Keyword.get(opts, :port, 27_100)

    case args do
      ["add", hostname] ->
        text = IO.iodata_to_binary([hostname, "\n"])
        File.write!(@filename, text, [:append])
        call_load(ip, port, hostname)

      ["remove", hostname] ->
        content =
          File.read!(@filename)
          |> String.trim()
          |> String.split("\n", trim: true)
          |> Enum.filter(&(&1 != hostname))
          |> Enum.join("\n")

        File.write!(@filename, content)
        call_load(ip, port, hostname)

      _ ->
        IO.puts("""
        Usage: mix replicants [add|remove] <hostname>
        """)
    end
  end

  defp call_load(ip, port, hostname) do
    case Udp.call(ip, port, %{"action" => "replicant_update", "data" => hostname}) do
      {:ok, response} ->
        IO.puts("Replicant updated: #{inspect(response)}")

      {:error, _reason} ->
        IO.puts("Node not response")
    end
  end
end
