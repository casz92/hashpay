defmodule Hashpay.WebSocketClientExample do
  @moduledoc """
  Ejemplo de uso del cliente WebSocket.
  Demuestra cómo usar la implementación de websocket_client.
  """
  require Logger

  @doc """
  Función para manejar mensajes recibidos del servidor.
  """
  def handle_message(message) do
    Logger.info("Mensaje recibido del servidor: #{inspect(message)}")
    # Aquí puedes implementar la lógica específica para manejar diferentes tipos de mensajes
  end

  @doc """
  Inicia un cliente WebSocket y realiza algunas operaciones de ejemplo.
  """
  def run(uri \\ "ws://localhost:4000/ws") do
    # Iniciar el cliente con suscripciones iniciales
    {:ok, client} = Hashpay.WebSocketClient.start_link(uri,
      message_handler: &handle_message/1,
      subscriptions: ["canal_principal"])

    # Esperar a que se establezca la conexión
    Process.sleep(1000)

    # Suscribirse a un canal adicional
    Hashpay.WebSocketClient.subscribe(client, "noticias")

    # Enviar un mensaje al canal por defecto
    Hashpay.WebSocketClient.push(client, %{
      type: "message",
      content: "Hola desde el cliente WebSocket"
    })

    # Enviar un mensaje a un canal específico
    Hashpay.WebSocketClient.push(client, %{
      type: "data",
      value: Enum.random(1..100)
    }, "noticias")

    # Esperar un tiempo para ver los mensajes
    Process.sleep(5000)

    # Desuscribirse del canal
    Hashpay.WebSocketClient.unsubscribe(client, "noticias")

    # Mantener el proceso vivo para observar la recepción, reconexión y heartbeat
    Logger.info("Cliente WebSocket iniciado y funcionando. Presiona Ctrl+C para salir.")

    # Devolver el cliente para que pueda ser usado en otras operaciones
    client
  end

  @doc """
  Función principal para ejecutar el ejemplo desde la línea de comandos.
  """
  def main(args \\ []) do
    uri = List.first(args) || "ws://localhost:4000/ws"
    run(uri)

    # Mantener el proceso principal vivo
    Process.sleep(:infinity)
  end
end
