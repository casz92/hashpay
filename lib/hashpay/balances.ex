defmodule Hashpay.Balance do
  alias Hashpay.DB
  alias Hashpay.Hits
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          balances: map(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    balances: %{},
    creation: 0,
    updated: 0
  ]

  @default_currency Application.compile_env(:hashpay, :default_currency)

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
      balances map<text, bigint>,
      creation bigint,
      updated bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def new(account_id, amount \\ 0) do
    %__MODULE__{
      id: account_id,
      balances: %{@default_currency => amount},
      creation: Hashpay.get_last_round_id(),
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

  def get(conn, {id, name}) do
    statement = "SELECT balances[?] as amount FROM balances WHERE id = ?;"
    params = [{"text", name}, {"text", id}]

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
    INSERT INTO balances (id, balances, creation, updated)
    VALUES (?, ?, ?, ?);
    """

    update_statement = """
    UPDATE balances
    SET balances[?] = ?, updated = ?
    WHERE id = ?;
    """

    delete_statement = """
    UPDATE balances
    SET balances[?] = null
    WHERE id = ?;
    """

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    update_prepared = Xandra.prepare!(conn, update_statement)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

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

  def batch_save(batch, balance) do
    Xandra.Batch.add(batch, insert_prepared(), [
      balance.id,
      balance.balances,
      balance.creation,
      balance.updated
    ])
  end

  def batch_sync(batch) do
    # Preparar consultas solo una vez
    update_prepared = update_prepared()
    delete_prepared = delete_prepared()

    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {{id, name} = tuple, :delete} ->
        remove(tuple)
        Xandra.Batch.add(batch, delete_prepared, [name, id])

      {{id, name}, balance} ->
        params = [
          name,
          balance,
          Hashpay.get_last_round_id(),
          id
        ]

        Xandra.Batch.add(batch, update_prepared, params)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  def fetch_all do
    :ets.tab2list(:balances)
  end

  @spec incr(tuple(), integer()) :: integer()
  def incr(tuple, amount) do
    result = :ets.update_counter(:balances, tuple, {2, amount}, {tuple, 0 + amount})
    Hits.hit(tuple, :balance)
    result
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
      balances: row["balances"],
      creation: row["creation"],
      updated: row["updated"]
    })
  end
end
