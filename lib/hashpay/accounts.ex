defmodule Hashpay.Account do
  alias Hashpay.Account
  alias Hashpay.Hits
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          pubkey: binary,
          channel: String.t(),
          verified: boolean(),
          type_alg: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :pubkey,
    :channel,
    :type_alg,
    verified: false
  ]

  @prefix "ac_"

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base.encode16(first16bytes)])
  end

  def new(attrs) do
    %__MODULE__{
      id: generate_id(attrs[:pubkey]),
      name: attrs[:name],
      pubkey: attrs[:pubkey],
      channel: attrs[:channel],
      type_alg: attrs[:type_alg]
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
      name text UNIQUE,
      pubkey blob,
      channel text,
      verified boolean,
      type_alg int,
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

  def batch_save(batch, account) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", account.id},
      {"text", account.name},
      {"blob", account.pubkey},
      {"text", account.channel},
      {"boolean", account.verified},
      {"int", account.type_alg}
    ])
  end

  def batch_delete(batch, id) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", id}])
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO accounts (id, name, pubkey, channel, verified, type_alg)
    VALUES (?, ?, ?, ?, ?, ?);
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
    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {id, :delete} ->
        remove(id)
        batch_delete(batch, id)

      {_id, account} ->
        batch_save(batch, account)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  def count(conn) do
    statement = "SELECT COUNT(*) FROM accounts;"
    params = []

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> {:ok, row["count"]}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
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

  def fetch_by_channel(conn, id, channel) do
    case fetch(id) do
      {:ok, account} ->
        (account.channel == channel && {:ok, account}) || {:error, :not_found}

      {:error, :not_found} ->
        get(conn, id, channel)
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

  def get(conn, id, channel) do
    statement = "SELECT * FROM accounts WHERE id = ? AND channel = ?;"
    params = [{"text", id}, {"text", channel}]

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

  def verified?(%Account{verified: verified}), do: verified

  def verified?(conn, id) do
    case fetch(conn, id) do
      {:ok, account} -> account.verified
      {:error, _} -> false
    end
  end

  def get_and_exists(conn, id, name) do
    statement = "SELECT * FROM accounts WHERE id = ? OR name = ?;"
    params = [{"text", id}, {"text", name}]

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

  def get_by_name(conn, name) do
    statement = "SELECT * FROM accounts WHERE name = ?;"
    params = [{"text", name}]

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
    SET pubkey = ?, channel = ?, type_alg = ?
    WHERE id = ?;
    """

    params = [
      {"blob", account.pubkey},
      {"text", account.channel},
      {"int", account.type_alg},
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
      type_alg: row["type_alg"]
    })
  end
end
