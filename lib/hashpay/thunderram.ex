defmodule ThunderRAM do
  @type t :: %__MODULE__{
          name: atom(),
          batch: reference() | nil,
          db: reference() | nil,
          ets: reference(),
          exp: boolean(),
          cfs: map() | nil
        }

  defstruct [:batch, :db, :ets, :name, :exp, :cfs]
  @key :thunderram

  alias Hashpay.Cache

  def new(opts) do
    name = Keyword.get(opts, :name) || raise("`name` is required")
    dbname = Keyword.get(opts, :db) || raise("`db` is required")
    column_families = Keyword.get(opts, :cfs, [])
    expiration = Keyword.get(opts, :exp, true)
    tid = :ets.new(name, [:set, :public, read_concurrency: true, write_concurrency: true])

    {db, cfs} =
      if File.exists?(dbname) do
        cfs_opts = [
          {~c"default", []} | Enum.map(column_families, &{String.to_charlist(&1), []})
        ]

        {:ok, db, cfs} = :rocksdb.open(dbname, [create_if_missing: true], cfs_opts)

        cfs =
          Enum.zip(column_families, cfs)
          |> Enum.map(fn {cf, handle} -> {String.to_atom(cf), handle} end)
          |> Map.new()

        {db, cfs}
      else
        {:ok, db} = :rocksdb.open(dbname, create_if_missing: true)

        cfs =
          for cf <- column_families do
            {:ok, cf_handle} = :rocksdb.create_column_family(db, String.to_charlist(cf), [])
            {String.to_atom(cf), cf_handle}
          end
          |> Map.new()

        {db, cfs}
      end

    tr = %__MODULE__{db: db, ets: tid, name: name, exp: expiration, cfs: cfs}
    :persistent_term.put({@key, name}, tr)
    tr
  end

  def new_batch(%ThunderRAM{db: db} = tr) do
    {:ok, batch} = :rocksdb.batch()
    %{tr | batch: batch}
  end

  def key_merge(keys) do
    Enum.join(keys, ":")
  end

  def key_merge(key1, key2) do
    <<key1::binary, ":", key2::binary>>
  end

  def put(%ThunderRAM{batch: batch, ets: ets, cfs: cfs}, name, key, value) do
    cf = Map.get(cfs, name)
    :ets.insert(ets, {key, value})
    :rocksdb.batch_put(batch, cf, key, term_to_binary(value))
  end

  def get(tr = %ThunderRAM{db: db, ets: ets, cfs: cfs}, name, key) do
    case :ets.lookup(ets, key) do
      [{^key, value}] -> value
      [] -> get_from_db(tr, name, key)
    end
  end

  def counter(%ThunderRAM{batch: batch, ets: ets, cfs: cfs}, name, key, {elem, amount}) do
    cf = Map.get(cfs, name)
    result = :ets.update_counter(ets, key, {elem, amount}, {key, amount})
    :rocksdb.batch_put(batch, cf, key, term_to_binary(result))
  end

  def count(%ThunderRAM{db: db, cfs: cfs}, name) do
    cf = Map.get(cfs, name)
    case :rocksdb.get_property(db, cf, "rocksdb.estimate-num-keys") do
      {:ok, count} -> String.to_integer(count)
      _ -> 0
    end
  end

  def delete(%ThunderRAM{batch: batch, ets: ets, cfs: cfs, exp: exp}, name, key) do
    cf = Map.get(cfs, name)
    :ets.delete(ets, key)
    if exp, do: Cache.remove(name, key)
    :rocksdb.batch_delete(batch, cf, key)
  end

  defp get_from_db(%ThunderRAM{db: db, ets: ets, exp: exp, cfs: cfs}, name, key) do
    cf = Map.get(cfs, name)

    case :rocksdb.get(db, cf, key, []) do
      :not_found ->
        nil

      {:ok, value} ->
        result = binary_to_term(value)
        if exp, do: Cache.put(name, key)
        :ets.insert(ets, {key, result})
        result

      err ->
        err
    end
  end

  def sync(tr = %ThunderRAM{batch: batch, db: db, ets: ets}) do
    if is_reference(batch) and :rocksdb.batch_count(batch) > 0 do
      key = :ets.first(ets)
      iterate_ets(key, ets)

      # Escribir el batch en RocksDB y liberarlo
      :rocksdb.write_batch(db, batch, [])
      :rocksdb.release_batch(batch)
    end

    %{tr | batch: nil}
  end

  # Detener cuando llega al final
  defp iterate_ets(:"$end_of_table", _ets), do: :ok

  defp iterate_ets(key, ets) do
    iterate_ets(:ets.next(ets, key), ets)
  end

  def savepoint(%ThunderRAM{batch: batch}) do
    :rocksdb.batch_savepoint(batch)
  end

  @spec snapshot(t()) :: no_return()
  def snapshot(%ThunderRAM{db: db}) do
    :rocksdb.snapshot(db)
  end

  def release_snapshot(snapshot) do
    :rocksdb.release_snapshot(snapshot)
  end

  @spec restore(t(), charlist()) :: :ok | {:error, term()}
  def restore(%ThunderRAM{db: db}, target) do
    case :rocksdb.open_backup_engine(target) do
      {:ok, ref} ->
        case :rocksdb.restore_db_from_latest_backup(db, target) do
          :ok ->
            :rocksdb.close_backup_engine(ref)

          {:error, _reason} = err ->
            err
        end

      {:error, _reason} = err ->
        err
    end
  end

  @spec backup(t(), charlist()) :: :ok | {:error, term()}
  def backup(%ThunderRAM{db: db}, target) do
    case :rocksdb.open_backup_engine(target) do
      {:ok, ref} ->
        case :rocksdb.create_new_backup(ref, db) do
          :ok ->
            :rocksdb.close_backup_engine(ref)

          {:error, _reason} = err ->
            err
        end

      {:error, _reason} = err ->
        err
    end
  end

  def close(%ThunderRAM{batch: batch, db: db, ets: ets}) do
    if is_reference(batch) do
      :rocksdb.release_batch(batch)
    end

    :ets.delete(ets)
    :rocksdb.close(db)
  end

  def destroy(%ThunderRAM{db: db, ets: ets, name: name}) do
    :rocksdb.destroy(String.to_charlist(name), [])
    :ets.delete(ets)
    :persistent_term.erase({@key, name})
  end

  defp term_to_binary(term) do
    :erlang.term_to_binary(term)
  end

  defp binary_to_term(binary) do
    :erlang.binary_to_term(binary)
  end
end
