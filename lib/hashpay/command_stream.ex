defmodule CommandStream do
  defstruct [:tid, :type, :counter]

  def new do
    counter = :counters.new(1, write_concurrency: true)

    %CommandStream{
      tid: :ets.new(:CommandStream, [:ordered_set, :public]),
      type: :ordered_set,
      counter: counter
    }
  end

  def add(stream = %CommandStream{counter: counter, tid: tid}, ctx, _thread) do
    ix = :counters.add(counter, 0, 1)
    :ets.insert(tid, {ix, ctx, ctx.size})
    stream
  end

  # def add(stream = %CommandStream{tid: tid}, ctx) do
  #   :ets.insert(tid, {ctx.command.hash, ctx})
  #   stream
  # end

  def run(%CommandStream{tid: tid}) do
    :ets.foldl(
      fn {_id, context, _size}, _acc ->
        Hashpay.Command.run(context)
      end,
      0,
      tid
    )

    :ets.delete(tid)
  end
end

defimpl Enumerable, for: CommandStream do
  def count(%CommandStream{tid: table}), do: :ets.info(table, :size)

  def member?(%CommandStream{tid: table}, value) do
    :ets.lookup(table, elem(value, 0)) != []
  end

  def reduce(%CommandStream{tid: table}, acc, fun) do
    :ets.foldl(fn entry, acc -> fun.(entry, acc) end, acc, table)
  end

  def filter(%CommandStream{tid: table}, fun) do
    :ets.foldl(fn entry, acc -> if fun.(entry), do: [entry | acc], else: acc end, [], table)
  end

  def slice(%CommandStream{tid: table, type: :ordened_set}) do
    size = :ets.info(table, :size)

    # Función para obtener la clave de un slot específico
    fetch_fun = fn start, length ->
      keys =
        Enum.reduce_while(start..(start + length - 1), [], fn i, acc ->
          case :ets.slot(table, i) do
            :"$end_of_table" -> {:halt, acc}
            key -> {:cont, [key | acc]}
          end
        end)

      {:ok, keys}
    end

    {:ok, size, fetch_fun}
  end

  def slice(_), do: {:error, __MODULE__}
end
