defmodule Hashpay.Balance do
  alias Hashpay.DB
  alias Hashpay.Hits
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          amount: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :amount,
    updated: 0
  ]

  @trdb :balances

  # @compile {:inline, [put: 1, fetch: 1, delete: 1]}

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS balances (
      id text,
      name text,
      amount decimal,
      updated bigint,
      PRIMARY KEY (id, name)
    ) WITH transactions = {'enabled': 'true'};
    """

    DB.execute!(conn, statement)
  end

  def new(account_id, name, amount \\ 0) do
    %__MODULE__{
      id: account_id,
      name: name,
      amount: amount,
      updated: Hashpay.get_last_round_id()
    }
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS balances;"
    DB.execute(conn, statement)
  end

  @impl true
  def init(_conn) do
    :ok
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO balances (id, name, amount, updated)
    VALUES (?, ?, ?, ?);
    """

    update_statement = """
    UPDATE balances
    SET amount = amount + ?, updated = ?
    WHERE id = ? and name = ?;
    """

    delete_statement = """
    DELETE FROM balances WHERE id = ?;
    """

    insert_prepared = DB.prepare!(conn, insert_prepared)
    update_prepared = DB.prepare!(conn, update_statement)
    delete_prepared = DB.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "balances_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "balances_update"}, update_prepared)
    :persistent_term.put({:stmt, "balances_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "balances_insert"})
  end

  def update_prepared do
    :persistent_term.get({:stmt, "balances_update"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "balances_delete"})
  end



  # def row_to_struct(row) do
  #   struct!(__MODULE__, %{
  #     id: row["id"],
  #     name: row["name"],
  #     amount: row["amount"],
  #     updated: row["updated"]
  #   })
  # end
end
