defmodule Hashpay.Plan do
  @moduledoc """
  Estructura y funciones para los planes de pago de la blockchain de Hashpay.
  Un plan de pago contiene:
  - id: Identificador único del plan
  - merchant_id: Identificador del comercio al que pertenece el plan
  - currency_id: Identificador de la moneda del plan
  - amount: Cantidad de la moneda en el plan
  - status: Estado del plan (0: activo, 1: cancelado, 2: vencido)
  - period: Periodo de tiempo del plan (en días)
  - due_date: Fecha limite de vencimiento del plan (en timestamp)
  - description: Descripción del plan
  - creation: Marca de tiempo de creación del plan
  """

  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour
  @type t :: %__MODULE__{
          id: String.t(),
          merchant_id: String.t(),
          currency_id: String.t(),
          amount: non_neg_integer(),
          status: non_neg_integer(),
          period: non_neg_integer(),
          due_date: non_neg_integer(),
          description: String.t(),
          creation: non_neg_integer()
        }

  defstruct [
    :id,
    :merchant_id,
    :currency_id,
    :amount,
    :period,
    :due_date,
    :description,
    status: 0,
    creation: 0
  ]

  @prefix "plan_"

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
    CREATE TABLE IF NOT EXISTS plans (
      id text,
      merchant_id text,
      currency_id text,
      amount bigint,
      status int,
      period int,
      due_date bigint,
      description text,
      creation bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS plans;"
    DB.execute(conn, statement)
  end

  def generate_id(merchant_id, currency_id, amount, period) do
    hash =
      [merchant_id, currency_id, Integer.to_string(amount), Integer.to_string(period)]
      |> Enum.join("|")
      |> :crypto.hash(:sha256)
      |> :binary.part(0, 16)
      |> Base62.encode()

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(attrs) do
    merchant_id = attrs[:merchant_id]
    currency_id = attrs[:currency_id]
    amount = attrs[:amount]
    period = attrs[:period]

    %__MODULE__{
      id: generate_id(merchant_id, currency_id, amount, period),
      merchant_id: merchant_id,
      currency_id: currency_id,
      amount: amount,
      period: period,
      due_date: attrs[:due_date],
      description: attrs[:description],
      creation: Hashpay.get_last_round_id()
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO plans (id, merchant_id, currency_id, amount, status, period, due_date, description, creation)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM plans WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "plans_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "plans_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "plans_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "plans_delete"})
  end

  def batch_save(batch, plan) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", plan.id},
      {"text", plan.merchant_id},
      {"text", plan.currency_id},
      {"bigint", plan.amount},
      {"int", plan.status},
      {"int", plan.period},
      {"bigint", plan.due_date},
      {"text", plan.description},
      {"bigint", plan.creation}
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
    UPDATE plans
    SET #{set_clause}
    WHERE id = :id;
    """

    Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  end

  def delete(conn, id) do
    statement = "DELETE FROM plans WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM plans WHERE id = ?;"
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

  def get_by_merchant(conn, merchant_id) do
    statement = "SELECT * FROM plans WHERE merchant_id = ?;"
    params = [{"text", merchant_id}]

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
      merchant_id: row["merchant_id"],
      currency_id: row["currency_id"],
      amount: row["amount"],
      status: row["status"],
      period: row["period"],
      due_date: row["due_date"],
      description: row["description"],
      creation: row["creation"]
    })
  end
end
