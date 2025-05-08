defmodule Hashpay.Currency.Command do
  alias Hashpay.Variable
  alias Hashpay.Balance
  alias Hashpay.Currency

  @default_currency Application.compile_env(:hashpay, :default_currency)

  def create(
        %{db: db, sender: %{id: sender_id}},
        attrs = %{"id" => currency_id, "name" => name}
      ) do
    cond do
      not Currency.match?(currency_id) ->
        {:error, "Invalid id"}

      not Currency.match_name?(name) ->
        {:error, "Invalid name"}

      Currency.exists?(db, currency_id) ->
        {:error, "Currency already exists"}

      true ->
        cost = Variable.get_currency_creation_cost()

        case Balance.get(db, sender_id, @default_currency) do
          amount when amount > cost ->
            currency = Currency.new(attrs)
            Balance.incr(db, sender_id, name, -cost)
            Currency.put(db, currency)

          _ ->
            {:error, "Insufficient balance"}
        end
    end
  end

  def change_name(ctx, id, name) do
    Currency.merge(ctx.db, id, %{name: name})
  end

  def change_pubkey(ctx, id, pubkey) do
    Currency.merge(ctx.db, id, %{pubkey: pubkey})
  end

  def update(_ctx = %{db: db, sender: %{id: sender_id}}, attrs) do
    attrs =
      Map.take(attrs, ["picture", "decimals", "symbol", "max_supply"])
      |> MapUtil.to_atoms()

    Currency.merge(db, sender_id, attrs)
  end

  def delete(ctx, id) do
    Currency.delete(ctx.db, id)
  end
end
