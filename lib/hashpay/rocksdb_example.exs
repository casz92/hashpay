defmodule RocksdbExample do
  @moduledoc """
  Ejemplo completo y corregido de operaciones con RocksDB en Elixir,
  basado en los ejemplos de Erlang.
  """

  require Logger

  @db_path ~c"my_rocksdb_elixir"

  # --- Utilidades Internas ---

  defp rm_rf(path) do
    File.rm_rf!(path)
  end

  defp open_db(opts \\ []) do
    with {:ok, db} <- :rocksdb.open(@db_path, [{:create_if_missing, true} | opts]) do
      {:ok, db}
    end
  rescue
    e ->
      Logger.error("Error al abrir la base de datos: #{inspect(e)}")
      {:error, e}
  end

  defp close_and_destroy_db(db) do
    :rocksdb.close(db)
    :rocksdb.destroy(@db_path, [])
    rm_rf(@db_path)
  end

  # --- Operaciones Básicas ---

  def start() do
    Logger.info("Iniciando RocksDB en '#{@db_path}'")

    {:ok, pid} =
      Supervisor.start_link(
        [
          {Rocksdb.Supervisor, name: :rocksdb_sup, path: @db_path}
        ],
        strategy: :one_for_one
      )

    {:ok, pid}
  end

  def stop() do
    Logger.info("Deteniendo RocksDB...")
    Supervisor.stop(:rocksdb_sup)
    :ok
  end

  def open(opts \\ []) do
    Logger.info("Abriendo base de datos...")
    open_db(opts)
  end

  def close(db) do
    Logger.info("Cerrando base de datos...")
    :rocksdb.close(db)
  end

  def destroy() do
    Logger.info("Destruyendo base de datos en '#{@db_path}'")
    :rocksdb.destroy(@db_path, [])
    rm_rf(@db_path)
  end

  def put(db, key, value) do
    Logger.debug("Insertando/Actualizando: Key = #{key}, Value = #{value}")
    :rocksdb.put(db, key, value, [])
  end

  def put(db, index, key, value) do
    Logger.debug("Insertando/Actualizando: Key = #{key}, Value = #{value}, Opts = #{opts}")
    :rocksdb.put(db, key, value, opts)
  end

  def put(db, dh, key, value) do
    Logger.debug("Insertando/Actualizando: Key = #{key}, Value = #{value}")
    :rocksdb.put(db, dh, key, value, [])
  end

  def get(db, key) do
    result = :rocksdb.get(db, key, [])
    Logger.debug("Obteniendo: Key = #{key}, Result = #{inspect(result)}")
    result
  end

  def get(db, dh, key) do
    result = :rocksdb.get(db, dh, key, [])
    Logger.debug("Obteniendo: Key = #{key}, Result = #{inspect(result)}")
    result
  end

  def delete(db, key, opts \\ []) do
    Logger.debug("Eliminando: Key = #{key}, Opts = #{opts}")
    :rocksdb.delete(db, key, opts)
  end

  def is_empty(db) do
    result = :rocksdb.is_empty(db)
    Logger.debug("¿Está vacía?: #{result}")
    result
  end

  def count(db) do
    result = :rocksdb.count(db)
    Logger.debug("Conteo: #{result}")
    result
  end

  # --- Iteradores ---

  def iterator(db, opts \\ []) do
    Logger.debug("Creando iterador con opciones: #{opts}")
    {:ok, it} = :rocksdb.iterator(db, opts)
    {:ok, it}
  end

  def iterator_move(iterator, direction_or_key) do
    result = :rocksdb.iterator_move(iterator, direction_or_key)
    Logger.debug("Moviendo iterador: #{direction_or_key}, Result = #{inspect(result)}")
    result
  end

  def iterator_close(iterator) do
    Logger.debug("Cerrando iterador")
    :rocksdb.iterator_close(iterator)
  end

  # --- Batch Operations ---

  def batch() do
    with {:ok, batch} <- :rocksdb.batch() do
      {:ok, batch}
    end
  end

  def batch_put(batch, key, value) do
    Logger.debug("Batch Put: Key = #{key}, Value = #{value}")
    :rocksdb.batch_put(batch, key, value)
  end

  def batch_delete(batch, key) do
    Logger.debug("Batch Delete: Key = #{key}")
    :rocksdb.batch_delete(batch, key)
  end

  def write_batch(db, batch, opts \\ []) do
    Logger.debug("Escribiendo Batch, Opts = #{opts}")
    :rocksdb.write_batch(db, batch, opts)
  end

  def release_batch(batch) do
    Logger.debug("Liberando Batch")
    :rocksdb.release_batch(batch)
  end

  # --- Column Families ---

  def open_with_cf(opts, column_families) do
    Logger.info("Abriendo DB con Column Families: #{inspect(column_families)}, Opts: #{opts}")
    :rocksdb.open(@db_path, [{:create_if_missing, true} | opts], column_families)
  end

  def list_column_families(opts \\ []) do
    result = :rocksdb.list_column_families(@db_path, opts)
    Logger.debug("Listando Column Families: #{result}")
    result
  end

  def create_column_family(db, cf_name, opts \\ []) do
    Logger.info("Creando Column Family: #{inspect(cf_name)}, Opts: #{opts}")
    {:ok, cf_handle} = :rocksdb.create_column_family(db, cf_name, opts)
    {:ok, cf_handle}
  end

  def drop_column_family(db, cf_handle) do
    Logger.info("Eliminando Column Family")
    :rocksdb.drop_column_family(db, cf_handle)
  end

  def snapshot(db) do
    :rocksdb.snapshot(db)
  end

  # --- Otras Operaciones (Ejemplos) ---

  def delete_range(db, start_key, end_key, opts \\ []) do
    Logger.info("Eliminando rango: Start = #{start_key}, End = #{end_key}, Opts: #{opts}")
    :rocksdb.delete_range(db, start_key, end_key, opts)
  end

  # --- Ejemplos de Uso ---

  def basic_example() do
    with {:ok, db} <- open() do
      put(db, "key1", "value1")
      put(db, "key2", "value2")
      get(db, "key1")
      delete(db, "key2")
      get(db, "key2")
      close(db)
      destroy()
    end
  end

  def batch_example() do
    {:ok, db} = open()
    {:ok, batch} = batch()
    batch_put(batch, "a", "1")
    batch_put(batch, "b", "2")
    batch_delete(batch, "a")
    write_batch(db, batch)
    get(db, "b")

    release_batch(batch)
    close(db)
    destroy()
  end

  def iterator_example() do
    {:ok, db} = open()
    put(db, "a", "1")
    put(db, "b", "2")
    put(db, "c", "3")
    {:ok, it} = iterator(db)
    iterator_move(it, :first)
    iterator_move(it, :next)
    iterator_close(it)
    close(db)
    destroy()
  end

  def column_family_example() do
    with {:ok, db, handles} <- open_with_cf([], [{~c"default", []}]),
         {:ok, cf_handle} <- create_column_family(db, ~c"cf1") do
      put(db, cf_handle, "key1", "value1")
      get(db, cf_handle, "key1")
      drop_column_family(db, cf_handle)
      close(db)
      destroy()
    end
  end

  def delete_range_example() do
    with {:ok, db} <- open() do
      put(db, "a", "1")
      put(db, "b", "2")
      put(db, "c", "3")
      delete_range(db, "b", "c")
      get(db, "a")
      get(db, "b")
      get(db, "c")
      close(db)
      destroy()
    end
  end
end
