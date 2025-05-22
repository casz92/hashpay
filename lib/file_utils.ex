defmodule FileUtils do
  def folder_size(path) when is_binary(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        path
        |> File.ls!()
        |> Enum.map(fn entry -> Path.join(path, entry) end)
        |> Enum.map(&folder_or_file_size/1)
        |> Enum.sum()
      {:ok, %{type: :regular, size: size}} ->
        size
      {:error, _} ->
        0
    end
  end

  defp folder_or_file_size(path) do
    case File.stat(path) do
      {:ok, %{type: :directory}} ->
        folder_size(path)
      {:ok, %{type: :regular, size: size}} ->
        size
      {:error, _} ->
        0
    end
  end
end
