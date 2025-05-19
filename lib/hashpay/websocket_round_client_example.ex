defmodule Hashpay.WebSocketRoundClientHandler do
  @moduledoc """
  Módulo para manejar conexiones WebSocket.
  Permite a los clientes conectarse a canales y comunicarse entre sí.
  """
  require Logger
  alias EventBus.Model.Event
  alias Hashpay.PubSub
  alias Hashpay.{Round, Block}

  @behaviour WebSock

  # Canal por defecto
  @default_channel Application.compile_env(:hashpay, :default_channel)
  @channel Application.compile_env(:hashpay, :channel)
  # @response_ok Jason.encode!(%{"status" => "ok"})
  @response_not_found Jason.encode!(%{"status" => "error", "msg" => "Not found"})

  @impl WebSock
  def init(args) do
    # Obtener parámetros de la conexión
    sender_id = Keyword.get(args, :sender)
    channel = Keyword.get(args, :channel, @channel)

    # Crear el estado inicial
    state = %{
      sender: sender_id,
      channel: channel,
      connected_at: DateTime.utc_now()
    }

    # Suscribirse al canal
    PubSub.subscribe(@default_channel)
    PubSub.subscribe(channel)

    Logger.debug(
      "WebSocket connection initialized for sender: #{sender_id} in channel: #{channel}"
    )

    {:ok, state}
  end

  @impl WebSock
  def handle_in({text, _opts}, state) do
    # Intentar decodificar el mensaje como JSON
    case CBOR.decode(text) do
      {:ok, %{"type" => "ping"}, _} ->
        # Es un ping, responder con un pong
        response = CBOR.encode(%{"type" => "pong"})
        {:push, {:binary, response}, state}

      {:ok, %{"type" => type, "args" => args}, _} ->
        case type do
          "round" ->
            round = Round.to_struct(args)
            event = %Event{id: generate_event_id(), topic: :round_received, data: round}
            EventBus.notify(event)

          "block" ->
            block = Block.to_struct(args)
            event = %Event{id: generate_event_id(), topic: :block_received, data: block}
            EventBus.notify(event)
        end

        {:noreply, state}

      _ ->
        {:push, {:text, @response_not_found}, state}
    end
  end

  @impl WebSock
  def handle_info({:channel_message, message}, state) do
    # Manejar mensajes recibidos del canal
    encoded = CBOR.encode(message)
    {:push, {:binary, encoded}, state}
  end

  @impl WebSock
  def handle_info(message, state) do
    Logger.info("Received unexpected message: #{inspect(message)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, state) do
    # Cancelar la suscripción al canal
    PubSub.unsubscribe(@default_channel)
    PubSub.unsubscribe(state.channel)

    Logger.info(
      "WebSocket connection terminated for user: #{state.sender}, channel: #{state.channel}, reason: #{inspect(reason)}"
    )

    :ok
  end

  defp generate_event_id do
    :rand.bytes(6) |> Base62.encode()
  end
end
