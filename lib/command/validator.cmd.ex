defmodule Hashpay.Validator.Command do
  alias Hashpay.Variable
  alias Hashpay.Validator
  alias Hashpay.ValidatorName
  alias Hashpay.Balance

  import Verify

  @default_currency Application.compile_env(:hashpay, :default_currency)

  def create(
        _ctx = %{db: db, sender: %{id: sender_id}},
        attrs = %{
          "name" => name,
          "pubkey" => pubkey,
          "hostname" => hostname,
          "port" => port,
          "channel" => channel
        }
      )
      when is_binary(name) and is_binary(hostname) and
             pubkey64?(pubkey) and
             valid_port?(port) and is_binary(channel) do
    cond do
      not host?(hostname) ->
        {:error, "Invalid hostname"}

      Validator.exists?(db, sender_id) ->
        {:error, "Validator already exists"}

      ValidatorName.exists?(db, name) ->
        {:error, "Validator name already exists"}

      true ->
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

  def create(_ctx, _attrs), do: {:error, "Invalid arguments"}

  def change_name(ctx = %{db: db}, name) when is_binary(name) do
    Validator.merge(db, ctx.sender.id, %{name: name})

    :math.pow(2, 10)
  end

  def change_name(_ctx, _name), do: {:error, "Invalid arguments"}

  def change_pubkey(ctx = %{db: db}, pubkey) when pubkey64?(pubkey) do
    Validator.merge(db, ctx.sender.id, %{pubkey: pubkey})
  end

  def change_pubkey(_ctx, _pubkey), do: {:error, "Invalid arguments"}

  def change_channel(ctx = %{db: db}, channel) when is_binary(channel) do
    Validator.merge(db, ctx.sender.id, %{channel: channel})
  end

  def change_channel(_ctx, _channel), do: {:error, "Invalid arguments"}

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
      })
      when is_money_positive(amount) and is_binary(currency) and is_binary(to) do
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

  def withdraw(_ctx, _attrs), do: {:error, "Invalid arguments"}

  def delete(ctx = %{db: db}) do
    case Validator.fetch(db, ctx.sender.id) do
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
