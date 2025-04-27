defmodule Hashpay.Broker do
  use GenServer
  require Logger

  def start_link(opts) do
    case GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__) do
      {:ok, pid} ->
        Logger.info("Running Hashpay.Broker ✅")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start Hashpay.Broker ❌: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def init(_args) do
    {:ok, %{members: []}}
  end

  @impl true
  def handle_call(:members, _from, %{members: members} = state) do
    {:reply, members, state}
  end

  @impl true
  def handle_cast({:join, member}, %{members: members} = state) do
    {:noreply, %{state | member: [member | members]}}
  end

  def handle_cast({:leave, member}, %{members: members} = state) do
    {:noreply, %{state | member: List.delete(members, member)}}
  end

  def join(member) do
    GenServer.cast(__MODULE__, {:join, member})
  end

  def leave(member) do
    GenServer.cast(__MODULE__, {:leave, member})
  end

  def members do
    GenServer.call(__MODULE__, :members)
  end
end
