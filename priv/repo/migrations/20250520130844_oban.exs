defmodule Hashpay.Repo.Migrations.Oban do
  use Ecto.Migration

  def up do
    Oban.Migrations.up(version: 1)
  end

  def down do
    Oban.Migrations.down(version: 1)
  end
end
