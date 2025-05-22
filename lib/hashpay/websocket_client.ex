defmodule Hashpay.WebSocketClient do
  @moduledoc """
  Cliente WebSocket para Hashpay.
  Proporciona funcionalidades de PubSub (publicación/suscripción) a través de WebSockets.
  Incluye reconexión automática y heartbeat.

  Implementado usando la librería websocket_client.
  """
  require Logger
  alias Hashpay.SystemInfo
  @behaviour :websocket_client

  # 30 segundos
  @heartbeat_interval 30_000
  # 3 segundos
  @reconnect_delay 3_000
  @default_channel "lobby"

  # API Pública

  @doc """
  Inicia un cliente WebSocket.

  ## Parámetros

  - `uri`: URI del servidor WebSocket (ej: "ws://localhost:4000/ws")
  - `opts`: Opciones adicionales
    - `:message_handler`: Función para manejar mensajes recibidos
    - `:subscriptions`: Lista de canales a los que suscribirse inicialmente
    - `:heartbeat_interval`: Intervalo de heartbeat en milisegundos (por defecto: 30000)

  ## Ejemplos

      {:ok, client} = Hashpay.WebSocketClient.start_link("ws://localhost:4000/ws")
      {:ok, client} = Hashpay.WebSocketClient.start_link("ws://localhost:4000/ws",
                        message_handler: &MyModule.handle_message/1,
                        subscriptions: ["canal1", "canal2"])
  """
  def start_link(uri, opts \\ []) do
    state = %{
      uri: uri,
      message_handler: Keyword.get(opts, :message_handler),
      subscriptions: MapSet.new(Keyword.get(opts, :subscriptions, [])),
      heartbeat_interval: Keyword.get(opts, :heartbeat_interval, @heartbeat_interval),
      heartbeat_timer: nil,
      counter: 0
    }

    :websocket_client.start_link(uri, __MODULE__, state)
  end

  @doc """
  Publica un mensaje en el servidor WebSocket.

  ## Parámetros

  - `client`: PID del cliente WebSocket
  - `message`: Mensaje a enviar (será codificado como JSON)
  - `channel`: Canal al que enviar el mensaje (opcional)

  ## Ejemplos

      Hashpay.WebSocketClient.push(client, %{type: "message", content: "Hola"})
      Hashpay.WebSocketClient.push(client, %{content: "Hola"}, "canal_noticias")
  """
  def push(client, message, channel \\ @default_channel) do
    payload =
      if channel do
        %{method: "publish", channel: channel, message: message}
      else
        message
      end

    :websocket_client.cast(client, {:text, Jason.encode!(payload)})
  end

  @doc """
  Suscribe el cliente a un canal.

  ## Parámetros

  - `client`: PID del cliente WebSocket
  - `channel`: Canal al que suscribirse

  ## Ejemplos

      Hashpay.WebSocketClient.subscribe(client, "canal_noticias")
  """
  def subscribe(client, channel) do
    message = %{method: "subscribe", channel: channel}
    :websocket_client.cast(client, {:text, Jason.encode!(message)})
  end

  @doc """
  Cancela la suscripción del cliente a un canal.

  ## Parámetros

  - `client`: PID del cliente WebSocket
  - `channel`: Canal del que desuscribirse

  ## Ejemplos

      Hashpay.WebSocketClient.unsubscribe(client, "canal_noticias")
  """
  def unsubscribe(client, channel) do
    message = %{method: "unsubscribe", channel: channel}
    :websocket_client.cast(client, {:text, Jason.encode!(message)})
  end

  # Callbacks de websocket_client

  @impl :websocket_client
  def init(state) do
    Logger.info("Inicializando cliente WebSocket para #{state.uri}")
    # Retornar {once, state} para recibir un mensaje a la vez
    # o {ok, state} para recibir mensajes continuamente
    {:once, state}
  end

  @impl :websocket_client
  def onconnect(_WSReq, state) do
    Logger.info("Conectado exitosamente a #{state.uri}")

    # Programar el heartbeat
    timer_ref = Process.send_after(self(), :heartbeat, state.heartbeat_interval)

    # Suscribirse a los canales iniciales
    Enum.each(state.subscriptions, fn channel ->
      message = %{method: "subscribe", channel: channel}
      :websocket_client.cast(self(), {:text, Jason.encode!(message)})
      Logger.info("Suscrito al canal: #{channel}")
    end)

    # Enviar un mensaje de conexión
    :websocket_client.cast(self(), {:text, Jason.encode!(%{type: "connect"})})

    {:ok, %{state | heartbeat_timer: timer_ref}}
  end

  @impl :websocket_client
  def ondisconnect({:remote, _closed}, state) do
    Logger.info("Conexión cerrada por el servidor. Intentando reconectar...")

    # Cancelar el timer de heartbeat si existe
    if state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    # Reconectar automáticamente
    {:reconnect, %{state | heartbeat_timer: nil}}
  end

  @impl :websocket_client
  def ondisconnect({:error, reason}, state) do
    Logger.error(
      "Error en la conexión: #{inspect(reason)}. Intentando reconectar en #{@reconnect_delay}ms..."
    )

    # Cancelar el timer de heartbeat si existe
    if state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    # Esperar antes de reconectar
    Process.sleep(@reconnect_delay)

    # Reconectar
    {:reconnect, %{state | heartbeat_timer: nil}}
  end

  @impl :websocket_client
  def websocket_handle({:text, msg}, _ConnState, state) do
    Logger.debug("Mensaje recibido: #{msg}")

    case Jason.decode(msg) do
      {:ok, decoded_message} ->
        handle_received_message(decoded_message, &Jason.encode!/1, state)

      {:error, reason} ->
        Logger.error("Error al decodificar mensaje JSON: #{inspect(reason)}")
        {:ok, state}
    end
  end

  @impl :websocket_client
  def websocket_handle({:binary, msg}, _ConnState, state) do
    Logger.debug("Mensaje binario recibido: #{inspect(msg)}")

    case CBOR.decode(msg) do
      {:ok, decoded_message, _} ->
        handle_received_message(decoded_message, &CBOR.encode/1, state)

      {:error, reason} ->
        Logger.error("Error al decodificar mensaje CBOR: #{inspect(reason)}")
        {:ok, state}
    end

    {:ok, state}
  end

  @impl :websocket_client
  def websocket_handle({:ping, data}, _ConnState, state) do
    # Responder automáticamente a los pings con pongs
    {:reply, {:pong, data}, state}
  end

  @impl :websocket_client
  def websocket_handle({:pong, _data}, _ConnState, state) do
    # Recibimos un pong, no necesitamos hacer nada especial
    {:ok, state}
  end

  @impl :websocket_client
  def websocket_handle(frame, _ConnState, state) do
    Logger.warning("Frame no manejado: #{inspect(frame)}")
    {:ok, state}
  end

  @impl :websocket_client
  def websocket_info(:heartbeat, _ConnState, state) do
    # Enviar heartbeat
    heartbeat = %{
      type: "heartbeat",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      counter: state.counter
    }

    # Programar el próximo heartbeat
    timer_ref = Process.send_after(self(), :heartbeat, state.heartbeat_interval)

    # Incrementar el contador para el próximo heartbeat
    updated_state = %{state | heartbeat_timer: timer_ref, counter: state.counter + 1}

    {:reply, {:text, Jason.encode!(heartbeat)}, updated_state}
  end

  @impl :websocket_client
  def websocket_info({:subscribe, channel}, _ConnState, state) do
    # Mensaje interno para suscribirse a un canal
    message = %{method: "subscribe", channel: channel}
    updated_state = %{state | subscriptions: MapSet.put(state.subscriptions, channel)}
    {:reply, {:text, Jason.encode!(message)}, updated_state}
  end

  @impl :websocket_client
  def websocket_info({:unsubscribe, channel}, _ConnState, state) do
    # Mensaje interno para desuscribirse de un canal
    message = %{method: "unsubscribe", channel: channel}
    updated_state = %{state | subscriptions: MapSet.delete(state.subscriptions, channel)}
    {:reply, {:text, Jason.encode!(message)}, updated_state}
  end

  @impl :websocket_client
  def websocket_info({:push, message, channel}, _ConnState, state) do
    # Mensaje interno para enviar un mensaje
    payload =
      if channel do
        %{method: "publish", channel: channel, message: message}
      else
        message
      end

    {:reply, {:text, Jason.encode!(payload)}, state}
  end

  @impl :websocket_client
  def websocket_info(message, _ConnState, state) do
    Logger.warning("Mensaje inesperado recibido: #{inspect(message)}")
    {:ok, state}
  end

  @impl :websocket_client
  def websocket_terminate(reason, _ConnState, state) do
    Logger.info("Conexión WebSocket terminada: #{inspect(reason)}")

    # Cancelar el timer de heartbeat si existe
    if state.heartbeat_timer do
      Process.cancel_timer(state.heartbeat_timer)
    end

    :ok
  end

  # Funciones privadas

  defp handle_received_message(message, encoder, state) do
    # Procesar el mensaje según su tipo
    case message do
      %{"id" => id, "method" => "heartbeat"} ->
        # Responder al heartbeat del servidor
        response = %{id: id, state: "ok"}
        {:reply, {:text, encoder.(response)}, state}

      %{"id" => id, "method" => "getInfo"} ->
        response = SystemInfo.get_info() |> Map.put(:id, id)
        {:reply, {:text, encoder.(response)}, state}

      %{"id" => id, "method" => "getInfoSystem"} ->
        response = SystemInfo.info_callback() |> Map.put(:id, id)
        {:reply, {:text, encoder.(response)}, state}

      %{"id" => id, "method" => "getInfoRoundchain"} ->
        response = SystemInfo.roundchain_callback() |> Map.put(:id, id)
        {:reply, {:text, encoder.(response)}, state}

      %{"id" => id, "method" => _method} ->
        # Pasar el mensaje al handler si existe
        response =
          if state.message_handler do
            try do
              case state.message_handler.(message) do
                {:error, reason} ->
                  %{id: id, state: "error", data: reason}

                _ok ->
                  %{id: id, state: "ok"}
              end
            rescue
              e ->
                reason = Exception.message(e)
                Logger.error("Error en el handler de mensajes: #{reason}")
                %{id: id, state: "error", data: reason}
            end
          else
            %{id: id, state: "error", data: "No handler"}
          end

        {:reply, {:text, encoder.(response)}, state}

      _ ->
        {:ok, state}
    end
  end
end
