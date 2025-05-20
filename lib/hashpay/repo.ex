defmodule Hashpay.Repo do
  use Ecto.Repo,
    otp_app: :hashpay,
    adapter: Ecto.Adapters.SQLite3
end
