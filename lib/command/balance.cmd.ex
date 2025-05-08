defmodule Hashpay.Balance.Command do
  alias Hashpay.Account
  alias Hashpay.Currency
  alias Hashpay.Balance

  def mint(ctx = %{db: db}, to, amount, currency_id) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(db, to) ->
        {:error, "Account not found"}

      not Currency.exists?(db, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(db, to, currency_id, amount)
    end
  end

  def transfer(_ctx = %{db: db, sender: %{id: from}}, to, amount, currency_id) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      from == to ->
        {:error, "Invalid transfer"}

      true ->
        case Balance.get(db, from, currency_id) do
          from_balance when from_balance >= amount ->
            Balance.incr(db, to, currency_id, amount)
            Balance.incr(db, from, currency_id, -amount)

          {:error, :not_found} ->
            {:error, "Balance not found"}

          _ ->
            {:error, "Insufficient balance"}
        end
    end
  end

  def frozen(ctx = %{db: db}, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(db, to) ->
        {:error, "Account not found"}

      not Currency.exists?(db, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(db, to, currency_id, -amount)
        Balance.incr(db, to, <<"frozen"::binary, currency_id::binary>>, amount)
    end
  end

  def unfrozen(ctx = %{db: db}, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(db, to) ->
        {:error, "Account not found"}

      not Currency.exists?(db, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(db, to, <<"frozen"::binary, currency_id::binary>>, -amount)
        Balance.incr(db, to, currency_id, amount)
    end
  end

  def burn(ctx = %{db: db}, currency_id, amount) do
    to = ctx.sender.id

    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      not Account.exists?(db, to) ->
        {:error, "Account not found"}

      not Currency.exists?(db, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(db, to, currency_id, -amount)
    end
  end

  def burn(ctx = %{db: db}, to, currency_id, amount) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      ctx.sender.id != currency_id ->
        {:error, "Invalid sender"}

      not Account.exists?(db, to) ->
        {:error, "Account not found"}

      not Currency.exists?(db, currency_id) ->
        {:error, "Currency not found"}

      true ->
        Balance.incr(db, to, currency_id, -amount)
    end
  end
end
