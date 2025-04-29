defmodule Hashpay.Paystream do
  @moduledoc """
  Estructura y funciones para los saldos de los paystreams de la blockchain de Hashpay.

  Un paystream contiene:
  - id: Identificador único del paystream
  - account_id: Identificador de la cuenta a la que pertenece el paystream
  - currency_id: Identificador de la moneda del paystream
  - merchant_id: Identificador del comercio al que pertenece el paystream
  - amount: Cantidad de la moneda en el paystream
  - last_paystream: Último paystream procesado
  - creation: Marca de tiempo de creación del paystream
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          account_id: String.t(),
          currency_id: String.t(),
          merchant_id: String.t(),
          amount: non_neg_integer(),
          last_paystream: non_neg_integer(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :account_id,
    :currency_id,
    :merchant_id,
    :amount,
    :last_paystream,
    creation: 0
  ]

  @prefix "pstr_"

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
    CREATE TABLE IF NOT EXISTS paystreams (
      id text,
      account_id text,
      currency_id text,
      merchant_id text,
      amount bigint,
      last_paystream bigint,
      creation bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS paystreams;"
    DB.execute(conn, statement)
  end

  def generate_id(account_id, currency_id, merchant_id) do
    hash =
      [account_id, currency_id, merchant_id]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 20)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(attrs) do
    account_id = attrs[:account_id]
    currency_id = attrs[:currency_id]
    merchant_id = attrs[:merchant_id]
    amount = attrs[:amount]
    last_paystream = attrs[:last_paystream]

    %__MODULE__{
      id: generate_id(account_id, currency_id, merchant_id),
      account_id: account_id,
      currency_id: currency_id,
      merchant_id: merchant_id,
      amount: amount,
      last_paystream: last_paystream,
      creation: Hashpay.get_last_round_id()
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO paystreams (id, account_id, currency_id, merchant_id, amount, last_paystream, creation)
    VALUES (?, ?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM paystreams WHERE id = ?;"

    incr_statement =
      "UPDATE paystreams SET amount = ?, last_paystream = ? WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)
    incr_prepared = Xandra.prepare!(conn, incr_statement)

    :persistent_term.put({:stmt, "paystreams_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "paystreams_delete"}, delete_prepared)
    :persistent_term.put({:stmt, "paystreams_incr"}, incr_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "paystreams_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "paystreams_delete"})
  end

  def incr_prepared do
    :persistent_term.get({:stmt, "paystreams_incr"})
  end

  def batch_save(batch, paystream) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", paystream.id},
      {"text", paystream.account_id},
      {"text", paystream.currency_id},
      {"text", paystream.merchant_id},
      {"bigint", paystream.amount},
      {"bigint", paystream.last_paystream},
      {"bigint", paystream.creation}
    ])
  end

  def batch_delete(batch, id) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", id}])
  end

  def batch_incr(batch, id, amount, last_paystream) do
    Xandra.Batch.add(batch, incr_prepared(), [
      {"bigint", amount},
      {"text", id},
      {"bigint", last_paystream}
    ])
  end

  def delete(conn, id) do
    statement = "DELETE FROM paystreams WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM paystreams WHERE id = ?;"
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
    statement = "SELECT * FROM paystreams WHERE account_id = ?;"
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
      merchant_id: row["merchant_id"],
      amount: row["amount"],
      last_paystream: row["last_paystream"],
      creation: row["creation"]
    })
  end
end
