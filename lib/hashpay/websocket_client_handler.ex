defmodule Hashpay.WebSocketClientHandler do
  @moduledoc """
  Módulo para manejar conexiones WebSocket.
  Permite a los clientes conectarse a canales y comunicarse entre sí.
  """
  require Logger
  alias Hashpay.Command
  alias Hashpay.PubSub

  @behaviour WebSock

  # Canal por defecto
  @default_channel Application.compile_env(:hashpay, :default_channel)
  @channel Application.compile_env(:hashpay, :channel)
  @response_ok Jason.encode!(%{"status" => "ok"})
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
    case Jason.decode(text) do
      {:ok, %{"type" => "ping"}} ->
        # Es un ping, responder con un pong
        response = Jason.encode!(%{type: "pong"})
        {:push, {:text, response}, state}

      {:ok, %{"fun" => _function} = map} ->
        command = Command.new(map, byte_size(text))

        response =
          case Command.handle(command) do
            {:error, reason} ->
              Logger.error("Error handling command: #{reason}")
              Jason.encode!(%{"status" => "error", "msg" => reason})

            _ ->
              @response_ok
          end

        {:push, {:text, response}, state}

      _ ->
        {:push, {:text, @response_not_found}, state}
    end
  end

  @impl WebSock
  def handle_info({:channel_message, message}, state) do
    # Manejar mensajes recibidos del canal
    response = Jason.encode!(message)

    {:push, {:text, response}, state}
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
end
