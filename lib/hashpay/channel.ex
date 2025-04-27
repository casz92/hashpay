defmodule Hashpay.Channel do
  @default_channel Application.compile_env(:hashpay, :default_channel)
  @channel Application.compile_env(:hashpay, :channel)

  def main, do: @default_channel

  def current, do: @channel
end
