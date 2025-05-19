defmodule RoundTimer do
  alias EventBus.Model.Event
  use GenServer
  require Logger

  @round_time Application.compile_env(:hashpay, :round_time, 500)
  @round_timeout Application.compile_env(:hashpay, :round_timeout, 1_500)

  ## Public API
  def finish_round_timeout do
    GenServer.cast(__MODULE__, :finish)
  end

  def start_round_time do
    GenServer.cast(__MODULE__, :start)
  end

  ## Callbacks

  @doc false
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc false
  @impl true
  def init(_opts) do
    tref = Process.send_after(self(), :round_time, @round_time)

    {:ok, %{tref: tref, toref: nil}}
  end

  @doc false
  @impl true
  def handle_info(:round_time, state) do
    toref = Process.send_after(self(), :round_timeout, @round_timeout)

    {:noreply, %{state | tref: nil, toref: toref}}
  end

  @doc false
  @impl true
  def handle_info(:round_timeout, state) do
    # tref = Process.send_after(self(), :round_time, @round_time)
    EventBus.notify(%Event{
      id: :round_timeout,
      topic: :round_timeout,
      data: %{}
    })

    # {:noreply, %{state | tref: tref, toref: nil}}
    {:noreply, state}
  end

  @doc false
  @impl true
  def handle_cast(:finish, state) do
    if state.toref do
      Process.cancel_timer(state.toref)
      tref = Process.send_after(self(), :round_time, @round_time)
      {:noreply, %{state | toref: nil, tref: tref}}
    else
      {:noreply, state}
    end
  end

  @doc false
  @impl true
  def handle_cast(:start, state) do
    Process.cancel_timer(state.tref)
    tref = Process.send_after(self(), :round_time, @round_time)
    {:noreply, %{state | toref: nil, tref: tref}}
  end
end
