defmodule Hashpay.Balance do
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          amount: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :amount,
    updated: 0
  ]

  @trdb :balances
  import ThunderRAM, only: [key_merge: 2]

  @compile {:inline, [put: 4, incr: 4, get: 3, delete: 2]}

  def new(account_id, name, amount \\ 0) do
    %__MODULE__{
      id: account_id,
      name: name,
      amount: amount,
      updated: Hashpay.get_last_round_id()
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"balances",
      exp: true
    ]
  end

  def incr(tr, id, token, amount) do
    ThunderRAM.incr(tr, @trdb, key_merge(id, token), {2, amount})
  end

  def get(tr, id, token) do
    key = key_merge(id, token)

    case ThunderRAM.get(tr, @trdb, key) do
      {:ok, amount} -> amount
      _ -> 0
    end
  end

  def put(tr, id, token, amount) do
    ThunderRAM.put(tr, @trdb, key_merge(id, token), amount)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
