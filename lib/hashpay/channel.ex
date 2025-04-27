defmodule Hashpay.Channel do
  def root do
    Application.get_env(:hashpay, :origin, "origin")
  end

  def current do
    Application.get_env(:hashpay, :channel)
  end
end
