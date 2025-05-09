defmodule Hashpay.Merchant.Command do
  alias Hashpay.Merchant
  alias Hashpay.MerchantName
  alias Hashpay.Function.Context

  @spec create(Context.t(), map()) :: {:ok, Merchant.t()} | {:error, String.t()}
  def create(_ctx = %{db: db}, attrs) do
    merchant = Merchant.new(attrs)

    case Merchant.exists?(db, merchant.id) do
      true ->
        {:error, "Merchant already exists"}

      _false ->
        Merchant.put_new(db, merchant)
    end
  end

  def change_pubkey(ctx = %{db: db}, %{"pubkey" => pubkey}) do
    pubkey = Base.decode64!(pubkey)

    case Merchant.get(db, ctx.sender.id) do
      {:ok, merchant} ->
        Merchant.put(db, Map.put(merchant, :pubkey, pubkey))

      {:error, :not_found} ->
        {:error, "Merchant not found"}
    end
  end

  def change_name(ctx = %{db: db}, %{"name" => name}) do
    cond do
      not MerchantName.exists?(db, name) ->
        {:error, "The name: #{name} is already taken"}

      true ->
        case Merchant.get(db, ctx.sender.id) do
          {:ok, merchant} ->
            Merchant.put(db, Map.put(merchant, :name, name))

          {:error, :not_found} ->
            {:error, "Merchant not found"}
        end
    end
  end

  def change_channel(ctx = %{db: db}, %{"channel" => channel}) do
    case Merchant.get(db, ctx.sender.id) do
      {:ok, merchant} ->
        Merchant.put(db, Map.put(merchant, :channel, channel))

      {:error, :not_found} ->
        {:error, "Merchant not found"}
    end
  end

  def delete(ctx = %{db: db}) do
    case Merchant.get(db, ctx.sender.id) do
      {:ok, %{id: account_id}} ->
        Merchant.delete(db, account_id)

      {:error, :not_found} ->
        {:error, "Merchant not found"}
    end
  end
end
