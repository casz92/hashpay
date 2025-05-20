defmodule Hashpay.NetType.Request do
  @enforce_keys [:id, :method, :params]
  defstruct [
    :id,
    :method,
    :params
  ]
end

defmodule Hashpay.NetType.Response do
  @enforce_keys [:id, :status]
  defstruct [
    :id,
    :status,
    :data
  ]
end

defmodule Hashpay.NetType.Event do
  @enforce_keys [:event, :data]
  defstruct [
    :id,
    :event,
    :data,
    :timestamp
  ]
end
