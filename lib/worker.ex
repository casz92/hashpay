defmodule Hashpay.Worker do
  use GenServer
  require Logger
  alias Hashpay.Function.Context

  def start_link({name, id}) do
    GenServer.start_link(__MODULE__, id, name: via_tuple(name, id))
  end

  defp via_tuple(name, id), do: {:via, Registry, {name, id}}

  @impl true
  def init(args) do
    {:ok, args}
  end

  @impl true
  def handle_call(context = %Context{cmd: command, fun: function}, _from, state) do
    result = :erlang.apply(function.mod, function.fun, [context | command.args])
    {:reply, result, state}
  end

  def handle_call(:ping, _from, state) do
    {:reply, {:pong, state}, state}
  end

  @impl true
  def handle_cast(context = %Context{cmd: command, fun: function}, state) do
    case :erlang.apply(function.mod, function.fun, [context | command.args]) do
      {:error, reason} ->
        Logger.debug("Error handling command: #{reason}")
        {:noreply, state}

      _result ->
        {:noreply, state}
    end
  end
end
