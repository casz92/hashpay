defmodule Hashpay.UdpCLI do
  require Logger
  alias Hashpay.Roundchain

  def handle_in(%{"action" => "replicant_update", "data" => _node}, _sender_ip, _sender_port) do
    Logger.info("Replicant updated")
    Roundchain.load_replicants()
    {:reply, %{"status" => "ok"}}
  end

  def handle_in(_, _, _) do
    :ok
  end
end
