defmodule Udp do
  @moduledoc """
  Cliente y servidor UDP para comunicación con servidores remotos.

  Este módulo proporciona:
  1. Funciones para comunicación UDP directa (call y cast)
  2. Funcionalidad de servidor UDP mediante GenServer
  3. Funciones de codificación/decodificación CBOR
  """
  use GenServer
  require Logger

  @default_timeout 5000

  @type server :: pid() | atom() | {:global, term()} | {:via, module(), term()}
  @type ip_address :: :inet.ip_address() | String.t()
  @type udp_port :: :inet.port_number()
  @type request :: term()
  @type response :: term()
  @type options :: [option()]
  @type option :: {:timeout, timeout()}

  @doc """
  Realiza una llamada síncrona a un servidor UDP.

  Envía una solicitud y espera una respuesta. La solicitud se codifica con CBOR
  antes de enviarse, y la respuesta se decodifica con CBOR al recibirla.

  ## Parámetros

  * `destination_ip` - Dirección IP del servidor destino
  * `destination_port` - Puerto del servidor destino
  * `request` - Datos a enviar
  * `options` - Opciones adicionales

  ## Opciones

  * `:timeout` - Tiempo máximo de espera para la respuesta (por defecto: 5000 ms)
  * `:source_port` - Puerto local a utilizar (opcional, se asignará uno automáticamente si no se especifica)
  * `:source_ip` - Dirección IP local a la que enlazar el socket (opcional)

  ## Ejemplos

      iex> Hashpay.UdpCLI.call("10.0.0.1", 8000, %{action: "get_status"})
      {:ok, %{status: "ok"}}

      iex> Hashpay.UdpCLI.call("10.0.0.1", 8000, %{action: "get_data"}, timeout: 10000)
      {:ok, %{data: [1, 2, 3]}}
  """
  @spec call(ip_address(), udp_port(), request(), options()) ::
          {:ok, response()} | {:error, term()}
  def call(destination_ip, destination_port, request, options \\ []) do
    timeout = Keyword.get(options, :timeout, @default_timeout)
    source_port = Keyword.get(options, :source_port, 0)
    source_ip = Keyword.get(options, :source_ip)

    # Configurar opciones del socket
    udp_options = [
      :binary,
      {:active, false},
      {:reuseaddr, true}
    ]

    # Agregar IP de origen si se especificó
    udp_options = if source_ip, do: [{:ip, parse_ip(source_ip)} | udp_options], else: udp_options

    # Abrir un socket UDP
    case :gen_udp.open(source_port, udp_options) do
      {:ok, socket} ->
        try do
          # Codificar el mensaje con CBOR
          encoded_message = encode(request)

          # Enviar el mensaje
          dest_ip = parse_ip(destination_ip)

          case :gen_udp.send(socket, dest_ip, destination_port, encoded_message) do
            :ok ->
              # Esperar la respuesta con timeout
              receive_response(socket, timeout)

            {:error, reason} ->
              {:error, reason}
          end
        after
          # Cerrar el socket
          :gen_udp.close(socket)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Realiza una llamada asíncrona a un servidor UDP.

  Envía una solicitud sin esperar respuesta. La solicitud se codifica con CBOR
  antes de enviarse.

  ## Parámetros

  * `destination_ip` - Dirección IP del servidor destino
  * `destination_port` - Puerto del servidor destino
  * `request` - Datos a enviar
  * `options` - Opciones adicionales

  ## Opciones

  * `:source_port` - Puerto local a utilizar (opcional, se asignará uno automáticamente si no se especifica)
  * `:source_ip` - Dirección IP local a la que enlazar el socket (opcional)

  ## Ejemplos

      iex> Hashpay.UdpCLI.cast("10.0.0.1", 8000, %{action: "notify", data: "event"})
      :ok
  """
  @spec cast(ip_address(), udp_port(), request(), options()) :: :ok | {:error, term()}
  def cast(destination_ip, destination_port, request, options \\ []) do
    source_port = Keyword.get(options, :source_port, 0)
    source_ip = Keyword.get(options, :source_ip)

    # Configurar opciones del socket
    udp_options = [
      :binary,
      {:active, false},
      {:reuseaddr, true}
    ]

    # Agregar IP de origen si se especificó
    udp_options = if source_ip, do: [{:ip, parse_ip(source_ip)} | udp_options], else: udp_options

    # Abrir un socket UDP
    case :gen_udp.open(source_port, udp_options) do
      {:ok, socket} ->
        try do
          # Preparar el mensaje
          message = %{
            type: "notification",
            payload: request
          }

          # Codificar el mensaje con CBOR
          encoded_message = encode(message)

          # Enviar el mensaje
          dest_ip = parse_ip(destination_ip)

          case :gen_udp.send(socket, dest_ip, destination_port, encoded_message) do
            :ok -> :ok
            {:error, reason} -> {:error, reason}
          end
        after
          # Cerrar el socket
          :gen_udp.close(socket)
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Funciones privadas

  defp receive_response(socket, timeout) do
    case :gen_udp.recv(socket, 0, timeout) do
      {:ok, {_sender_ip, _sender_port, data}} ->
        # Intentar decodificar el mensaje con CBOR
        case decode(data) do
          {:ok, message, _rest} ->
            {:ok, message}

          {:error, reason} ->
            # Error al decodificar
            Logger.error("Failed to decode CBOR message: #{inspect(reason)}")
            {:error, :decode_error}
        end

      {:error, :timeout} ->
        # Timeout al esperar respuesta
        {:error, :timeout}

      {:error, reason} ->
        # Otro error
        {:error, reason}
    end
  end

  defp parse_ip(ip) when is_tuple(ip), do: ip

  defp parse_ip(ip) when is_binary(ip) do
    {:ok, address} = :inet.parse_address(String.to_charlist(ip))
    address
  end

  # Funciones de codificación/decodificación

  @doc """
  Codifica un término a formato CBOR.

  ## Parámetros

  * `term` - Término a codificar

  ## Ejemplos

      iex> Hashpay.UdpCLI.encode(%{key: "value"})
      <<...>> # Datos binarios CBOR
  """
  @spec encode(term()) :: binary()
  def encode(term) do
    CBOR.encode(term)
  end

  @doc """
  Decodifica datos CBOR a un término Elixir.

  ## Parámetros

  * `data` - Datos CBOR a decodificar

  ## Ejemplos

      iex> data = Hashpay.UdpCLI.encode(%{key: "value"})
      iex> Hashpay.UdpCLI.decode(data)
      {:ok, %{key: "value"}}
  """
  @spec decode(binary()) :: {:ok, term(), term()} | {:error, term()}
  def decode(data) do
    CBOR.decode(data)
  end

  # Funciones de servidor UDP (GenServer)

  @doc """
  Inicia un servidor UDP.

  ## Opciones

  * `:ip` - Dirección IP a la que enlazar el socket (opcional)
  * `:port` - Puerto en el que escuchar (opcional, por defecto: 0)
  * `:active` - Modo de recepción de mensajes (por defecto: true)
  * `:handler` - Función para manejar mensajes recibidos (opcional)

  ## Ejemplos

      iex> {:ok, server} = Hashpay.UdpCLI.start_link(port: 8000)
      iex> {:ok, server} = Hashpay.UdpCLI.start_link(ip: "127.0.0.1", port: 8000, handler: &MyModule.handle_message/3)
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc """
  Inicia un servidor UDP con nombre registrado.

  ## Parámetros

  * `name` - Nombre para registrar el proceso
  * `opts` - Opciones de configuración

  ## Ejemplos

      iex> {:ok, server} = Hashpay.UdpCLI.start_link(UdpServer, port: 8000)
  """
  @spec start_link(atom(), keyword()) :: GenServer.on_start()
  def start_link(name, opts) when is_atom(name) do
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Detiene un servidor UDP.

  ## Parámetros

  * `server` - PID o nombre del servidor

  ## Ejemplos

      iex> Hashpay.UdpCLI.stop(server)
      :ok
  """
  @spec stop(server()) :: :ok
  def stop(server) do
    GenServer.stop(server)
  end

  @doc """
  Obtiene información sobre el servidor UDP.

  ## Parámetros

  * `server` - PID o nombre del servidor

  ## Ejemplos

      iex> Hashpay.UdpCLI.info(server)
      %{ip: {127, 0, 0, 1}, port: 8000, active: true}
  """
  @spec info(server()) :: map()
  def info(server) do
    GenServer.call(server, :info)
  end

  # Callbacks de GenServer

  @impl true
  def init(opts) do
    ip = Keyword.get(opts, :ip)
    port = Keyword.get(opts, :port, 0)
    active = Keyword.get(opts, :active, true)
    handler = Keyword.get(opts, :handler)

    udp_options = [
      :binary,
      {:active, active},
      {:reuseaddr, true}
    ]

    udp_options = if ip, do: [{:ip, parse_ip(ip)} | udp_options], else: udp_options

    case :gen_udp.open(port, udp_options) do
      {:ok, socket} ->
        {:ok, {local_ip, local_port}} = :inet.sockname(socket)
        Logger.debug("UDP server started on #{format_ip(local_ip)}:#{local_port}")

        state = %{
          socket: socket,
          ip: local_ip,
          port: local_port,
          active: active,
          handler: handler
        }

        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to open UDP socket: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:info, _from, state) do
    info = %{
      ip: state.ip,
      port: state.port,
      active: state.active
    }

    {:reply, info, state}
  end

  @impl true
  def handle_info({:udp, _socket, sender_ip, sender_port, data}, %{socket: socket} = state) do
    # Intentar decodificar el mensaje con CBOR
    case decode(data) do
      {:ok, message, _rest} ->
        # Logger.info("Received message: #{inspect(message)}")

        case handle_udp_message(message, sender_ip, sender_port, state) do
          {:reply, reply} ->
            encoded_reply = encode(reply)
            :gen_udp.send(socket, sender_ip, sender_port, encoded_reply)
            {:noreply, state}

          resp ->
            Logger.info("Message not response handled #{inspect(resp)}")
            {:noreply, state}
        end

      {:error, reason} ->
        Logger.error("Failed to decode CBOR message: #{inspect(reason)}")
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warning("Unexpected message: #{inspect(msg)}")
    {:noreply, state}
  end

  @impl true
  def terminate(_reason, %{socket: socket}) do
    :gen_udp.close(socket)
    :ok
  end

  # Funciones privadas adicionales

  defp handle_udp_message(message, sender_ip, sender_port, state) do
    # Si hay un handler definido, llamarlo
    if state.handler do
      try do
        :erlang.apply(state.handler, :handle_in, [message, sender_ip, sender_port])
      rescue
        e ->
          Logger.error("Error in message handler: #{inspect(e)}")
      end
    end
  end

  defp format_ip({a, b, c, d}), do: "#{a}.#{b}.#{c}.#{d}"

  defp format_ip({a, b, c, d, e, f, g, h}) do
    "#{Integer.to_string(a, 16)}:#{Integer.to_string(b, 16)}:#{Integer.to_string(c, 16)}:#{Integer.to_string(d, 16)}:#{Integer.to_string(e, 16)}:#{Integer.to_string(f, 16)}:#{Integer.to_string(g, 16)}:#{Integer.to_string(h, 16)}"
  end
end
