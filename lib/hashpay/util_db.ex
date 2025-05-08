defmodule Hashpay.Util.DB do
end

defmodule MapUtil do
  def to_atoms(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) -> {String.to_atom(k), v}
      {k, v} -> {k, v}
    end)
    |> Enum.into(%{})
  end

  def to_strings(map) do
    Map.new(map, fn
      {k, v} when is_atom(k) -> {Atom.to_string(k), v}
      {k, v} -> {k, v}
    end)
    |> Enum.into(%{})
  end
end
