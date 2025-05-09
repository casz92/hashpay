defmodule Paystream.Command do
  alias Hashpay.{Paystream, Balance, Property, Payday, Merchant}

  @min_withdrawal_amount 10_000

  def send(%{db: db, sender: %{id: merchant_id}}, %{
        "to" => to,
        "amount" => amount,
        "currency" => currency_id,
        "from" => from
      })
      when amount >= 1 do
    paystream_id = Paystream.generate_id(to, currency_id, merchant_id)
    payday_id = Payday.generate_id(from, currency_id)

    case Balance.incr_non_zero(db, payday_id, -amount) do
      {:ok, _result_amount} ->
        Balance.incr(db, paystream_id, amount)

      _error ->
        {:error, "Payday balance insufficient"}
    end
  end

  def withdraw(%{db: db, sender: %{id: sender_id}}, %{
        "amount" => amount,
        "currency" => currency_id,
        "merchant" => merchant_id
      }) do
    props = Property.get(db, merchant_id)
    min_withdrawal_amount = Map.get(props, "min_withdrawal_amount", @min_withdrawal_amount)

    cond do
      amount < min_withdrawal_amount ->
        {:error, "Amount below minimum withdrawal amount"}

      not Merchant.match?(merchant_id) ->
        {:error, "Invalid merchant"}

      true ->
        percent = Map.get(props, "paystream_withdrawal_fee", 0.01)
        fee = amount * percent
        total = amount + fee
        paystream_id = Paystream.generate_id(sender_id, currency_id, merchant_id)

        case Balance.incr_non_zero(db, paystream_id, -total) do
          {:ok, _result_amount} ->
            Balance.incr(db, merchant_id, currency_id, fee)
            Balance.incr(db, sender_id, currency_id, amount)

          _error ->
            {:error, "Paystream balance insufficient"}
        end
    end
  end
end
