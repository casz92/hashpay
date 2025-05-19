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
        cost = Variable.get_currency_creation_cost() * (Currency.total(db) + 1)

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
    cond do
      not Currency.match_name?(name) ->
        {:error, "Invalid name"}

      true ->
        case Currency.get(ctx.db, id) do
          {:ok, currency} ->
            Currency.put(ctx.db, Map.put(currency, :name, name))

          {:error, :not_found} ->
            {:error, "Currency not found"}
        end
    end
  end

  def change_pubkey(ctx, id, pubkey) do
    pubkey = Base.decode64!(pubkey)

    case Currency.get(ctx.db, id) do
      {:ok, currency} ->
        Currency.put(ctx.db, Map.put(currency, :pubkey, pubkey))

      {:error, :not_found} ->
        {:error, "Currency not found"}
    end
  end

  def change_channel(ctx, id, channel) do
    case Currency.get(ctx.db, id) do
      {:ok, currency} ->
        Currency.put(ctx.db, Map.put(currency, :channel, channel))

      {:error, :not_found} ->
        {:error, "Currency not found"}
    end
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
