defmodule Hashpay.Property.Command do
  alias Hashpay.Property

  def set(%{db: db, sender: %{id: sender_id}}, %{"name" => name, "value" => value}) do
    first_char = String.first(name)

    cond do
      first_char == "@" ->
        {:error, "Invalid name"}

      true ->
        Property.put(db, sender_id, name, value)
    end
  end

  def delete(%{db: db, sender: %{id: sender_id}}, %{"name" => name}) do
    first_char = String.first(name)

    cond do
      first_char == "@" ->
        {:error, "Invalid name"}

      true ->
        Property.delete(db, sender_id, name)
    end
  end
end
