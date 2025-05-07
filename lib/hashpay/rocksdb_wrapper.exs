defmodule RocksDBWrapper do
  @moduledoc """
  Módulo para gestionar operaciones CRUD con RocksDB.
  Incluye conexión, batch writes, índices y cierre de base de datos.
  """

  @db_path ~c"rocksdb_store.db"

  ## 📌 CONEXIÓN Y CIERRE 🚀
  def start_db do
    :rocksdb.open(@db_path, create_if_missing: true)
  end

  def close_db(db) do
    :rocksdb.close(db)
  end

  ## 📌 CRUD (Crear, Leer, Actualizar, Eliminar) 🔥
  def put(db, key, value) do
    :rocksdb.put(db, key, :erlang.term_to_binary(value), [])
  end

  def get(db, key) do
    case :rocksdb.get(db, key, []) do
      {:ok, raw_value} -> :erlang.binary_to_term(raw_value)
      :not_found -> nil
    end
  end

  def delete(db, key) do
    :rocksdb.delete(db, key)
  end

  ## 📌 CREACIÓN DE ÍNDICES 🔍
  def index_scan(db, prefix) do
    {:ok, iterator} = :rocksdb.iterator(db, [])

    items =
      Enum.map(:rocksdb.iterator_seek(iterator, prefix), fn {_key, value} ->
        Jason.decode!(value)
      end)

    :rocksdb.iterator_close(iterator)
    items
  end

  ## 📌 BATCH WRITES ⚡
  def batch_write(db, operations) do
    batch =
      Enum.reduce(operations, :rocksdb.write_batch(), fn
        {key, :delete, _}, batch ->
          :rocksdb.write_batch_delete(batch, key)

        {key, _value, nil}, batch ->
          batch

        {key, _value, erlvalue}, batch ->
          :rocksdb.write_batch_put(batch, key, erlvalue)
      end)

    :rocksdb.write(db, batch)
  end
end
