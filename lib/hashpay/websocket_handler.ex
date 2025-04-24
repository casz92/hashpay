defmodule Hashpay.WebSocketHandler do
  @moduledoc """
  Módulo para manejar conexiones WebSocket.
  Permite a los clientes conectarse a canales y comunicarse entre sí.
  """
  require Logger
  alias Hashpay.PubSub

  @behaviour WebSock

  # Canal por defecto
  @default_channel "lobby"

  # Intervalo de heartbeat en milisegundos (30 segundos)
  @heartbeat_interval 60_000

  @impl WebSock
  def init(args) do
    # Obtener parámetros de la conexión
    user_id = Keyword.get(args, :user_id, "anonymous")
    channel = Keyword.get(args, :channel, @default_channel)

    # Crear el estado inicial
    state = %{
      user_id: user_id,
      channel: channel,
      messages: [],
      last_heartbeat: DateTime.utc_now()
    }

    # Suscribirse al canal
    PubSub.subscribe(channel)

    # Notificar a otros usuarios sobre la nueva conexión
    broadcast_user_event(state, "joined")

    # Iniciar el proceso de heartbeat
    schedule_heartbeat()

    Logger.info("WebSocket connection initialized for user: #{user_id} in channel: #{channel}")
    {:ok, state}
  end

  @impl WebSock
  def handle_in({text, _opts}, state) do
    # Intentar decodificar el mensaje como JSON
    case Jason.decode(text) do
      {:ok, %{"type" => "heartbeat_ack", "timestamp" => timestamp}} ->
        # Es un mensaje de confirmación de heartbeat
        Logger.debug("Heartbeat ACK recibido de #{state.user_id}: #{timestamp}")
        {:ok, state}

      _ ->
        # Es un mensaje normal
        Logger.info("Received message from #{state.user_id} in channel #{state.channel}: #{text}")

        # Procesar el mensaje recibido
        message = %{
          id: UUID.uuid4(),
          user_id: state.user_id,
          channel: state.channel,
          content: text,
          timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        # Actualizar el estado con el nuevo mensaje
        updated_state = %{state | messages: [message | state.messages]}

        # Enviar el mensaje a todos los usuarios en el canal
        broadcast_message(state.channel, message)

        # Enviar una confirmación al cliente
        response =
          Jason.encode!(%{
            type: "message_sent",
            message: message
          })

        {:push, {:text, response}, updated_state}
    end
  end

  @impl WebSock
  def handle_info(:heartbeat, state) do
    # Programar el próximo heartbeat
    schedule_heartbeat()

    # Actualizar el estado con el último heartbeat
    updated_state = %{state | last_heartbeat: DateTime.utc_now()}

    # Enviar un ping al cliente (no visible en el chat)
    heartbeat =
      Jason.encode!(%{
        type: "heartbeat",
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    {:push, {:text, heartbeat}, updated_state}
  end

  @impl WebSock
  def handle_info({:channel_message, message}, state) do
    # Manejar mensajes recibidos del canal
    response =
      Jason.encode!(%{
        type: "channel_message",
        message: message
      })

    {:push, {:text, response}, state}
  end

  @impl WebSock
  def handle_info({:user_event, user_id, event, data}, state) do
    # Manejar eventos de usuarios (unirse, salir, etc.)
    response =
      Jason.encode!(%{
        type: "user_event",
        user_id: user_id,
        event: event,
        data: data,
        timestamp: DateTime.utc_now() |> DateTime.to_iso8601()
      })

    {:push, {:text, response}, state}
  end

  @impl WebSock
  def handle_info({:broadcast, message}, state) do
    # Manejar mensajes enviados desde otras partes de la aplicación
    response =
      Jason.encode!(%{
        type: "broadcast",
        message: message
      })

    {:push, {:text, response}, state}
  end

  @impl WebSock
  def handle_info(message, state) do
    Logger.info("Received unexpected message: #{inspect(message)}")
    {:ok, state}
  end

  @impl WebSock
  def terminate(reason, state) do
    # Notificar a otros usuarios que este usuario ha salido
    broadcast_user_event(state, "left")

    # Cancelar la suscripción al canal
    PubSub.unsubscribe(state.channel)

    Logger.info(
      "WebSocket connection terminated for user: #{state.user_id}, channel: #{state.channel}, reason: #{inspect(reason)}"
    )

    :ok
  end

  # Programar el próximo heartbeat
  defp schedule_heartbeat do
    Process.send_after(self(), :heartbeat, @heartbeat_interval)
  end

  # Funciones auxiliares para broadcast

  defp broadcast_message(channel, message) do
    PubSub.broadcast(channel, {:channel_message, message})
  end

  defp broadcast_user_event(state, event, data \\ %{}) do
    PubSub.broadcast(
      state.channel,
      {:user_event, state.user_id, event, data}
    )
  end
end
