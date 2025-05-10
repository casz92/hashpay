defmodule Hashpay.Property.Command do
  alias Hashpay.Property

  def set(%{db: db, sender: %{id: sender_id}}, %{"name" => name, "value" => value}) do
    first_char = :binary.first(name)

    cond do
      especial_char?(first_char) ->
        {:error, "Invalid name"}

      true ->
        Property.put(db, sender_id, name, value)
    end
  end

  def delete(%{db: db, sender: %{id: sender_id}}, %{"name" => name}) do
    first_char = :binary.first(name)

    cond do
      especial_char?(first_char) ->
        {:error, "Invalid name"}

      true ->
        Property.delete(db, sender_id, name)
    end
  end

  def especial_char?(char) do
    char in 0..47 or
      char in 58..64 or
      char in 91..96 or
      char in 123..255
  end
end
