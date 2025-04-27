defmodule Hashpay.Util.Changeset do
  def cast(params) when is_map(params) do
    params
    |> Enum.map(fn {key, value} ->
      new_key = if is_binary(key), do: String.to_atom(key), else: key
      {new_key, value}
    end)
    |> Enum.into(%{})
  end

  def cast(params, allowed_keys) when is_map(params) and is_list(allowed_keys) do
    params
    |> Enum.map(fn {key, value} ->
      new_key = if is_binary(key), do: String.to_atom(key), else: key
      {new_key, value}
    end)
    |> Enum.into(%{})
    |> Map.take(allowed_keys)
  end
end
