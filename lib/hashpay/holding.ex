defmodule Hashpay.Holding do
  @moduledoc """
  Estructura y funciones para los holdings de la blockchain de Hashpay.

  Un holding contiene:
  - id: Identificador único del holding
  - account_id: Identificador de la cuenta a la que pertenece el holding
  - currency_id: Identificador de la moneda del holding
  - amount: Cantidad de la moneda en el holding
  - apr: Tasa de rendimiento anual del holding
  - creation: Marca de tiempo de creación del holding
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour
  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          amount: non_neg_integer(),
          apr: number(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :amount,
    :apr,
    creation: 0
  ]

  @prefix "ho_"

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  @impl true
  def init(conn) do
    prepare_statements!(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS holdings (
        id text,
        account_id text,
        currency_id text,
        amount bigint,
        apr double,
        creation bigint,
        PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS holdings;"
    DB.execute(conn, statement)
  end

  def generate_id(account_id, currency_id, apr) do
    hash =
      [account_id, currency_id, Float.to_string(apr)]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(account_id, currency_id, amount, apr) do
    %__MODULE__{
      id: generate_id(account_id, currency_id, apr),
      account_id: account_id,
      currency_id: currency_id,
      amount: amount,
      apr: apr,
      creation: Hashpay.get_last_round_id()
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO holdings (id, account_id, currency_id, amount, apr, creation)
    VALUES (?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM holdings WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "holdings_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "holdings_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "holdings_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "holdings_delete"})
  end

  def batch_save(batch, holding) do
    Xandra.Batch.add(batch, insert_prepared(), [
      holding.id,
      holding.account_id,
      holding.currency_id,
      holding.amount,
      holding.apr,
      holding.creation
    ])
  end

  def batch_delete(batch, id) do
    Xandra.Batch.add(batch, delete_prepared(), [id])
  end

  def batch_update_fields(batch, map, id) do
    set_clause =
      Enum.map_join(map, ", ", fn {field, value} ->
        "#{field} = :#{value}"
      end)

    statement = """
    UPDATE holdings
    SET #{set_clause}
    WHERE id = :id;
    """

    Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  end

  def get(conn, id) do
    statement = "SELECT * FROM holdings WHERE id = ?;"
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
    statement = "SELECT * FROM holdings WHERE account_id = ?;"
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
      apr: row["apr"],
      creation: row["creation"]
    })
  end
end
