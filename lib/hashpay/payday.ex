defmodule Hashpay.Payday do
  @moduledoc """
  Estructura y funciones para los saldos de los paydays de la blockchain de Hashpay.

  Un payday contiene:
  - id: Identificador único del payday
  - account_id: Identificador de la cuenta a la que pertenece el payday
  - currency_id: Identificador de la moneda del payday
  - amount: Cantidad de la moneda en el payday
  - last_payday: Último payday procesado
  - last_stream: Último stream procesado
  - creation: Marca de tiempo de creación del payday
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          amount: non_neg_integer(),
          last_payday: non_neg_integer(),
          last_stream: non_neg_integer(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :amount,
    :last_payday,
    :last_stream,
    creation: 0
  ]

  @prefix "pdy_"

  @impl true
  def up do
    conn = DB.get_conn_with_retry()
    create_table(conn)
  end

  @impl true
  def down do
    conn = DB.get_conn_with_retry()
    drop_table(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS paydays (
      id text,
      account_id text,
      currency_id text,
      amount bigint,
      last_payday bigint,
      last_stream bigint,
      creation bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS paydays;"
    DB.execute(conn, statement)
  end

  def generate_id(account_id, currency_id) do
    hash =
      [account_id, currency_id]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(attrs) do
    account_id = attrs[:account_id]
    currency_id = attrs[:currency_id]
    amount = attrs[:amount]
    last_payday = attrs[:last_payday]
    last_stream = attrs[:last_stream]

    %__MODULE__{
      id: generate_id(account_id, currency_id),
      account_id: account_id,
      currency_id: currency_id,
      amount: amount,
      last_payday: last_payday,
      last_stream: last_stream,
      creation: Hashpay.get_last_round_id()
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO paydays (id, account_id, currency_id, amount, last_payday, last_stream, creation)
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM paydays WHERE id = ?;"

    incr_prepared =
      Xandra.prepare!(
        conn,
        "UPDATE paydays SET amount = amount + ?, last_stream = ? WHERE id = ?;"
      )

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)
    incr_prepared = Xandra.prepare!(conn, incr_prepared)

    :persistent_term.put({:stmt, "paydays_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "paydays_delete"}, delete_prepared)
    :persistent_term.put({:stmt, "paydays_incr"}, incr_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "paydays_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "paydays_delete"})
  end

  def incr_prepared do
    :persistent_term.get({:stmt, "paydays_incr"})
  end

  def batch_save(batch, payday) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", payday.id},
      {"text", payday.account_id},
      {"text", payday.currency_id},
      {"bigint", payday.amount},
      {"bigint", payday.last_payday},
      {"bigint", payday.last_stream},
      {"bigint", payday.creation}
    ])
  end

  def batch_delete(batch, id) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", id}])
  end

  def batch_update_fields(batch, map, id) do
    set_clause =
      Enum.map_join(map, ", ", fn {field, value} ->
        "#{field} = :#{value}"
      end)

    statement = """
    UPDATE paydays
    SET #{set_clause}
    WHERE id = :id;
    """

    Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  end

  def delete(conn, id) do
    statement = "DELETE FROM paydays WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM paydays WHERE id = ?;"
    params = [{"text", id}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> {:ok, row_to_struct(row)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  def get_by_account(conn, account_id) do
    statement = "SELECT * FROM paydays WHERE account_id = ?;"
    params = [{"text", account_id}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        structs = Enum.map(page, &row_to_struct/1)
        {:ok, structs}

      error ->
        error
    end
  end

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      account_id: row["account_id"],
      currency_id: row["currency_id"],
      amount: row["amount"],
      last_payday: row["last_payday"],
      last_stream: row["last_stream"],
      creation: row["creation"]
    })
  end
end
