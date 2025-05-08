defmodule Hashpay.Variable.Command do
  alias Hashpay.Variable

  def set(ctx, %{"key" => key, "value" => value}) do
    Variable.put(ctx.db, key, value)
  end

  def set(ctx, key, value) do
    Variable.put(ctx.db, key, value)
  end

  def delete(ctx, key) do
    Variable.delete(ctx.db, key)
  end
end
