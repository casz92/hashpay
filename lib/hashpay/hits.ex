defmodule Hashpay.Hits do
  @moduledoc """
  Módulo para almacenar y gestionar hits (accesos) a objetos en una tabla ETS.

  Almacena información sobre objetos accedidos recientemente:
  - id: Identificador único del objeto
  - updated_at: Timestamp de la última actualización
  - hits: Contador de accesos al objeto
  """

  @table_name :hits

  @doc """
  Inicia el módulo de hits creando la tabla ETS.
  """
  def start_link do
    # Crear tabla ETS con nombre del módulo, pública y con concurrencia de lectura
    @table_name = :ets.new(@table_name, [:named_table, :public, :set, {:read_concurrency, true}])
    {:ok, self()}
  end

  @doc """
  Registra un hit para el ID especificado.
  Si el ID no existe, lo crea con un contador inicial de 1.
  Si existe, incrementa el contador y actualiza el timestamp.

  ## Parámetros

  - `id`: Identificador único del objeto

  ## Retorno

  - `{:ok, hits}`: Número actual de hits después de la operación
  """
  def register(id) do
    timestamp = :os.timestamp()

    case :ets.lookup(@table_name, id) do
      [] ->
        # Nuevo registro: {id, updated_at, hits}
        :ets.insert(@table_name, {id, timestamp, 1})
        {:ok, 1}

      [{^id, _old_timestamp, hits}] ->
        # Actualizar registro existente
        new_hits = hits + 1
        :ets.insert(@table_name, {id, timestamp, new_hits})
        {:ok, new_hits}
    end
  end

  @doc """
  Obtiene la información de hits para un ID específico.

  ## Parámetros

  - `id`: Identificador único del objeto

  ## Retorno

  - `{:ok, {updated_at, hits}}`: Timestamp y número de hits
  - `{:error, :not_found}`: Si el ID no existe
  """
  def get(id) do
    case :ets.lookup(@table_name, id) do
      [{^id, timestamp, hits}] -> {:ok, {timestamp, hits}}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Obtiene los N objetos más accedidos (con mayor número de hits).

  ## Parámetros

  - `limit`: Número máximo de objetos a retornar (por defecto 10)

  ## Retorno

  - Lista de tuplas `{id, updated_at, hits}` ordenadas por hits (descendente)
  """
  def top(limit \\ 10) do
    :ets.tab2list(@table_name)
    |> Enum.sort_by(fn {_id, _timestamp, hits} -> hits end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Obtiene los objetos actualizados más recientemente.

  ## Parámetros

  - `limit`: Número máximo de objetos a retornar (por defecto 10)

  ## Retorno

  - Lista de tuplas `{id, updated_at, hits}` ordenadas por timestamp (descendente)
  """
  def recent(limit \\ 10) do
    :ets.tab2list(@table_name)
    |> Enum.sort_by(fn {_id, timestamp, _hits} -> timestamp end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Elimina un registro de la tabla.

  ## Parámetros

  - `id`: Identificador único del objeto a eliminar
  """
  def delete(id) do
    :ets.delete(@table_name, id)
    :ok
  end

  @doc """
  Limpia registros antiguos basados en un timestamp límite.

  ## Parámetros

  - `older_than`: Timestamp límite (registros más antiguos serán eliminados)

  ## Retorno

  - Número de registros eliminados
  """
  def cleanup(older_than) do
    size = :ets.info(@table_name, :size)
    :ets.select_delete(@table_name, [{{:"$1", :"$2", :"$3"}, [{:<, :"$2", older_than}], [true]}])

    size
  end
end
