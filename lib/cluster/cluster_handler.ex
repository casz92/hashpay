defmodule Hashpay.Cluster.Handler do
  @moduledoc """
  Manejador de mensajes para el broker de mensajes del cluster.
  """
  require Logger
  alias Hashpay.PubSub
  alias Hashpay.Cluster
  @behaviour WebSock

  # Canal por defecto
  @default_channel Application.compile_env(:hashpay, :default_channel)

  @impl WebSock
  def init(args) do
    # Obtener parámetros de la conexión
    node = Keyword.get(args, :node)

    # Crear el estado inicial
    state = %{
      id: node.name
    }

    # Unirse al broker
    Cluster.join(node)

    # Suscribirse al canal
    PubSub.subscribe(@default_channel)

    Logger.info("WebSocket connection initialized for node: #{state.id}")
    {:ok, state}
  end

  @impl WebSock
  def handle_in({text, _opts}, %{id: node_id} = state) do
    # Intentar decodificar el mensaje como JSON
    case Jason.decode(text) do
      {:ok, %{"method" => "subscribe", "channel" => channel}} ->
        # Suscribirse al canal
        PubSub.subscribe(channel)
        {:ok, state}

      {:ok, %{"method" => "unsubscribe", "channel" => channel}} ->
        # Cancelar la suscripción al canal
        PubSub.unsubscribe(channel)
        {:ok, state}

      {:ok, %{"method" => "publish", "channel" => channel, "message" => message}} ->
        # Publicar el mensaje en el canal
        new_message = Map.put(message, "from_node", node_id)
        PubSub.broadcast_from(channel, {:channel_message, new_message})
        {:ok, state}

      {:ok, %{"method" => "members"}} ->
        # Enviar la lista de miembros
        members = Cluster.members()
        response = Jason.encode!(%{type: "members", members: members})
        {:push, {:text, response}, state}

      _ ->
        Logger.info("Received message from #{node_id}: #{text}")
        {:ok, state}
    end
  end

  @impl WebSock
  def handle_info({:channel_message, message}, state) do
    # Manejar mensajes recibidos del canal
    response = Jason.encode!(message)

    {:push, {:text, response}, state}
  end

  @impl WebSock
  def terminate(reason, %{id: node_id}) do
    Logger.info(
      "WebSocket connection terminated for node: #{node_id}, reason: #{inspect(reason)}"
    )

    # Salir del broker
    Cluster.leave(node_id)

    :ok
  end
end
