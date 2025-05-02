defmodule Hashpay.Account.Command do
  alias Hashpay.Function.Context
  alias Hashpay.Account

  @spec create(Context.t(), String.t(), binary(), String.t()) ::
          {:ok, Account.t()} | {:error, String.t()}
  def create(ctx, name, pubkey, channel) do
    account =
      Account.new(%{
        name: name,
        pubkey: pubkey,
        channel: channel
      })

    Account.fetch(ctx.conn, account.id)
    |> case do
      {:ok, _} ->
        {:error, "Account already exists"}

      {:error, :not_found} ->
        Account.batch_save(ctx.batch, account)
    end
  end

  def change_pubkey(ctx, pubkey) do
    Account.fetch(ctx.conn, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.batch_update_fields(ctx.batch, %{pubkey: pubkey}, account.id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def change_name(ctx, name) do
    Account.fetch(ctx.conn, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.batch_update_fields(ctx.batch, %{name: name}, account.id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def change_channel(ctx, channel) do
    Account.fetch(ctx.conn, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.batch_update_fields(ctx.batch, %{channel: channel}, account.id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def delete(ctx) do
    Account.fetch(ctx.conn, ctx.sender.id)
    |> case do
      {:ok, %{id: account_id}} ->
        Account.batch_delete(ctx.batch, account_id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end

  def verify(ctx, verified) do
    Account.fetch(ctx.conn, ctx.sender.id)
    |> case do
      {:ok, account} ->
        Account.batch_update_fields(ctx.batch, %{verified: verified}, account.id)

      {:error, :not_found} ->
        {:error, "Account not found"}
    end
  end
end
