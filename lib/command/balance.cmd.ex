defmodule Hashpay.Balance.Command do
  alias Hashpay.Account
  alias Hashpay.Currency
  alias Hashpay.Balance

  @supply "@supply"

  def mint(
        ctx = %{db: db, sender: %{id: currency_id, max_supply: max_supply}},
        %{"to" => to, "amount" => amount}
      ) do
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
        case Balance.incr_limit(db, currency_id, @supply, amount, max_supply) do
          {:ok, _new_amount} ->
            Balance.incr(db, to, currency_id, amount)

          _error ->
            {:error, "Max supply reached"}
        end
    end
  end

  def transfer(_ctx = %{db: db, sender: %{id: from, channel: channel}}, %{
        "to" => to,
        "amount" => amount,
        "currency" => currency_id
      }) do
    cond do
      amount <= 0 ->
        {:error, "Invalid amount"}

      from == to ->
        {:error, "Invalid transfer"}

      true ->
        fee = Hashpay.compute_fees(amount)
        total = amount + fee

        case Balance.incr_non_zero(db, from, currency_id, -total) do
          _amount ->
            Balance.incr(db, to, currency_id, amount)
            Balance.incr(db, channel, currency_id, fee)

          error ->
            error
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
        Balance.incr(db, currency_id, @supply, -amount)
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
        Balance.incr(db, currency_id, @supply, -amount)
    end
  end
end
