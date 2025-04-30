defmodule Hashpay.Cluster do
  use GenServer
  require Logger
  alias Hashpay.ClusterNode
  alias Hashpay.Cluster.Member

  @module_name Module.split(__MODULE__) |> Enum.join(".")

  def start_link(opts) do
    case GenServer.start_link(__MODULE__, opts, name: opts[:name] || __MODULE__) do
      {:ok, pid} ->
        Logger.debug("Running #{@module_name} ✅")
        {:ok, pid}

      {:error, reason} ->
        Logger.error("Failed to start #{@module_name} ❌: #{inspect(reason)}")
        {:error, reason}
    end
  end

  @impl true
  def init(_args) do
    tid = :ets.new(:cluster_members, [:set, :public, :named_table])
    {:ok, %{ets_table: tid}}
  end

  @impl true
  def handle_call(:members, _from, state) do
    members = :ets.tab2list(state.ets_table)
    {:reply, members, state}
  end

  def join(%ClusterNode{name: name} = _node) do
    member = Member.new(name, self())
    :ets.insert(:cluster_members, {name, member})
  end

  def leave(member_id) do
    :ets.delete(:cluster_members, member_id)
  end

  def get_and_authenticate(name, message, signature) do
    conn = Hashpay.DB.get_conn()
    ClusterNode.get_and_authenticate(conn, name, message, signature)
  end

  def members do
    GenServer.call(__MODULE__, :members)
  end
end
