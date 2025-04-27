defmodule Hashpay.Cluster.Member do
  defstruct [
    :id,
    :pid,
    :channels,
    :joined_at
  ]

  def new(id, pid) do
    %__MODULE__{
      id: id,
      pid: pid,
      channels: [],
      joined_at: System.os_time(:millisecond)
    }
  end
end
