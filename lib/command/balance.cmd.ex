defmodule Hashpay.Balance.Command do
  alias Hashpay.Account
  alias Hashpay.Currency
  alias Hashpay.Balance

  def mint(ctx, to, amount, currency_id) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(ctx.conn, to) ->
        {:error, "Account not found"}

      not Currency.exists?(ctx.conn, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(ctx.batch, to, currency_id, amount)
    end
  end

  def transfer(ctx = %{sender: %{id: from}}, to, amount, currency_id) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      from == to ->
        {:error, "Invalid transfer"}

      true ->
        case Balance.fetch(ctx.conn, from, currency_id) do
          {:ok, from_balance} when from_balance >= amount ->
            Balance.incr(ctx.batch, to, currency_id, amount)
            Balance.incr(ctx.batch, from, currency_id, -amount)

          {:error, :not_found} ->
            {:error, "Balance not found"}

          _ ->
            {:error, "Insufficient balance"}
        end
    end
  end

  def frozen(ctx, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(ctx.conn, to) ->
        {:error, "Account not found"}

      not Currency.exists?(ctx.conn, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(ctx.batch, to, currency_id, -amount)
        Balance.incr(ctx.batch, to, <<"frozen"::binary, currency_id::binary>>, amount)
    end
  end

  def unfrozen(ctx, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(ctx.conn, to) ->
        {:error, "Account not found"}

      not Currency.exists?(ctx.conn, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(ctx.batch, to, <<"frozen"::binary, currency_id::binary>>, -amount)
        Balance.incr(ctx.batch, to, currency_id, amount)
    end
  end

  def burn(ctx, currency_id, amount) do
    to = ctx.sender.id

    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      not Account.exists?(ctx.conn, to) ->
        {:error, "Account not found"}

      not Currency.exists?(ctx.conn, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(ctx.batch, to, currency_id, -amount)
    end
  end

  def burn(ctx, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(ctx.conn, to) ->
        {:error, "Account not found"}

      not Currency.exists?(ctx.conn, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(ctx.batch, to, currency_id, -amount)
    end
  end
end
