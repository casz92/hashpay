defmodule Mix.Tasks.Pg.Migrate do
  use Mix.Task
  alias Hashpay.Postgres

  @shortdoc "Ejecuta migraciones en PostgreSQL"
  @moduledoc """
  Ejecuta migraciones en la base de datos PostgreSQL.

  ## Ejemplos

      mix pg.migrate up
      mix pg.migrate down
  """

  def run(args) do
    # Iniciar aplicaciones necesarias
    [:postgrex, :logger]
    |> Enum.each(&Application.ensure_all_started/1)

    # Cargar configuración
    Application.ensure_all_started(:hashpay)

    case args do
      ["up"] ->
        IO.puts("Ejecutando migraciones UP en PostgreSQL...")
        create_tables()
        IO.puts("Migraciones completadas.")

      ["down"] ->
        IO.puts("Ejecutando migraciones DOWN en PostgreSQL...")
        drop_tables()
        IO.puts("Migraciones completadas.")

      _ ->
        IO.puts("Uso: mix pg.migrate [up|down]")
    end
  end

  defp create_tables do
    # Crear tabla de usuarios
    Postgres.create_table("users", """
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL UNIQUE,
    email VARCHAR(100) NOT NULL UNIQUE,
    password_hash VARCHAR(100) NOT NULL,
    full_name VARCHAR(100),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    """)

    # Crear tabla de transacciones
    Postgres.create_table("transactions", """
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL REFERENCES users(id),
    amount DECIMAL(20, 8) NOT NULL,
    currency VARCHAR(10) NOT NULL,
    transaction_type VARCHAR(20) NOT NULL,
    status VARCHAR(20) NOT NULL,
    reference VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    """)

    # Crear tabla de configuraciones
    Postgres.create_table("settings", """
    id SERIAL PRIMARY KEY,
    key VARCHAR(50) NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    """)

    # Crear tabla de logs
    Postgres.create_table("logs", """
    id SERIAL PRIMARY KEY,
    level VARCHAR(10) NOT NULL,
    message TEXT NOT NULL,
    metadata JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    """)

    # Crear índices
    Postgres.query("CREATE INDEX idx_transactions_user_id ON transactions(user_id)")
    Postgres.query("CREATE INDEX idx_transactions_status ON transactions(status)")
    Postgres.query("CREATE INDEX idx_logs_level ON logs(level)")
    Postgres.query("CREATE INDEX idx_logs_created_at ON logs(created_at)")
  end

  defp drop_tables do
    # Eliminar tablas en orden inverso para respetar las restricciones de clave foránea
    Postgres.drop_table("logs")
    Postgres.drop_table("settings")
    Postgres.drop_table("transactions")
    Postgres.drop_table("users")
  end
end
