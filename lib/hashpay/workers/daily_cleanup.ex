defmodule Hashpay.Workers.DailyCleanup do
  @moduledoc """
  Trabajador Oban para realizar limpieza diaria de datos.
  """
  use Oban.Worker, queue: :background, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Ejecutando limpieza diaria")
    
    # Aquí iría la lógica de limpieza
    # Por ejemplo, eliminar datos antiguos, archivos temporales, etc.
    
    # Simular trabajo
    Process.sleep(1000)
    
    Logger.info("Limpieza diaria completada")
    :ok
  end
end
