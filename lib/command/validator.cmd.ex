defmodule Hashpay.Validator.Command do
  alias Hashpay.Variable
  alias Hashpay.Validator
  alias Hashpay.Balance

  @default_currency Application.compile_env(:hashpay, :default_currency)

  def create(_ctx = %{db: db, sender: %{id: sender_id}}, attrs) do
    case Validator.get(db, sender_id) do
      {:ok, _validator} ->
        {:error, "Validator already exists"}

      {:error, :not_found} ->
        cost = Variable.get_validator_creation_cost() * (Validator.total(db) + 1)

        case Balance.incr_non_zero(db, sender_id, @default_currency, -cost) do
          :ok ->
            validator = Validator.new(attrs)
            Validator.put_new(db, validator)

          error ->
            error
        end
    end
  end

  def change_name(ctx = %{db: db}, name) do
    Validator.merge(db, ctx.sender.id, %{name: name})
  end

  def change_pubkey(ctx = %{db: db}, pubkey) do
    Validator.merge(db, ctx.sender.id, %{pubkey: pubkey})
  end

  def change_channel(ctx = %{db: db}, channel) do
    Validator.merge(db, ctx.sender.id, %{channel: channel})
  end

  def update(_ctx = %{db: db, sender: %{id: sender_id}}, attrs) do
    attrs =
      Map.take(attrs, ["picture", "factor_a", "factor_b", "active"])
      |> MapUtil.to_atoms()

    Validator.merge(db, sender_id, attrs)
  end

  def withdraw(_ctx = %{db: db, sender: %{id: validator_id}}, %{
        "amount" => amount,
        "currency" => currency,
        "to" => to
      }) do
    cost = compute_withdrawal_fee(amount)

    case Balance.incr_non_zero(db, validator_id, @default_currency, -cost) do
      :ok ->
        case Balance.incr_non_zero(db, validator_id, currency, -amount) do
          :ok ->
            Balance.incr(db, to, currency, amount)

          error ->
            # rollback
            Balance.incr(db, validator_id, @default_currency, cost)
            error
        end

      error ->
        error
    end
  end

  def delete(ctx = %{db: db}) do
    case Validator.get(db, ctx.sender.id) do
      {:ok, validator} ->
        Validator.delete(db, validator)

      {:error, :not_found} ->
        {:error, "Validator not found"}
    end
  end

  defp compute_withdrawal_fee(amount) do
    case Variable.get_validator_withdrawal_fee() do
      0 -> amount
      fee -> trunc(amount * fee)
    end
  end
end
