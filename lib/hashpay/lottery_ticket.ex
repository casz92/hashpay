defmodule Hashpay.LotteryTicket do
  @moduledoc """
  Estructura y funciones para los tickets de lotería de la blockchain de Hashpay.
  Un ticket de lotería contiene:
  - id: Identificador único del ticket
  - lottery_id: Identificador de la lotería a la que pertenece el ticket
  - account_id: Identificador de la cuenta que compró el ticket
  - number: Número del ticket
  - creation: Marca de tiempo de creación del ticket
  """

  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          lottery_id: String.t(),
          account_id: String.t(),
          number: String.t(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :lottery_id,
    :account_id,
    :number,
    creation: 0
  ]

  @prefix "lt_"
  @regex ~r/^lt_[a-zA-Z0-9]$/

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
    CREATE TABLE IF NOT EXISTS lottery_tickets (
      id text,
      lottery_id text,
      account_id text,
      number text,
      creation bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS lottery_tickets;"
    DB.execute(conn, statement)
  end

  def generate_id(lottery_id, account_id, number) do
    hash =
      [lottery_id, account_id, number]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(attrs) do
    lottery_id = attrs[:lottery_id]
    account_id = attrs[:account_id]
    number = attrs[:number]
    creation = attrs[:creation]

    %__MODULE__{
      id: generate_id(lottery_id, account_id, number),
      lottery_id: lottery_id,
      account_id: account_id,
      number: number,
      creation: creation
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO lottery_tickets (id, lottery_id, account_id, number, creation)
    VALUES (?, ?, ?, ?, ?);
    """

    insert_prepared = Xandra.prepare!(conn, insert_prepared)

    :persistent_term.put({:stmt, "lottery_tickets_insert"}, insert_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "lottery_tickets_insert"})
  end

  def batch_save(batch, ticket) do
    Xandra.Batch.add(batch, insert_prepared(), [
      ticket.id,
      ticket.lottery_id,
      ticket.account_id,
      ticket.number,
      ticket.creation
    ])
  end

  def get(conn, id) do
    statement = "SELECT * FROM lottery_tickets WHERE id = ?;"
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

  def delete_all(conn, lottery_id) do
    statement = "DELETE FROM lottery_tickets WHERE lottery_id = ?;"
    params = [{"text", lottery_id}]

    DB.execute(conn, statement, params)
  end

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      lottery_id: row["lottery_id"],
      account_id: row["account_id"],
      number: row["number"],
      creation: row["creation"]
    })
  end
end
