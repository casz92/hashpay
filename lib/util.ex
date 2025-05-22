defmodule Util do
  def encode16(nil), do: nil
  def encode16(binary), do: Base.encode16(binary)

  def encode64(nil), do: nil
  def encode64(binary), do: Base.encode64(binary)
end
