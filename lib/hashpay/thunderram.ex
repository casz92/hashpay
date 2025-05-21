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
  @stat_count "$count"

  @open_options [
    create_if_missing: true,
    merge_operator: :erlang_merge_operator
  ]

  alias Hashpay.Cache

  @compile {:inline,
            [
              exists?: 3,
              get: 3,
              put: 4,
              incr: 4,
              delete: 3,
              total: 2,
              binary_to_term: 1,
              term_to_binary: 1
            ]}

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
          :rocksdb.open(filename, @open_options, cfs_opts)

        {db, cfs}
      else
        try do
          {:ok, db, _default_cf} =
            :rocksdb.open(filename, @open_options, [{~c"default", []}])

          cfs =
            Enum.map(modules, fn mod ->
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
        ets_type = Keyword.get(dbopts, :ets_type, :set)
        ets = :ets.new(dbopts[:name], [ets_type, :public, read_concurrency: true])
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

  @doc """
  Usage:
    tr = ThunderRAM.get_tr(:blockchain)
    opts = [
      init: {:seek, "ac_"},
      direction: :next
    ]
    ThunderRAM.foreach(tr, :accounts, fn key, value ->
      # do something with key and value
    end, opts)
  """
  def foreach(%ThunderRAM{db: db, tables: tables}, name, fun, opts \\ []) do
    %{handle: handle} = Map.get(tables, name)
    # init: <<>> | :last
    initial = Keyword.get(opts, :init, <<>>)
    # direction: :next | :prev
    direction = Keyword.get(opts, :direction, :next)

    {:ok, iter} = :rocksdb.iterator(db, handle, [])

    try do
      case :rocksdb.iterator_move(iter, initial) do
        {:ok, key, value} ->
          fun.(key, binary_to_term(value))
          do_foreach(iter, fun, direction)

        _ ->
          :rocksdb.iterator_close(iter)
      end
    rescue
      e ->
        :rocksdb.iterator_close(iter)
        reraise e, __STACKTRACE__
    end
  end

  defp do_foreach(iter, fun, direction) do
    case :rocksdb.iterator_move(iter, direction) do
      {:ok, key, value} ->
        fun.(key, binary_to_term(value))
        do_foreach(iter, fun, direction)

      _ ->
        :rocksdb.iterator_close(iter)
    end
  end

  def while(%ThunderRAM{db: db, tables: tables}, name, fun, opts \\ []) do
    %{handle: handle} = Map.get(tables, name)
    initial = Keyword.get(opts, :init, <<>>)
    direction = Keyword.get(opts, :direction, :next)

    {:ok, iter} = :rocksdb.iterator(db, handle, [])

    try do
      case :rocksdb.iterator_move(iter, initial) do
        {:ok, key, value} ->
          if fun.(key, binary_to_term(value)) == :next do
            do_while(iter, fun, direction)
          else
            :rocksdb.iterator_close(iter)
          end

        _ ->
          :rocksdb.iterator_close(iter)
      end
    rescue
      e ->
        :rocksdb.iterator_close(iter)
        reraise e, __STACKTRACE__
    end
  end

  defp do_while(iter, fun, direction) do
    case :rocksdb.iterator_move(iter, direction) do
      {:ok, key, value} ->
        if fun.(key, binary_to_term(value)) == :next do
          do_while(iter, fun, direction)
        else
          :rocksdb.iterator_close(iter)
        end

      _ ->
        :rocksdb.iterator_close(iter)
    end
  end

  def fold(%ThunderRAM{db: db, tables: tables}, name, fun, acc, opts \\ []) do
    %{handle: handle} = Map.get(tables, name)
    initial = Keyword.get(opts, :init, <<>>)
    direction = Keyword.get(opts, :direction, :next)

    {:ok, iter} = :rocksdb.iterator(db, handle, [])

    try do
      case :rocksdb.iterator_move(iter, initial) do
        {:ok, key, value} ->
          acc = fun.(key, binary_to_term(value), acc)
          do_fold(iter, fun, acc, direction)

        _ ->
          :rocksdb.iterator_close(iter)
          acc
      end
    rescue
      e ->
        :rocksdb.iterator_close(iter)
        reraise e, __STACKTRACE__
    end
  end

  defp do_fold(iter, fun, acc, direction) do
    case :rocksdb.iterator_move(iter, direction) do
      {:ok, key, value} ->
        acc = fun.(key, binary_to_term(value), acc)
        do_fold(iter, fun, acc, direction)

      _ ->
        :rocksdb.iterator_close(iter)
        acc
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

  def put_db(%ThunderRAM{batch: batch, tables: tables}, name, key, value) do
    %{handle: handle} = Map.get(tables, name)
    :rocksdb.batch_put(batch, handle, key, term_to_binary(value))
  end

  def get(tr = %ThunderRAM{tables: tables}, name, key) do
    %{ets: ets} = Map.get(tables, name)

    case :ets.lookup(ets, key) do
      [{^key, value}] -> {:ok, value}
      [] -> get_from_db(tr, name, key)
    end
  end

  def slot(%ThunderRAM{tables: tables}, name, position) do
    %{ets: ets} = Map.get(tables, name)
    :ets.slot(ets, position)
  end

  defp incr_from_db(tr, ets, name, key) do
    if not :ets.member(ets, key) do
      case get_from_db(tr, name, key) do
        {:ok, value} -> :ets.insert(ets, {key, value})
        _ -> false
      end
    end
  end

  def incr(tr = %ThunderRAM{batch: batch, tables: tables}, name, key, {elem, amount}) do
    %{handle: handle, ets: ets} = Map.get(tables, name)

    incr_from_db(tr, ets, name, key)

    result = :ets.update_counter(ets, key, {elem, amount}, {key, 0})
    :rocksdb.batch_put(batch, handle, key, term_to_binary(result))

    # :rocksdb.batch_merge(batch, key, term_to_binary({:int_add, amount}), [])
    result
  end

  def incr_non_zero(tr = %ThunderRAM{batch: batch, tables: tables}, name, key, {elem, neg_amount}) do
    %{handle: handle, ets: ets} = Map.get(tables, name)

    incr_from_db(tr, ets, name, key)

    case :ets.update_counter(ets, key, {elem, neg_amount}, {key, 0}) do
      result when 0 > result ->
        :ets.update_counter(ets, key, {elem, abs(neg_amount)})
        {:error, "Insufficient balance"}

      result ->
        :rocksdb.batch_put(batch, handle, key, term_to_binary(result))
        # :rocksdb.batch_merge(batch, handle, key, term_to_binary({:int_add, neg_amount}))
        {:ok, result}
    end
  end

  def incr_limit(tr = %ThunderRAM{batch: batch, tables: tables}, name, key, {elem, amount}, limit) do
    %{handle: handle, ets: ets} = Map.get(tables, name)

    incr_from_db(tr, ets, name, key)

    case :ets.update_counter(ets, key, {elem, amount}, {key, 0}) do
      result when limit != 0 and result > limit ->
        :ets.update_counter(ets, key, {elem, -amount})
        {:error, "Limit exceeded"}

      result ->
        :rocksdb.batch_put(batch, handle, key, term_to_binary(result))
        # :rocksdb.batch_merge(batch, handle, key, term_to_binary({:int_add, amount}))
        {:ok, result}
    end
  end

  def total(tr, name) do
    case get(tr, name, @stat_count) do
      {:ok, count} -> count
      _ -> 0
    end
  end

  def count_one(tr, name) do
    incr(tr, name, @stat_count, {2, 1})
  end

  def discount_one(tr, name) do
    incr(tr, name, @stat_count, {2, -1})
  end

  def ets_total(%ThunderRAM{tables: tables}, name) do
    %{ets: ets} = Map.get(tables, name)
    :ets.info(ets, :size)
  end

  def delete(%ThunderRAM{batch: batch, tables: tables}, name, key) do
    %{handle: handle, ets: ets, exp: exp} = Map.get(tables, name)
    :ets.delete(ets, key)
    if exp, do: Cache.remove(key)
    :rocksdb.batch_delete(batch, handle, key)
  end

  def delete_db(%ThunderRAM{batch: batch, tables: tables}, name, key) do
    %{handle: handle} = Map.get(tables, name)
    :rocksdb.batch_delete(batch, handle, key)
  end

  def get_from_db(%ThunderRAM{db: db, tables: tables}, name, key) do
    %{handle: handle, ets: ets, exp: exp} = Map.get(tables, name)

    case :rocksdb.get(db, handle, key, []) do
      :not_found ->
        {:error, :not_found}

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

  def load_all(tr = %ThunderRAM{tables: tables}, name) do
    %{ets: ets} = Map.get(tables, name)

    foreach(tr, name, fn key, value ->
      :ets.insert(ets, {key, value})
    end)
  end

  def savepoint(%ThunderRAM{batch: batch}) do
    :rocksdb.batch_savepoint(batch)
  end

  @spec snapshot(t()) :: no_return()
  def snapshot(%ThunderRAM{db: db}) do
    :rocksdb.snapshot(db)
  end

  @spec release_snapshot(reference()) :: no_return()
  def release_snapshot(snapshot) do
    :rocksdb.release_snapshot(snapshot)
  end

  @spec restore(charlist(), charlist()) :: :ok | {:error, term()}
  def restore(target, output) do
    zip_file = IO.iodata_to_binary([target, ".zip"]) |> String.to_charlist()

    case ZipUtil.extract(zip_file, target) do
      {:ok, _} ->
        case :rocksdb.open_backup_engine(target) do
          {:ok, ref} ->
            case :rocksdb.restore_db_from_latest_backup(ref, output) do
              :ok ->
                :rocksdb.close_backup_engine(ref)

              {:error, _reason} = err ->
                err
            end

          {:error, _reason} = err ->
            err
        end

      {:error, _reason} = err ->
        err
    end
  end

  @spec backup(t(), charlist() | binary()) :: :ok | {:error, term()}
  def backup(%ThunderRAM{db: db}, target) do
    case :rocksdb.open_backup_engine(target) do
      {:ok, ref} ->
        case :rocksdb.create_new_backup(ref, db) do
          :ok ->
            :rocksdb.close_backup_engine(ref)
            zip_file = IO.iodata_to_binary([target, ".zip"])

            case ZipUtil.compress_folder(target, zip_file) do
              {:ok, _} ->
                File.rm_rf!(target)
                :ok

              {:error, _reason} = err ->
                err
            end

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
