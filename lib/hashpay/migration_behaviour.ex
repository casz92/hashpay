defmodule Hashpay.MigrationBehaviour do
  @moduledoc """
  Módulo para definir migraciones de la base de datos.

  Define dos callbacks para las migraciones:
  - up: Función para aplicar la migración
  - down: Función para deshacer la migración
  """

  @callback up() :: :ok | {:error, term()}
  @callback down() :: :ok | {:error, term()}
end
