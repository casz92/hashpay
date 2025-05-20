defmodule Mix.Tasks.Oban.Setup do
  @moduledoc """
  Tarea Mix para configurar Oban con SQLite.
  
  ## Ejemplos
  
      mix oban.setup
  """
  use Mix.Task
  
  @shortdoc "Configura Oban con SQLite"
  
  @impl Mix.Task
  def run(_args) do
    # Iniciar aplicaciones necesarias
    [:ecto_sqlite3, :logger, :oban]
    |> Enum.each(&Application.ensure_all_started/1)
    
    # Asegurar que el directorio para la base de datos exista
    db_path = Application.get_env(:hashpay, Hashpay.Repo)[:database]
    File.mkdir_p!(Path.dirname(db_path))
    
    # Iniciar el repositorio
    {:ok, _} = Hashpay.Repo.start_link()
    
    # Crear las tablas de Oban
    IO.puts("Creando tablas de Oban...")
    
    # Ejecutar las migraciones de Oban
    Oban.Migrations.up(Hashpay.Repo)
    
    IO.puts("Configuración de Oban completada.")
  end
end
