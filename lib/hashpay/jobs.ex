defmodule Hashpay.Jobs do
  @moduledoc """
  Módulo para programar y gestionar trabajos en segundo plano con Oban.
  """

  alias Hashpay.Workers.DailyCleanup
  alias Hashpay.Workers.PeriodicCheck

  @doc """
  Programa una tarea de limpieza para ejecutarse inmediatamente.

  ## Ejemplos

      iex> Hashpay.Jobs.schedule_cleanup()
      {:ok, %Oban.Job{...}}
  """
  def schedule_cleanup do
    %{id: Ecto.UUID.generate()}
    |> DailyCleanup.new()
    |> Oban.insert()
  end

  @doc """
  Programa una tarea de limpieza para ejecutarse en un momento específico.

  ## Parámetros

  - `scheduled_at`: Fecha y hora programada para la ejecución

  ## Ejemplos

      iex> scheduled_at = ~U[2023-06-01 00:00:00Z]
      iex> Hashpay.Jobs.schedule_cleanup_at(scheduled_at)
      {:ok, %Oban.Job{...}}
  """
  def schedule_cleanup_at(scheduled_at) do
    %{id: Ecto.UUID.generate()}
    |> DailyCleanup.new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @doc """
  Programa una verificación periódica para ejecutarse inmediatamente.

  ## Ejemplos

      iex> Hashpay.Jobs.schedule_check()
      {:ok, %Oban.Job{...}}
  """
  def schedule_check do
    %{id: Ecto.UUID.generate()}
    |> PeriodicCheck.new()
    |> Oban.insert()
  end

  @doc """
  Programa una verificación periódica para ejecutarse en un momento específico.

  ## Parámetros

  - `scheduled_at`: Fecha y hora programada para la ejecución

  ## Ejemplos

      iex> scheduled_at = ~U[2023-06-01 12:00:00Z]
      iex> Hashpay.Jobs.schedule_check_at(scheduled_at)
      {:ok, %Oban.Job{...}}
  """
  def schedule_check_at(scheduled_at) do
    %{id: Ecto.UUID.generate()}
    |> PeriodicCheck.new(scheduled_at: scheduled_at)
    |> Oban.insert()
  end

  @doc """
  Programa una tarea personalizada para ejecutarse.

  ## Parámetros

  - `worker`: Módulo del trabajador
  - `args`: Argumentos para el trabajador
  - `opts`: Opciones adicionales (como queue, max_attempts, scheduled_at)

  ## Ejemplos

      iex> Hashpay.Jobs.schedule_job(MyWorker, %{key: "value"}, queue: :critical)
      {:ok, %Oban.Job{...}}
  """
  def schedule_job(worker, args, opts \\ []) do
    args
    |> worker.new(opts)
    |> Oban.insert()
  end

  @doc """
  Cancela un trabajo programado.

  ## Parámetros

  - `id`: ID del trabajo a cancelar

  ## Ejemplos

      iex> Hashpay.Jobs.cancel_job("123e4567-e89b-12d3-a456-426614174000")
      {:ok, %Oban.Job{...}}
  """
  def cancel_job(id) do
    Oban.cancel_job(id)
  end

  @doc """
  Obtiene información sobre un trabajo.

  ## Parámetros

  - `id`: ID del trabajo

  ## Ejemplos

      iex> Hashpay.Jobs.get_job("123e4567-e89b-12d3-a456-426614174000")
      {:ok, %Oban.Job{...}}
  """
  # def get_job(id) do
  #   case Oban.fetch_job(id) do
  #     {:ok, job} -> {:ok, job}
  #     {:error, :not_found} -> {:error, :not_found}
  #   end
  # end

  def get_job(id) do
    Hashpay.Repo.get_by(Oban.Job, id: id)
  end
end
