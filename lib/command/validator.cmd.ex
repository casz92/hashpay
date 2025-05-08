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

        case Balance.get(db, sender_id, @default_currency) do
          amount when amount > cost ->
            validator = Validator.new(attrs)
            Balance.incr(db, sender_id, cost, -cost)
            Validator.put_new(db, validator)

          _ ->
            {:error, "Insufficient balance"}
        end
    end
  end

  def update(_ctx = %{db: db, sender: %{id: sender_id}}, attrs) do
    attrs =
      Map.take(attrs, ["picture", "factor_a", "factor_b", "active"])
      |> MapUtil.to_atoms()

    Validator.merge(db, sender_id, attrs)
  end

  def withdraw(ctx = %{db: db}, amount) do
    case Validator.get(db, ctx.sender.id) do
      {:ok, validator} ->
        Balance.incr(db, ctx.sender.id, amount, amount)
        Validator.put(db, Map.put(validator, :balance, validator.balance - amount))

      {:error, :not_found} ->
        {:error, "Validator not found"}
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
end
