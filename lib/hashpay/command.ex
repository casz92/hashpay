defmodule Hashpay.Command do
  @moduledoc """
  Estructura y funciones para los comandos de la blockchain de Hashpay.

  Un comando contiene:
  - hash: Hash del comando
  - fun: Nombre de la función a ejecutar
  - args: Argumentos de la función
  - from: Identificador del emisor del comando
  - time: Marca de tiempo de creación del comando
  - sign: Firma digital del emisor
  """
  @type t :: %__MODULE__{
          hash: binary() | nil,
          fun: String.t() | pos_integer(),
          args: list() | nil,
          from: String.t() | nil,
          size: non_neg_integer(),
          sign: binary() | nil,
          time: non_neg_integer()
        }

  defstruct [
    :hash,
    :fun,
    :args,
    :from,
    :size,
    :sign,
    :time
  ]

  @threads Application.compile_env(:hashpay, :threads)
  @channel Application.compile_env(:hashpay, :channel)
  @default_channel Application.compile_env(:hashpay, :default_channel)

  alias Hashpay.Validator
  alias Hashpay.Merchant
  alias Hashpay.Account
  alias Hashpay.Function.Context
  alias Hashpay.Functions
  alias Hashpay.TxIndex
  import Hashpay, only: [hash: 1]

  def new(attrs, size, :text) do
    %__MODULE__{
      fun: attrs["fun"],
      args: attrs["args"],
      from: attrs["from"],
      size: size,
      sign: Base.decode64!(attrs["sign"]),
      time: attrs["time"]
    }
    |> compute_hash()
  end

  def new(attrs, size, :binary) do
    %__MODULE__{
      fun: attrs["fun"],
      args: attrs["args"],
      from: attrs["from"],
      size: size,
      sign: attrs["sign"],
      time: attrs["time"]
    }
    |> compute_hash()
  end

  @spec encode(t()) :: String.t()
  def encode(%__MODULE__{} = command) do
    Jason.encode!(command)
  end

  @spec decode(String.t()) :: t()
  def decode(json) do
    Jason.decode!(json)
  end

  defmodule Encoder do
    @join ""

    def to_binary(value) when is_map(value) do
      value
      |> Enum.map(fn {k, v} -> IO.iodata_to_binary([k, ":", to_binary(v)]) end)
      |> Enum.join(@join)
    end

    def to_binary(value) when is_list(value) do
      value
      |> Enum.map(&to_binary/1)
      |> Enum.join(@join)
    end

    def to_binary(value), do: to_string(value)
  end

  defp compute_hash(command = %{time: time, fun: fun, args: args, from: from, sign: signature}) do
    targs = Encoder.to_binary(args)

    iodata =
      [
        fun,
        targs,
        from,
        time
      ]
      |> Enum.join("|")

    <<fhash::binary-24, _rest::binary>> = hash(iodata)
    hash = [<<time::64>>, fhash] |> IO.iodata_to_binary()
    %{command | hash: hash, size: byte_size(iodata) + byte_size(signature)}
  end

  def sign(command, private_key) do
    {:ok, signature} = Cafezinho.Impl.sign(hash(command), private_key)
    %{command | sign: signature}
  end

  def verify_signature(command, public_key) do
    Cafezinho.Impl.verify(command.sign, command.hash, public_key)
  end

  # @spec fetch_sender(ThunderRAM.t(), String.t()) ::
  #         {:ok, Hashpay.object_type(), term()} | {:error, :not_found} | {:error, String.t()}
  def fetch_sender(_tr, id, 0) do
    <<prefix::binary-3, _rest::binary>> = id

    case prefix do
      "ac_" ->
        {:ok, :account}

      "mc_" ->
        {:ok, :merchant}

      "cu_" ->
        {:ok, :currency}

      <<"v_", _::binary>> ->
        {:ok, :validator}

      _ ->
        {:error, "Invalid sender"}
    end
  end

  def fetch_sender(tr, id, 1) do
    <<prefix::binary-3, _rest::binary>> = id

    case prefix do
      "ac_" ->
        {:ok, Account.get(tr, id), :account}

      "mc_" ->
        {:ok, Merchant.get(tr, id), :merchant}

      "cu_" ->
        {:ok, Merchant.get(tr, id), :currency}

      <<"v_", _::binary>> ->
        {:ok, Validator.get(tr, id), :validator}

      # <<"gov_", _::binary>> ->
      #   {:ok, GovProposal.get(tr, id), :govproposal}

      _ ->
        {:error, "Invalid sender"}
    end
  end

  @spec thread(Hashpay.Function.t(), t()) :: non_neg_integer()
  def thread(%{thread: :roundrobin}, _cmd) do
    ref = :persistent_term.get(:thread_counter, nil)
    number = :counters.add(ref, 0, 1)

    if number > @threads do
      :counters.put(ref, 0, 0)
    end

    number
  end

  def thread(fun, cmd) do
    result =
      case fun.thread do
        :sender ->
          :erlang.phash2(cmd.from.id)

        :type_and_args ->
          :erlang.phash2(cmd.args) + fun.id

        :type_and_sender ->
          :erlang.phash2(cmd.from.id) + fun.id

        :args ->
          :erlang.phash2(cmd.args)

        :type ->
          fun.id

        :hash ->
          :erlang.phash2(cmd.hash)
      end

    rem(result, @threads)
  end

  @spec handle(t(), ThunderRAM.t()) :: {:ok, any()} | {:error, String.t()}
  def handle(command, tr) do
    case Functions.fetch(command.fun) do
      {:ok, function} ->
        case fetch_sender(tr, command.from, function.auth_type) do
          {:ok, nil, _sender_type} ->
            {:error, "Sender not found"}

          {:ok, sender = %{id: sender_id}, sender_type} ->
            cond do
              sender.channel != @channel && sender.channel != @default_channel ->
                {:error, "Invalid channel"}

              function.auth_type == 1 && !verify_signature(command, sender.public_key) ->
                {:error, "Invalid signature"}

              TxIndex.valid?(tr, sender_id, command.hash) ->
                {:error, "Transaction already executed"}

              true ->
                context = Context.new(tr, command, function, sender, sender_type)
                thread = thread(function, command)
                SpawnPool.cast(:worker_pool, thread, context)
                {:ok, "Transaction sent"}
            end

          {:ok, sender_type} ->
            context = Context.new(tr, command, function, nil, sender_type)
            thread = thread(function, command)
            SpawnPool.cast(:worker_pool, thread, context)
            {:ok, "Transaction sent"}

          {:error, _reason} = err ->
            err
        end

      _ ->
        {:error, "Function not found"}
    end
  end

  def run(context = %{command: command, fun: function}) do
    case :erlang.apply(function.mod, function.fun, [context | command.args]) do
      {:error, _reason} = err -> err
      result -> result
    end
  end

  def prepare(context = %{command: command}) do
    :ets.insert(:commands, {command.hash, context})
  end

  def push(context = %{command: command}) do
    :ets.insert(:commands, {command.hash, context, to_list(command)})
  end

  def to_list(%__MODULE__{args: args, from: from, fun: fun, time: time, sign: sign}) do
    [fun, args, from, time, sign]
  end

  def from_list([fun, args, from, time, sign]) do
    %__MODULE__{args: args, from: from, fun: fun, time: time, sign: sign}
    |> compute_hash()
  end
end
