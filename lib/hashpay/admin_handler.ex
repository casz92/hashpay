defmodule Hashpay.Admin.Handler do
  @moduledoc """
  Módulo para manejar conexiones WebSocket.
  Permite a los clientes conectarse a canales y comunicarse entre sí.
  """
  require Logger
  alias Hashpay.PubSub
  alias Hashpay.SystemInfo
  alias Hashpay.Validator

  @behaviour WebSock

  # Canal por defecto
  @channel "admin"

  @impl WebSock
  def init(args) do
    node_id = Keyword.get(args, :id) || random_id()

    state = %{
      id: node_id,
      connected_at: DateTime.utc_now()
    }

    # Suscribirse al canal
    PubSub.subscribe(@channel)
    PubSub.subscribe(unique_channel(node_id))

    Logger.debug(
      "WebSocket connection initialized for sender: #{node_id} in channel: #{@channel}"
    )

    {:ok, state}
  end

  @impl WebSock
  def handle_in({text, _opts}, state) do
    # Intentar decodificar el mensaje como JSON
    case decode(text) do
      {:ok, %{"id" => id, "method" => "getInfo"}} ->
        response = SystemInfo.get_info() |> Map.put(:id, id)
        {:push, {:text, encode(response)}, state}

      {:ok, %{"id" => id, "method" => "getInfoSystem"}} ->
        response = SystemInfo.info_callback() |> Map.put(:id, id)
        {:push, {:text, encode(response)}, state}

      {:ok, %{"id" => id, "method" => "getInfoRoundchain"}} ->
        response = SystemInfo.roundchain_callback() |> Map.put(:id, id)
        {:push, {:text, encode(response)}, state}

      {:ok, %{"id" => id, "method" => "aboutMe"}} ->
        vid = Application.get_env(:hashpay, :id)
        db = ThunderRAM.get_tr(:blockchain)

        case Validator.fetch(db, vid) do
          {:ok, validator} ->
            response = %{id: id, data: validator}
            {:push, {:text, encode(response)}, state}

          _error ->
            {:push, {:text, encode(%{id: id, status: "error", msg: "Validator not found"})},
             state}
        end

      {:error, _decode} ->
        {:push, {:text, encode(%{status: "error", msg: "Invalid json format"})}, state}

      _ ->
        {:ok, state}
    end
  end

  @impl WebSock
  def handle_info({:channel_message, message}, state) do
    # Manejar mensajes recibidos del canal
    response = encode(message)

    {:push, {:text, response}, state}
  end

  @impl WebSock
  def handle_info(message, state) do
    Logger.info("Received unexpected message: #{inspect(message)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, state = %{id: id}) do
    # Cancelar la suscripción al canal
    PubSub.unsubscribe(@channel)
    PubSub.unsubscribe(unique_channel(id))

    Logger.info(
      "WebSocket connection terminated for user: #{state.id}, channel: #{state.channel}, reason: #{inspect(reason)}"
    )

    :ok
  end

  defp random_id do
    :rand.bytes(4) |> Base62.encode()
  end

  defp unique_channel(id) do
    "#{@channel}:#{id}"
  end

  defp encode(message) do
    Jason.encode!(message)
  end

  defp decode(message) do
    Jason.decode(message)
  end
end
