defmodule PostgrexBatch do
  @moduledoc """
  Módulo para manejar transacciones en Postgrex con conexión única (`pool_size: 1`).
  """
  require Logger

  defstruct conn: nil, ets: nil

  def new() do
    opts = Application.get_env(:hashpay, :postgres)
    # Mantener una única conexión activa
    opts = Keyword.put(opts, :pool_size, 1)
    {:ok, conn} = Postgrex.start_link(opts)

    %PostgrexBatch{
      conn: conn,
      ets: :ets.new(:prepared_statements, [:set, :public, read_concurrency: true])
    }
  end

  def add(batch = %PostgrexBatch{ets: ets}, key, params \\ []) do
    case :ets.lookup(ets, key) do
      [{_key, values, _prepared}] ->
        sql = add_row(values, params)
        :ets.update_element(ets, key, {2, sql})

      [] ->
        prepared = :persistent_term.get({:stmt, key})
        fist_row = add_row(params)
        :ets.insert(ets, {key, fist_row, prepared})
    end

    batch
  end

  @doc """
  example:
  prepared = "INSERT INTO example (id, value) VALUES {VALUES} ON CONFLICT DO NOTHING;"

  PostgrexBatch.new()
  |>  PostgrexBatch.add_prepared(:example, prepared, ["John", "john@example.com"])
  |>  PostgrexBatch.add_prepared(:example, prepared, ["John2", "john@example.com"])
  |> PostgrexBatch.run()
  """
  def add_prepared(batch = %PostgrexBatch{ets: ets}, key, prepared, params \\ []) do
    case :ets.lookup(ets, key) do
      [{_key, values, _prepared}] ->
        sql = add_row(values, params)
        :ets.update_element(ets, key, {2, sql})

      [] ->
        fist_row = add_row(params)
        :ets.insert(ets, {key, fist_row, prepared})
    end

    batch
  end

  @doc """
  UPDATE productos AS p
  SET precio = d.nuevo_precio
  FROM (VALUES
    (1, 100.00),
    (2, 150.00),
    (3, 200.00)
  ) AS d(id_producto, nuevo_precio)
  WHERE p.id = d.id_producto;

  UPDATE productos AS p
  SET precio = d.nuevo_precio
  FROM (:VALUES) AS d(id_producto, nuevo_precio)
  WHERE p.id = d.id_producto;

  DELETE FROM productos
  WHERE id IN :VALUES;
  """
  def run(batch = %PostgrexBatch{conn: conn, ets: ets}) do
    try do
      Postgrex.transaction(
        conn,
        fn conn ->
          :ets.foldl(
            fn {_key, values, prepared}, acc ->
              sql = String.replace(prepared, "{VALUES}", values)
              Logger.debug(sql)
              Postgrex.query!(conn, sql, [])
              acc
            end,
            0,
            ets
          )
        end,
        timeout: :infinity
      )
    rescue
      e in Postgrex.Error ->
        Logger.error("Error en la transacción: #{inspect(e)}")
        {:error, :database_error}
    catch
      :exit, _ -> {:error, :timeout}
    end

    close(batch)
  end

  defp close(%PostgrexBatch{conn: conn, ets: ets}) do
    if Process.alive?(conn) do
      GenServer.stop(conn)
    end

    :ets.delete(ets)
    :ok
  end

  defp add_row(params) do
    new_params = Enum.map(params, &param/1) |> Enum.join(", ")
    ["(", new_params, ")"] |> IO.iodata_to_binary()
  end

  defp add_row(sql, params) do
    new_params = Enum.map(params, &param/1) |> Enum.join(", ")
    [sql, ", (", new_params, ")"] |> IO.iodata_to_binary()
  end

  defp param(value) when is_binary(value) do
    case String.printable?(value) do
      true -> "'#{escape_text(value)}'"
      false -> bytea(value)
    end
  end

  defp param(value) when is_map(value) do
    jsonb(value)
  end

  defp param({:text, value}) do
    "'#{value}'"
  end

  defp param(value) do
    value
  end

  @compile {:inline, bytea: 1, escape_text: 1, jsonb: 1}
  defp bytea(binary_data) do
    ["\\x", Base.encode16(binary_data, case: :lower)] |> IO.iodata_to_binary()
  end

  defp escape_text(value) do
    value
    |> String.replace("'", "''")
    |> String.replace("\\", "\\\\")
  end

  defp jsonb(map) do
    Jason.encode!(map)
  end
end
