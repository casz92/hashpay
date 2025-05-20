defmodule Hashpay.Workers.PeriodicCheck do
  @moduledoc """
  Trabajador Oban para realizar verificaciones periódicas.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  require Logger

  @impl Oban.Worker
  def perform(_job) do
    Logger.info("Ejecutando verificación periódica")
    
    # Aquí iría la lógica de verificación
    # Por ejemplo, comprobar el estado del sistema, sincronizar datos, etc.
    
    # Simular trabajo
    Process.sleep(500)
    
    Logger.info("Verificación periódica completada")
    :ok
  end
end
