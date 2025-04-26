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

  def save(conn, %__MODULE__{} = variable) do
    statement = """
    INSERT INTO variables (key, value)
    VALUES (?, ?, ?);
    """

    params = [
      {"text", variable.key},
      {"blob", variable.value}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, variable}
      error -> error
    end
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

  def up do
    conn = DB.get_conn_with_retry()

    create_table(conn)
    save(conn, %Variable{key: "round_rewarded_base", value: 10})
    save(conn, %Variable{key: "round_rewarded_transactions", value: 0.1})
    save(conn, %Variable{key: "round_size_target", value: 0.05})
  end

  def down do
    conn = DB.get_conn_with_retry()
    drop_table(conn)
  end
end
