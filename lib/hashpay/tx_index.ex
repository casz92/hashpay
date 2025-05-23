defmodule Hashpay.TxIndex do
  @compile {:inline, [put: 3, valid?: 3]}

  def dbopts do
    [
      name: :tx_index,
      handle: ~c"tx_index",
      exp: true
    ]
  end

  def put(tr, sender_id, tx_hash) do
    ThunderRAM.put(tr, :tx_index, tx_hash, sender_id)
  end

  def valid?(tr, sender_id, tx_hash) do
    case ThunderRAM.get(tr, :tx_index, sender_id) do
      {:ok, hash} -> tx_hash > hash
      _ -> false
    end
  end
end
