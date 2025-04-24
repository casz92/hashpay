defmodule Hashpay.Router do
  @moduledoc """
  Router para la aplicación Hashpay.
  Define las rutas HTTP y sus manejadores.
  """
  use Plug.Router
  import Plug.Conn
  require Logger

  # Plugins
  plug(Plug.Logger)
  plug(:match)

  plug(Plug.Parsers,
    parsers: [:json, :urlencoded, :multipart],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(:dispatch)

  # Ruta de ejemplo que responde "it works!"
  get "/" do
    send_resp(conn, 200, "it works!")
  end

  # Ruta de estado para verificar que el servidor está funcionando
  get "/status" do
    response = %{
      status: "ok",
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:hashpay, :vsn)
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  # Ruta para WebSockets
  get "/ws" do
    conn = fetch_query_params(conn)
    user_id = Map.get(conn.params, "user_id", "anonymous")
    channel = Map.get(conn.params, "channel", "lobby")

    Logger.info("WebSocket connection request from user: #{user_id} to channel: #{channel}")

    conn
    |> WebSockAdapter.upgrade(
      Hashpay.WebSocketHandler,
      [user_id: user_id, channel: channel],
      timeout: 120_000
    )
    |> halt()
  end

  if Mix.env() == :dev do
    # Ruta para el depurador de Plug
    # use Plug.Debugger

    get "/websocket-example" do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, "priv/html/websocket_example.html")
    end
  end

  # Ruta para la página de ejemplo de WebSocket

  # Captura todas las demás rutas
  match _ do
    send_resp(conn, 404, "Not found")
  end
end
