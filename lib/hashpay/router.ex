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
    # parsers: [:json, :urlencoded, :multipart],
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]
    # json_decoder: Jason
  )

  plug(:dispatch)

  # Ruta de ejemplo que responde "it works!"
  get "/" do
    send_resp(conn, 200, "it works!")
  end

  alias Hashpay.Command

  post "/v1/call" do
    {:ok, body, _conn} = read_body(conn)
    command = Command.decode(body)

    case Command.handle(command) do
      {:error, reason} ->
        Logger.error("Error handling command: #{reason}")
        send_resp(conn, 400, reason)

      _ ->
        send_resp(conn, 200, "OK")
    end
  end

  # Ruta de estado para verificar que el servidor está funcionando
  get "/v1/status" do
    response = %{
      status: "ok",
      # s3: Application.get_env(:hashpay, :s3_endpoint),
      timestamp: DateTime.utc_now() |> DateTime.to_iso8601(),
      version: Application.spec(:hashpay, :vsn) |> to_string()
    }

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(response))
  end

  # Ruta para WebSockets
  get "/v1/public/ws" do
    conn = fetch_query_params(conn)
    sender = Map.get(conn.params, "sender")
    channel = Map.get(conn.params, "channel")
    challenge = Map.get(conn.params, "challenge")
    signature = Map.get(conn.params, "signature") |> Base.decode16!()
    db_conn = Hashpay.DB.get_conn()

    # Verificar la firma del remitente
    response =
      case Command.fetch_sender(db_conn, sender) do
        {:ok, sender} ->
          case Cafezinho.Impl.verify(signature, challenge, sender.public_key) do
            true -> :ok
            false -> {:error, "Invalid signature"}
          end

        {:error, :not_found} ->
          {:error, "Sender not found"}

        error ->
          error
      end

    case response do
      :ok ->
        conn
        |> WebSockAdapter.upgrade(
          Hashpay.Public.Handler,
          [sender: sender, channel: channel],
          timeout: 120_000
        )
        |> halt()

      {:error, reason} ->
        Logger.debug("Invalid signature for sender: #{sender}")

        conn
        |> send_resp(401, reason)
        |> halt()
    end
  end

  if Application.compile_env(:hashpay, :enable_cluster, true) do
    get "/v1/cluster/ws" do
      conn = fetch_query_params(conn)
      name = Map.get(conn.params, "name")
      challenge = Map.get(conn.params, "challenge") |> DateTime.from_iso8601()
      signature = Map.get(conn.params, "signature") |> Base.decode16!()

      with false <- is_nil(name),
           {:on, node} <- Hashpay.Cluster.get_and_authenticate(name, challenge, signature) do
        Logger.info("WebSocket connection request from node: #{node.name}")

        conn
        |> WebSockAdapter.upgrade(
          Hashpay.Cluster.Handler,
          [node: node],
          timeout: 150_000
        )
        |> halt()
      else
        _error ->
          conn
          |> send_resp(401, "Unauthorized")
          |> halt()
      end
    end
  end

  if Mix.env() == :dev do
    # Ruta para el depurador de Plug
    # use Plug.Debugger

    get "/websocket-example" do
      conn
      |> put_resp_content_type("text/html")
      |> send_file(200, "priv/html/websocket_example.html")
    end

    get "/ws" do
      conn = fetch_query_params(conn)
      user_id = Map.get(conn.params, "user_id", "anonymous")
      channel = Map.get(conn.params, "channel", "lobby")

      Logger.info("WebSocket connection request from user: #{user_id} to channel: #{channel}")

      conn
      |> WebSockAdapter.upgrade(
        Hashpay.WebSocketHandlerExample,
        [user_id: user_id, channel: channel],
        timeout: 120_000
      )
      |> halt()
    end
  end

  # Ruta para la página de ejemplo de WebSocket

  # Captura todas las demás rutas
  match _ do
    send_resp(conn, 404, "Not found")
  end
end
