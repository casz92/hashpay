defmodule Hashpay.Variable do
  @moduledoc """
  Estructura y funciones para las variables globales de la blockchain de Hashpay.

  Variables globales:
  - round_rewarded_base: Cantidad recompenza base de Hashpay por ronda
  - round_rewarded_transactions: Cantidad de Hashpay recompensada por transacción
  - round_size_target: Cantidad de penalización por tamaño de ronda
  """
  alias Hashpay.Variable
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  defstruct [:key, :value]

  def get_factor_a do
    :persistent_term.get({:var, "factor_a"}, 1)
  end

  def get_factor_b do
    :persistent_term.get({:var, "factor_b"}, 0)
  end

  def get_round_rewarded_base do
    :persistent_term.get({:var, "round_rewarded_base"}, 10)
  end

  def get_round_rewarded_transactions do
    :persistent_term.get({:var, "round_rewarded_transactions"}, 0.1)
  end

  def get_round_size_target do
    :persistent_term.get({:var, "round_size_target"}, 0.05)
  end

  def create_table(conn, keyspace \\ nil) do
    if keyspace do
      DB.use_keyspace(conn, keyspace)
    end

    statement = """
    CREATE TABLE IF NOT EXISTS variables (
      key text,
      value blob,
      PRIMARY KEY (key)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn, keyspace \\ nil) do
    if keyspace do
      DB.use_keyspace(conn, keyspace)
    end

    statement = "DROP TABLE IF EXISTS variables;"
    DB.execute(conn, statement)
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO variables (key, value)
    VALUES (?, ?);
    """

    delete_statement = "DELETE FROM variables WHERE key = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "variables_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "variables_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "variables_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "variables_delete"})
  end

  def batch_save(batch, variable) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", variable.key},
      {"blob", variable.value |> :erlang.term_to_binary()}
    ])
  end

  def batch_delete(batch, key) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", key}])
  end

  def load_all(conn) do
    statement = "SELECT key, value FROM variables;"

    case DB.execute(conn, statement) do
      {:ok, %Xandra.Page{} = page} ->
        Enum.each(page, fn row ->
          key = row["key"]
          value = row["value"] |> :erlang.binary_to_term()
          :persistent_term.put({:var, key}, value)
        end)

      error ->
        error
    end
  end

  def up(conn) do
    create_table(conn)

    Xandra.Batch.new()
    |> batch_save(%Variable{key: "round_rewarded_base", value: 10})
    |> batch_save(%Variable{key: "round_rewarded_transactions", value: 0.1})
    |> batch_save(%Variable{key: "round_size_target", value: 0.05})
    |> Xandra.execute(conn)
  end

  def down(conn) do
    drop_table(conn)
  end
end
