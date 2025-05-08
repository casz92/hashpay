defmodule Hashpay.Account do
  alias Hashpay.Account
  alias Hashpay.AccountName

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          pubkey: binary,
          channel: String.t(),
          verified: integer(),
          type_alg: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :pubkey,
    :channel,
    :type_alg,
    verified: 0
  ]

  @prefix "ac_"
  @regex ~r/^ac_[a-zA-Z0-9]*$/
  @trdb :accounts

  @compile {:inline, [put: 2, put_new: 2, exists?: 2, delete: 2]}

  def dbopts do
    [
      name: :accounts,
      cf: ~c"accounts",
      exp: true
    ]
  end

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base62.encode(first16bytes)])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(attrs = %{"pubkey" => pubkey, "name" => name, "channel" => channel}) do
    %__MODULE__{
      id: generate_id(pubkey),
      name: name,
      pubkey: Base.decode64!(pubkey),
      channel: channel,
      type_alg: Map.get(attrs, "type_alg", 0)
    }
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def verified?(%Account{verified: verified}), do: verified > 0

  def put(tr, %Account{} = account) do
    ThunderRAM.put(tr, @trdb, account.id, account)
  end

  def put_new(tr, %Account{name: name, id: id} = account) do
    ThunderRAM.put(tr, @trdb, id, account)
    AccountName.put(tr, name, id)
  end

  def exists?(tr, id) do
    ThunderRAM.exists?(tr, @trdb, id)
  end

  def delete(tr, %__MODULE__{id: id, name: name}) do
    ThunderRAM.delete(tr, @trdb, id)
    AccountName.delete(tr, name)
  end

  def delete(tr, id) do
    account = get(tr, id)
    ThunderRAM.delete(tr, @trdb, id)
    AccountName.delete(tr, account.name)
  end
end

defmodule Hashpay.AccountName do
  @compile {:inline, [put: 3, exists?: 2, delete: 2]}
  @trdb :account_names_idx

  def dbopts do
    [
      name: @trdb,
      cf: ~c"account_names_idx",
      exp: false
    ]
  end

  def put(tr, name, id) do
    ThunderRAM.put(tr, @trdb, name, id)
  end

  def exists?(tr, name) do
    ThunderRAM.exists?(tr, @trdb, name)
  end

  def delete(tr, name) do
    ThunderRAM.delete(tr, @trdb, name)
  end
end
