defmodule Hashpay.Currency.Command do
  alias Hashpay.Variable
  alias Hashpay.Balance
  alias Hashpay.Currency

  def create(
        %{db: db, conn: conn, sender: %{id: sender_id}},
        attrs = %{"id" => currency_id, "name" => name}
      ) do
    cond do
      not Currency.match?(currency_id) ->
        {:error, "Invalid id"}

      not Currency.match_name?(name) ->
        {:error, "Invalid name"}

      Currency.exists?(conn, currency_id) ->
        {:error, "Currency already exists"}

      true ->
        cost = Variable.get_currency_creation_cost()

        case Balance.get(conn, sender_id, currency_id) do
          {:ok, amount} when amount > cost ->
            currency = Currency.new(attrs)
            Balance.incr(db, sender_id, name, -cost)
            Currency.put(db, currency)

          {:error, :not_found} ->
            {:ok, :not_found}

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

  def update(ctx, id, attrs) do
    attrs =
      Map.take(attrs, ["picture", "decimals", "symbol", "max_supply"])
      |> MapUtil.to_atoms()

    Currency.merge(ctx.db, id, attrs)
  end

  def delete(ctx, id) do
    Currency.delete(ctx.db, id)
  end
end
