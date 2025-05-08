defmodule Hashpay.Account.Command do
  alias Hashpay.Function.Context
  alias Hashpay.Account
  alias Hashpay.AccountName

  @spec create(Context.t(), map()) :: {:ok, Account.t()} | {:error, String.t()}
  def create(_ctx = %{db: db}, attrs) do
    account = Account.new(attrs)

    Account.get(db, account.id)
    |> case do
      {:ok, _} ->
        {:error, "Account already exists"}

      {:error, :not_found} ->
        Account.put(db, account)
    end
  end

  def change_pubkey(ctx = %{db: db}, %{"pubkey" => pubkey}) do
    pubkey = Base.decode64!(pubkey)

    Account.get(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :pubkey, pubkey))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def change_name(ctx = %{db: db}, %{"name" => name}) do
    cond do
      not AccountName.exists?(db, name) ->
        {:error, "The name: #{name} is already taken"}

      true ->
        Account.get(db, ctx.sender.id)
        |> case do
          {:ok, account} ->
            Account.put(db, Map.put(account, :name, name))

          {:error, :not_found} ->
            {:error, "Account not found"}
        end
    end
  end

  def change_channel(ctx = %{db: db}, %{"channel" => channel}) do
    Account.get(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :channel, channel))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def delete(ctx = %{db: db}) do
    Account.get(db, ctx.sender.id)
    |> case do
      {:ok, %{id: account_id}} ->
        Account.delete(db, account_id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def verify(ctx = %{db: db}, %{"level" => level}) do
    Account.get(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :verified, level))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end
end
