defmodule Hashpay.Account do
  alias Hashpay.Hits
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          pubkey: binary,
          channel: String.t(),
          sig_type: non_neg_integer()
        }

  defstruct [
    :id,
    :pubkey,
    :channel,
    :sig_type
  ]

  def new(attrs) do
    %__MODULE__{
      id: attrs[:id],
      pubkey: attrs[:pubkey],
      channel: attrs[:channel],
      sig_type: attrs[:sig_type]
    }
  end

  def up do
    conn = DB.get_conn_with_retry()
    create_table(conn)
  end

  def down do
    conn = DB.get_conn_with_retry()
    drop_table(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS accounts (
      id text,
      pubkey blob,
      channel text,
      sig_type int,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS accounts;"
    DB.execute(conn, statement)
  end

  def create_ets_table do
    :ets.new(:accounts, [:set, :public, :named_table])
  end

  def save(conn, %__MODULE__{} = account) do
    statement = """
    INSERT INTO accounts (id, pubkey, channel, sig_type)
    VALUES (?, ?, ?, ?);
    """

    params = [
      {"text", account.id},
      {"blob", account.pubkey},
      {"text", account.channel},
      {"int", account.sig_type}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} ->
        Hits.hit_write(account.id, :account)
        {:ok, account}

      error ->
        error
    end
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO accounts (id, pubkey, channel, sig_type)
    VALUES (?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM accounts WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "accounts_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "accounts_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "accounts_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "accounts_delete"})
  end

  def batch_sync(batch) do
    insert_prepared = insert_prepared()
    delete_prepared = delete_prepared()

    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {id, :delete} ->
        remove(id)
        Xandra.Batch.add(batch, delete_prepared, [{"text", id}])

      {_id, account} ->
        params = [
          {"blob", account.pubkey},
          {"text", account.channel},
          {"int", account.sig_type},
          {"text", account.id}
        ]

        Xandra.Batch.add(batch, insert_prepared, params)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  def fetch(id) do
    case :ets.lookup(:accounts, id) do
      [{^id, account}] ->
        Hits.hit_read(account.id, :account)
        {:ok, account}

      [] ->
        {:error, :not_found}
    end
  end

  def fetch(conn, id) do
    case fetch(id) do
      {:ok, account} -> {:ok, account}
      {:error, :not_found} -> get(conn, id)
    end
  end

  def fetch_all do
    :ets.tab2list(:accounts)
  end

  def get(conn, id) do
    statement = "SELECT * FROM accounts WHERE id = ?;"
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

  def update(conn, %__MODULE__{} = account) do
    statement = """
    UPDATE accounts
    SET pubkey = ?, channel = ?, sig_type = ?
    WHERE id = ?;
    """

    params = [
      {"blob", account.pubkey},
      {"text", account.channel},
      {"int", account.sig_type},
      {"text", account.id}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, account}
      error -> error
    end
  end

  def put(%__MODULE__{} = account) do
    :ets.insert(:accounts, {account.id, account})
  end

  def remove(id) do
    :ets.delete(:accounts, id)
    Hits.remove(id)
  end

  def delete(id) do
    :ets.insert(:accounts, {id, :delete})
  end

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      pubkey: row["pubkey"],
      channel: row["channel"],
      sig_type: row["sig_type"]
    })
  end
end
