defmodule Hashpay.Currency.Command do
  alias Hashpay.Variable
  alias Hashpay.Balance
  alias Hashpay.Currency

  def create(
        %{batch: batch, conn: conn, sender: %{id: sender_id}},
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
        currency = Currency.new(attrs)

        case Balance.fetch(conn, sender_id, currency_id) do
          {:ok, amount} when amount > cost ->
            Balance.incr(batch, sender_id, name, -cost)
            Currency.batch_save(batch, currency)

          {:error, :not_found} ->
            {:ok, :not_found}

          _ ->
            {:error, "Insufficient balance"}
        end
    end
  end

  def change_name(ctx, id, name) do
    Currency.batch_update_fields(ctx.batch, %{name: name}, id)
  end

  def change_pubkey(ctx, id, pubkey) do
    Currency.batch_update_fields(ctx.batch, %{pubkey: pubkey}, id)
  end

  def update(ctx, id, attrs) do
    attrs = Map.take(attrs, ["picture", "decimals", "symbol", "max_supply"])
    Currency.batch_update_fields(ctx.batch, attrs, id)
  end

  def delete(ctx, id) do
    Currency.batch_delete(ctx.batch, id)
  end
end
