defmodule Hashpay.Payday.Command do
  alias Hashpay.{Payday, Account}
  alias Hashpay.Balance
  alias Hashpay.Currency
  alias Hashpay.Property

  @supply "@supply"
  @default_amount 100
  @default_period 172_800

  def create(%{db: db, sender: %{id: sender_id, verified: verified}}, %{
        "currency" => currency_id
      }) do
    payday_id = Payday.generate_id(sender_id, currency_id)
    props = Property.get(db, currency_id)

    cond do
      verified < 0 ->
        {:error, "Account not verified"}

      Account.match?(sender_id) ->
        {:error, "Invalid account"}

      is_nil(props) or not Map.has_key?(props, "payday") ->
        {:error, "Currency is not payday property"}

      not Payday.exists?(db, payday_id) ->
        {:error, "Payday already exists"}

      true ->
        amount = Map.get(props, "payday", @default_amount)
        payday = Payday.new(sender_id, currency_id)
        Payday.put(db, payday)
        Balance.incr(db, payday_id, amount)
    end
  end

  def claim(%{db: db, sender: %{id: sender_id}}, %{"currency" => currency_id}) do
    payday_id = Payday.generate_id(sender_id, currency_id)

    case Payday.fetch(db, payday_id) do
      {:ok, payday} ->
        last_round_id = Hashpay.get_last_round_id()
        currency = Currency.get(db, currency_id)
        props = Property.get(db, currency_id)
        payday_period = Map.get(props, "payday_period", @default_period)
        payday_max_to_claim = Map.get(props, "payday_max_to_claim", 60)
        amount = Map.get(props, "payday", @default_amount)
        rounds = div(last_round_id - payday.last_payday, payday_period)

        cond do
          rounds > payday_max_to_claim ->
            Payday.put(db, %{payday | last_payday: last_round_id})

          rounds > 0 ->
            case Balance.incr_limit(db, currency_id, @supply, amount, currency.max_supply) do
              {:ok, _new_amount} ->
                Balance.incr(db, payday_id, amount)
                Payday.put(db, %{payday | last_payday: last_round_id})

              error ->
                error
            end

          true ->
            {:error, "Payday already claimed"}
        end

      error ->
        error
    end
  end

  def withdraw(%{db: db, sender: %{id: sender_id}}, %{
        "currency" => currency_id,
        "amount" => amount
      }) do
    payday_id = Payday.generate_id(sender_id, currency_id)

    case Payday.fetch(db, payday_id) do
      {:ok, payday} ->
        case Balance.incr_non_zero(db, payday_id, -amount) do
          {:ok, _result_amount} ->
            last_round_id = Hashpay.get_last_round_id()

            Payday.put(db, %{payday | last_withdraw: last_round_id})

          _error ->
            {:error, "payday balance insufficient"}
        end

      {:error, :not_found} ->
        {:error, "Payday not found"}
    end
  end
end
