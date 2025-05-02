defmodule Hashpay.Variable.Command do
  alias Hashpay.Variable

  def set(ctx, %{"key" => key, "value" => value}) do
    Variable.batch_save(ctx.batch, %Variable{key: key, value: value})
  end

  def set(ctx, key, value) do
    Variable.batch_save(ctx.batch, %Variable{key: key, value: value})
  end

  def delete(ctx, key) do
    Variable.batch_delete(ctx.batch, key)
  end
end
