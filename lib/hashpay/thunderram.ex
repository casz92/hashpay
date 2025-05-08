defmodule ThunderRAM do
  @type table :: %{
          name: atom(),
          handle: reference(),
          ets: reference(),
          exp: boolean()
        }

  @type t :: %__MODULE__{
          name: atom(),
          batch: reference() | nil,
          db: reference() | nil,
          tables: %{String.t() => table()}
        }

  defstruct [:batch, :db, :name, :tables]
  @key :thunderram

  alias Hashpay.Cache

  def new(opts) do
    name = Keyword.get(opts, :name) || raise("`name` is required")
    filename = Keyword.get(opts, :filename) || raise("`filename` is required")
    modules = Keyword.get(opts, :modules, [])

    {db, cfs} =
      if File.exists?(filename) do
        cfs_opts = [
          {~c"default", []} | Enum.map(modules, &{&1.dbopts()[:handle], []})
        ]

        {:ok, db, [_default_cf | cfs]} =
          :rocksdb.open(filename, [create_if_missing: true], cfs_opts)

        {db, cfs}
      else
        try do
          {:ok, db, _default_cf} =
            :rocksdb.open(filename, [create_if_missing: true], [{~c"default", []}])

          cfs =
            Enum.map(modules, fn mod ->
              IO.inspect(mod)
              {:ok, handle} = :rocksdb.create_column_family(db, mod.dbopts()[:handle], [])
              handle
            end)

          {db, cfs}
        rescue
          e ->
            File.rm_rf!(filename)
            reraise e, __STACKTRACE__
        end
      end

    tables =
      Enum.zip(modules, cfs)
      |> Enum.map(fn {mod, handle} ->
        dbopts = mod.dbopts()
        name = dbopts[:name]
        ets = :ets.new(dbopts[:name], [:set, :public, read_concurrency: true])
        exp = dbopts[:exp]
        {name, %{handle: handle, ets: ets, exp: exp}}
      end)
      |> Map.new()

    tr = %__MODULE__{db: db, name: name, tables: tables}
    :persistent_term.put({@key, name}, tr)
    tr
  end

  def get_tr(name) do
    :persistent_term.get({@key, name})
  end

  def new_batch(tr = %ThunderRAM{}) do
    {:ok, batch} = :rocksdb.batch()
    %{tr | batch: batch}
  end

  def key_merge(keys) do
    Enum.join(keys, ":")
  end

  def key_merge(key1, key2) do
    <<key1::binary, ":", key2::binary>>
  end

  def exists?(%ThunderRAM{db: db, tables: tables}, name, key) do
    %{ets: ets, handle: handle, exp: exp} = Map.get(tables, name)

    case :ets.member(ets, key) do
      true ->
        true

      false ->
        case :rocksdb.get(db, handle, key, []) do
          :not_found ->
            false

          {:ok, value} ->
            result = binary_to_term(value)
            :ets.insert(ets, {key, result})
            if exp, do: Cache.put(name, key)
            true

          err ->
            err
        end
    end
  end

  def foreach(%ThunderRAM{db: db, tables: tables}, name, fun, opts \\ []) do
    %{handle: handle} = Map.get(tables, name)
    # init: <<>> | :last
    initial = Keyword.get(opts, :init, <<>>)
    # direction: :next | :prev
    direction = Keyword.get(opts, :direction, :next)

    {:ok, iter} = :rocksdb.iterator(db, handle, [])
    :rocksdb.iterator_move(iter, initial)

    try do
      do_foreach(iter, fun, direction)
    rescue
      e ->
        :rocksdb.iterator_close(iter)
        reraise e, __STACKTRACE__
    end
  end

  defp do_foreach(iter, fun, direction \\ :next) do
    case :rocksdb.iterator_move(iter, direction) do
      {:ok, key, value} ->
        fun.(key, binary_to_term(value))
        do_foreach(iter, fun)

      _ ->
        :rocksdb.iterator_close(iter)
    end
  end

  def while(%ThunderRAM{db: db, tables: tables}, name, fun, opts \\ []) do
    %{handle: handle} = Map.get(tables, name)
    initial = Keyword.get(opts, :init, <<>>)
    direction = Keyword.get(opts, :direction, :next)

    {:ok, iter} = :rocksdb.iterator(db, handle, [])
    :rocksdb.iterator_move(iter, initial)

    try do
      do_while(iter, fun, direction)
    rescue
      e ->
        :rocksdb.iterator_close(iter)
        reraise e, __STACKTRACE__
    end
  end

  defp do_while(iter, fun, direction \\ :next) do
    case :rocksdb.iterator_move(iter, direction) do
      {:ok, key, value} ->
        if fun.(key, binary_to_term(value)) == :next do
          do_while(iter, fun)
        else
          :rocksdb.iterator_close(iter)
        end

      _ ->
        :rocksdb.iterator_close(iter)
    end
  end

  def put(%ThunderRAM{batch: batch, tables: tables}, name, key, value) do
    case Map.get(tables, name) do
      %{handle: handle, ets: ets, exp: false} ->
        :ets.insert(ets, {key, value})
        :rocksdb.batch_put(batch, handle, key, term_to_binary(value))

      %{handle: handle, ets: ets} ->
        :ets.insert(ets, {key, value})
        :rocksdb.batch_put(batch, handle, key, term_to_binary(value))
        Cache.put(name, key)
    end
  end

  def get(tr = %ThunderRAM{tables: tables}, name, key) do
    %{ets: ets} = Map.get(tables, name)

    case :ets.lookup(ets, key) do
      [{^key, value}] -> {:ok, value}
      [] -> get_from_db(tr, name, key)
    end
  end

  def incr(%ThunderRAM{batch: batch, tables: tables}, name, key, {elem, amount}) do
    %{handle: handle, ets: ets} = Map.get(tables, name)
    result = :ets.update_counter(ets, key, {elem, amount}, {key, amount})
    :rocksdb.batch_put(batch, handle, key, term_to_binary(result))
  end

  def count(%ThunderRAM{db: db, tables: tables}, name) do
    %{handle: handle} = Map.get(tables, name)

    case :rocksdb.get_property(db, handle, "rocksdb.estimate-num-keys") do
      {:ok, count} -> String.to_integer(count)
      _ -> 0
    end
  end

  def delete(%ThunderRAM{batch: batch, tables: tables}, name, key) do
    %{handle: handle, ets: ets, exp: exp} = Map.get(tables, name)
    :ets.delete(ets, key)
    if exp, do: Cache.remove(key)
    :rocksdb.batch_delete(batch, handle, key)
  end

  defp get_from_db(%ThunderRAM{db: db, tables: tables}, name, key) do
    %{handle: handle, ets: ets, exp: exp} = Map.get(tables, name)

    case :rocksdb.get(db, handle, key, []) do
      :not_found ->
        nil

      {:ok, value} ->
        result = binary_to_term(value)
        if exp, do: Cache.put(name, key)
        :ets.insert(ets, {key, result})
        {:ok, result}

      err ->
        err
    end
  end

  def sync(tr = %ThunderRAM{batch: batch, db: db}) do
    if is_reference(batch) and :rocksdb.batch_count(batch) > 0 do
      :rocksdb.write_batch(db, batch, [])
      :rocksdb.release_batch(batch)
    end

    %{tr | batch: nil}
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

  def close(%ThunderRAM{batch: batch, db: db, tables: tables}) do
    if is_reference(batch) do
      :rocksdb.release_batch(batch)
    end

    for {_, %{ets: ets}} <- tables do
      :ets.delete(ets)
    end

    :rocksdb.close(db)
  end

  def destroy(%ThunderRAM{tables: tables, name: name}) do
    :rocksdb.destroy(String.to_charlist(name), [])

    for {_, %{ets: ets}} <- tables do
      :ets.delete(ets)
    end

    :persistent_term.erase({@key, name})
  end

  defp term_to_binary(term) do
    :erlang.term_to_binary(term)
  end

  defp binary_to_term(binary) do
    :erlang.binary_to_term(binary)
  end
end
