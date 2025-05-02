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
  def init(conn) do
    create_ets_table()
    prepare_statements!(conn)
  end

  def create_ets_table do
    :ets.new(:balances, [:set, :public, :named_table])
  end

  def put(tuple, amount) do
    :ets.insert(:balances, {tuple, amount})
    Hits.hit(tuple, :balance)
  end

  @spec fetch(tuple()) :: {:ok, t()} | {:error, :not_found | :deleted}
  def fetch({id, _name} = tuple) do
    case :ets.lookup(:balances, id) do
      [{^tuple, :delete}] ->
        {:error, :deleted}

      [{^tuple, balance}] ->
        put(tuple, balance)
        {:ok, balance}

      [] ->
        {:error, :not_found}
    end
  end

  def fetch(conn, tuple) do
    case fetch(tuple) do
      {:ok, balance} ->
        Hits.hit(tuple, :balance)
        {:ok, balance}

      {:error, :not_found} ->
        get(conn, tuple)

      error ->
        error
    end
  end

  def fetch(conn, id, name) do
    fetch(conn, {id, name})
  end

  def get(conn, {id, name}) do
    statement = "SELECT amount FROM balances WHERE id = ? and name = ?;"
    params = [{"text", id}, {"text", name}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] ->
            amount = row["amount"]
            put({id, name}, amount)
            {:ok, amount}

          [] ->
            {:error, :not_found}

          _ ->
            {:error, :multiple_results}
        end

      error ->
        error
    end
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

  def batch_update(batch, account_id, currency_id, amount) do
    Xandra.Batch.add(batch, update_prepared(), [
      currency_id,
      amount,
      Hashpay.get_last_round_id(),
      account_id
    ])
  end

  def batch_save(batch, balance) do
    Xandra.Batch.add(batch, insert_prepared(), [
      balance.id,
      balance.name,
      balance.amount,
      balance.updated
    ])
  end

  def batch_sync(batch) do
    # Preparar consultas solo una vez
    update_prepared = update_prepared()
    delete_prepared = delete_prepared()
    now = Hashpay.get_last_round_id()
    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {{id, name} = tuple, :delete} ->
        remove(tuple)
        Xandra.Batch.add(batch, delete_prepared, [name, id])

      {{id, name}, balance} ->
        params = [
          balance,
          now,
          id,
          name
        ]

        Xandra.Batch.add(batch, update_prepared, params)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  def fetch_all do
    :ets.tab2list(:balances)
  end

  @spec incr(tuple(), integer()) :: any()
  def incr(tuple, amount) do
    :ets.update_counter(:balances, tuple, {2, amount}, {tuple, amount})
    Hits.hit(tuple, :balance)
  end

  @spec incr(Xandra.Batch.t(), String.t(), String.t(), integer()) :: any()
  def incr(batch, account_id, currency_id, amount) do
    incr({account_id, currency_id}, amount)
    batch_update(batch, account_id, currency_id, amount)
  end

  def delete(batch, id, name) do
    Xandra.Batch.add(batch, delete_prepared(), [name, id])
    remove({id, name})
  end

  @spec remove(tuple()) :: true
  def remove(tuple) do
    :ets.delete(:balances, tuple)
    Hits.remove(tuple)
  end

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      name: row["name"],
      amount: row["amount"],
      updated: row["updated"]
    })
  end
end
