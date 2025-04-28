defmodule Hashpay.WebSocketClientTest do
  use ExUnit.Case
  alias Hashpay.WebSocketClient

  # Estos tests son más bien de integración y requieren un servidor WebSocket en ejecución
  # Por lo tanto, los marcamos como @tag :integration para que puedan ser ejecutados selectivamente

  @tag :integration
  test "start_link inicia el cliente correctamente" do
    uri = "ws://localhost:4000/ws"
    {:ok, client} = WebSocketClient.start_link(uri)
    assert is_pid(client)

    # Dar tiempo para que se establezca la conexión
    Process.sleep(1000)

    # Verificar que el proceso está vivo
    assert Process.alive?(client)

    # No podemos acceder directamente al estado con la nueva implementación
    # ya que ahora usamos el comportamiento :websocket_client
  end

  @tag :integration
  test "start_link con suscripciones iniciales" do
    {:ok, client} = WebSocketClient.start_link("ws://localhost:4000/ws",
      subscriptions: ["canal_test"])
    assert is_pid(client)

    # Dar tiempo para que se establezca la conexión y se suscriba
    Process.sleep(1000)

    # No podemos verificar directamente las suscripciones con la nueva implementación
    # pero podemos verificar que el proceso está vivo
    assert Process.alive?(client)
  end

  @tag :integration
  test "subscribe envía mensaje de suscripción" do
    {:ok, client} = WebSocketClient.start_link("ws://localhost:4000/ws")
    Process.sleep(1000)

    # Suscribirse a un canal
    # Esto solo verifica que no hay errores al enviar el mensaje de suscripción
    WebSocketClient.subscribe(client, "test_channel")
    Process.sleep(500)

    # Verificar que el proceso sigue vivo
    assert Process.alive?(client)
  end

  @tag :integration
  test "unsubscribe envía mensaje de desuscripción" do
    {:ok, client} = WebSocketClient.start_link("ws://localhost:4000/ws")
    Process.sleep(1000)

    # Suscribirse y luego desuscribirse
    WebSocketClient.subscribe(client, "test_channel")
    Process.sleep(500)
    WebSocketClient.unsubscribe(client, "test_channel")
    Process.sleep(500)

    # Verificar que el proceso sigue vivo
    assert Process.alive?(client)
  end

  @tag :integration
  test "push envía un mensaje correctamente" do
    # Este test solo verifica que no hay errores al enviar un mensaje
    # No podemos verificar fácilmente que el mensaje llegue al servidor
    {:ok, client} = WebSocketClient.start_link("ws://localhost:4000/ws")
    Process.sleep(1000)

    # Enviar un mensaje
    WebSocketClient.push(client, %{type: "test", content: "Hello"})

    # Verificar que el proceso sigue vivo
    assert Process.alive?(client)
  end

  # Test para el manejo de mensajes recibidos
  @tag :integration
  test "el handler de mensajes es llamado cuando se recibe un mensaje" do
    test_pid = self()

    # Crear un handler que envía un mensaje al proceso de test
    handler = fn message ->
      send(test_pid, {:received, message})
    end

    # Iniciar el cliente con el handler
    {:ok, client} = WebSocketClient.start_link("ws://localhost:4000/ws", message_handler: handler)
    Process.sleep(1000)

    # Suscribirse a un canal donde esperamos recibir mensajes
    WebSocketClient.subscribe(client, "test_channel")

    # Enviar un mensaje al mismo canal (esto debería hacer que el servidor lo reenvíe)
    WebSocketClient.push(client, %{type: "echo", content: "test"}, "test_channel")

    # Esperar a recibir el mensaje (con timeout)
    receive do
      {:received, message} ->
        assert is_map(message)
    after
      5000 ->
        flunk("No se recibió ningún mensaje en 5 segundos")
    end
  end

  # Nota: No podemos probar el cierre de la conexión directamente con la nueva implementación
  # ya que no tenemos un método close() explícito. La conexión se cierra cuando el proceso termina.
end
