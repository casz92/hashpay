defmodule Hashpay.Variable.Command do
  alias Hashpay.Variable

  @governance "governance"

  def set(ctx = %{db: db, sender: %{id: @governance}}, %{"key" => key, "value" => value}) do
    Variable.put(db, key, value)
  end

  def delete(ctx = %{db: db, sender: %{id: @governance}}, %{"key" => key}) do
    Variable.delete(db, key)
  end
end
