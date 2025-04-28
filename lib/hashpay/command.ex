defmodule Hashpay.Command do
  @moduledoc """
  Estructura y funciones para los comandos de la blockchain de Hashpay.

  Un comando contiene:
  - hash: Hash del comando
  - fun: Nombre de la función a ejecutar
  - args: Argumentos de la función
  - from: Identificador del emisor del comando
  - timestamp: Marca de tiempo de creación del comando
  - signature: Firma digital del emisor
  """
  @type t :: %__MODULE__{
          hash: binary() | nil,
          fun: String.t() | pos_integer(),
          args: list() | nil,
          from: String.t() | nil,
          size: non_neg_integer(),
          signature: binary() | nil,
          timestamp: non_neg_integer()
        }

  defstruct [
    :hash,
    :fun,
    :args,
    :from,
    :size,
    :signature,
    :timestamp
  ]

  alias Hashpay.DB
  alias Hashpay.Merchant
  alias Hashpay.Account
  alias Hashpay.Function.Context
  alias Hashpay.Functions

  def new(attrs, size) do
    %__MODULE__{
      fun: attrs["fun"],
      args: attrs["args"],
      from: attrs["from"],
      size: size,
      signature: attrs["signature"],
      timestamp: attrs["timestamp"]
    }
    |> put_hash()
  end

  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{} = command) do
    Jason.encode!(command)
  end

  @spec decode(String.t()) :: t()
  def decode(json) do
    Jason.decode!(json)
    |> new(byte_size(json))
  end

  def hash(command) do
    :crypto.hash(:sha256, encode(command))
  end

  defp put_hash(command) do
    %{command | hash: hash(command)}
  end

  # def verify_hash(command, hash) do
  #   hash(command) == hash
  # end

  def sign(command, private_key) do
    {:ok, signature} = Cafezinho.Impl.sign(hash(command), private_key)
    %{command | signature: signature}
  end

  def verify_signature(command, public_key) do
    Cafezinho.Impl.verify(command.signature, command.hash, public_key)
  end

  @spec fetch_sender(pid(), String.t()) ::
          {:ok, Account.t() | Merchant.t()} | {:error, :not_found} | {:error, String.t()}
  def fetch_sender(conn, id) do
    cond do
      Account.match?(id) ->
        Account.fetch(conn, id)

      Merchant.match?(id) ->
        Merchant.fetch(conn, id)

      true ->
        {:error, "Invalid sender"}
    end
  end

  @spec handle(t()) :: {:ok, any()} | {:error, String.t()}
  def handle(command) do
    case Functions.get(command.fun) do
      {:ok, function} ->
        conn = DB.get_conn()

        case fetch_sender(conn, command.from) do
          {:ok, sender} ->
            cond do
              function.auth_type == 1 && !verify_signature(command, sender.public_key) ->
                {:error, "Invalid signature"}

              true ->
                context = Context.new(command, function, sender)

                case apply(function.mod, function.fun, [context | command.args]) do
                  {:error, reason} -> {:error, reason}
                  result -> result
                end
            end

          {:error, :not_found} ->
            {:error, "Sender not found"}

          error_sender ->
            error_sender
        end

      _ ->
        {:error, "Function not found"}
    end
  end
end
