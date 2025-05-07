defmodule Hashpay.Account.Command do
  alias Hashpay.Function.Context
  alias Hashpay.Account

  @spec create(Context.t(), String.t(), binary(), String.t()) ::
          {:ok, Account.t()} | {:error, String.t()}
  def create(ctx = %{db: db}, name, pubkey, channel) do
    account =
      Account.new(%{
        name: name,
        pubkey: pubkey,
        channel: channel
      })

    Account.fetch(db, account.id)
    |> case do
      {:ok, _} ->
        {:error, "Account already exists"}

      {:error, :not_found} ->
        Account.put(db, account)
    end
  end

  def change_pubkey(ctx = %{db: db}, pubkey) do
    Account.fetch(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :pubkey, pubkey))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def change_name(ctx = %{db: db}, name) do
    Account.fetch(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :name, name))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def change_channel(ctx = %{db: db}, channel) do
    Account.fetch(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :channel, channel))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def delete(ctx = %{db: db}) do
    Account.fetch(db, ctx.sender.id)
    |> case do
      {:ok, %{id: account_id}} ->
        Account.delete(db, account_id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def verify(ctx = %{db: db}, verified) do
    Account.fetch(db, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.put(db, Map.put(account, :verified, verified))

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end
end
