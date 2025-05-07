defmodule Hashpay.Account do
  alias Hex.Netrc.Cache
  alias Hashpay.Account
  alias Hashpay.Cache
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
  @regex ~r/^ac_[a-zA-Z0-9]*$/
  @trdb :accounts

  @compile {:inline, [fetch: 2, fetch_by_channel: 3, delete: 2]}

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base62.encode(first16bytes)])
  end

  def match?(id) do
    Regex.match?(@regex, id)
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

  @impl true
  def up(conn) do
    create_table(conn)
  end

  @impl true
  def down(conn) do
    drop_table(conn)
  end

  def create_table(_conn) do
    # statement = """
    # CREATE TABLE IF NOT EXISTS accounts (
    #   id text,
    #   name text,
    #   pubkey bytea,
    #   channel text,
    #   verified boolean,
    #   type_alg integer,
    #   PRIMARY KEY (id)
    # );
    # """

    # DB.execute!(conn, statement)

    # indices = [
    #   "CREATE INDEX IF NOT EXISTS idx_accounts_name ON accounts (name);"
    # ]

    # Enum.each(indices, fn index ->
    #   DB.execute!(conn, index)
    # end)
  end

  def drop_table(_conn) do
    # statement = "DROP TABLE IF EXISTS accounts;"
    # DB.execute!(conn, statement)
  end

  @impl true
  def init(_conn) do
    # prepare_statements!(conn)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, :accounts, id)
  end

  # def prepare_statements!(conn) do
  #   insert_prepared = """
  #   INSERT INTO accounts (id, name, pubkey, channel, verified, type_alg)
  #   VALUES :VALUES ON CONFLICT DO NOTHING;
  #   """

  #   delete_statement = "DELETE FROM accounts WHERE id in :VALUES;"

  #   insert_prepared = DB.prepare!(conn, insert_prepared)
  #   delete_prepared = DB.prepare!(conn, delete_statement)

  #   :persistent_term.put({:stmt, "accounts_insert"}, insert_prepared)
  #   :persistent_term.put({:stmt, "accounts_delete"}, delete_prepared)
  # end

  # def insert_prepared do
  #   :persistent_term.get({:stmt, "accounts_insert"})
  # end

  # def delete_prepared do
  #   :persistent_term.get({:stmt, "accounts_delete"})
  # end

  # def batch_sync(batch) do
  #   # Optimizar con Stream para evitar acumulación en memoria
  #   fetch_all()
  #   |> Stream.map(fn
  #     {id, :delete} ->
  #       remove(id)
  #       batch_delete(batch, id)

  #     {_id, account} ->
  #       batch_save(batch, account)
  #   end)
  #   # Ejecuta el proceso sin acumular memoria innecesariamente
  #   |> Stream.run()
  # end

  # def count(conn) do
  #   statement = "SELECT COUNT(*) FROM accounts;"
  #   params = []

  #   case DB.execute(conn, statement, params) do
  #     {:ok, %Xandra.Page{} = page} ->
  #       case Enum.to_list(page) do
  #         [row] -> {:ok, row["count"]}
  #         [] -> {:error, :not_found}
  #         _ -> {:error, :multiple_results}
  #       end

  #     error ->
  #       error
  #   end
  # end

  def fetch(tr, id) do
    ThunderRAM.get(tr, :accounts, id)
  end

  def exists?(conn, id) do
    case fetch(conn, id) do
      {:ok, _account} ->
        true

      _error ->
        false
    end
  end

  def fetch_by_channel(tr, id, channel) do
    case fetch(tr, id) do
      {:ok, account} ->
        (account.channel == channel && {:ok, account}) || {:error, :not_found}

      nil ->
        nil
    end
  end

  # def fetch_all do
  #   :ets.tab2list(:accounts)
  # end

  # def get(conn, id) do
  #   statement = "SELECT * FROM accounts WHERE id = ?;"
  #   params = [{"text", id}]

  #   case DB.execute(conn, statement, params) do
  #     {:ok, %Postgrex.Result{rows: rows, columns: columns}} ->
  #       case rows do
  #         [row] -> {:ok, row_to_struct(row, columns)}
  #         [] -> {:error, :not_found}
  #         _ -> {:error, :multiple_results}
  #       end

  #     error ->
  #       error
  #   end
  # end

  # def get(conn, id, channel) do
  #   statement = "SELECT * FROM accounts WHERE id = ? AND channel = ?;"
  #   params = [{"text", id}, {"text", channel}]

  #   case DB.execute(conn, statement, params) do
  #     {:ok, %Postgrex.Result{rows: rows, columns: columns}} ->
  #       case rows do
  #         [row] -> {:ok, row_to_struct(row, columns)}
  #         [] -> {:error, :not_found}
  #         _ -> {:error, :multiple_results}
  #       end

  #     error ->
  #       error
  #   end
  # end

  def verified?(%Account{verified: verified}), do: verified

  # def verified?(conn, id) do
  #   case fetch(conn, id) do
  #     {:ok, account} -> account.verified
  #     {:error, _} -> false
  #   end
  # end

  # def get_and_exists(conn, id, name) do
  #   statement = "SELECT * FROM accounts WHERE id = ? OR name = ?;"
  #   params = [{"text", id}, {"text", name}]

  #   case DB.execute(conn, statement, params) do
  #     {:ok, %Postgrex.Result{rows: rows, columns: columns}} ->
  #       case rows do
  #         [row] -> {:ok, row_to_struct(row, columns)}
  #         [] -> {:error, :not_found}
  #         _ -> {:error, :multiple_results}
  #       end

  #     error ->
  #       error
  #   end
  # end

  # def get_by_name(conn, name) do
  #   statement = "SELECT * FROM accounts WHERE name = ?;"
  #   params = [{"text", name}]

  #   case DB.execute(conn, statement, params) do
  #     {:ok, %Postgrex.Result{rows: rows, columns: columns}} ->
  #       case rows do
  #         [row] ->
  #           {:ok, row_to_struct(row, columns)}

  #         [] ->
  #           {:error, :not_found}

  #         _ ->
  #           {:error, :multiple_results}
  #       end

  #     error ->
  #       error
  #   end
  # end

  # def batch_update_fields(batch, map, id) do
  #   set_clause =
  #     Enum.map_join(map, ", ", fn {field, value} ->
  #       "#{field} = :#{value}"
  #     end)

  #   statement = """
  #   UPDATE accounts
  #   SET #{set_clause}
  #   WHERE id = :id;
  #   """

  #   Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  # end

  def prepare_bulks do
    insert_account =
      """
      INSERT INTO accounts (id, name, pubkey, channel, verified, type_alg)
      VALUES :VALUES ON CONFLICT DO NOTHING;
      """

    name_update =
      """
      UPDATE accounts AS a
      SET name = b.name
      FROM (
      VALUES
      :VALUES
      ) AS b(id, name)
      WHERE b.id = a.id;
      """

    pubkey_update =
      """
      UPDATE accounts AS a
      SET pubkey = b.pubkey, sig_type = b.sig_type
      FROM (
      VALUES
      :VALUES
      ) AS b(id, pubkey, sig_type)
      WHERE b.id = a.id;
      """

    channel_update =
      """
      UPDATE accounts AS a
      SET channel = b.channel
      FROM (
      VALUES
      :VALUES
      ) AS b(id, channel)
      WHERE b.id = a.id;
      """

    verified_update =
      """
      UPDATE accounts AS a
      SET verified = b.verified
      FROM (
      VALUES
      :VALUES
      ) AS b(id, verified)
      WHERE b.id = a.id;
      """

    delete_accounts =
      """
      DELETE FROM accounts
      WHERE id IN (:VALUES);
      """

    :persistent_term.put({:stmt, "accounts_insert"}, insert_account)
    :persistent_term.put({:stmt, "accounts_update_name"}, name_update)
    :persistent_term.put({:stmt, "accounts_update_pubkey"}, pubkey_update)
    :persistent_term.put({:stmt, "accounts_update_channel"}, channel_update)
    :persistent_term.put({:stmt, "accounts_update_verified"}, verified_update)
    :persistent_term.put({:stmt, "accounts_delete"}, delete_accounts)
  end

  # defp set_update_fields(varname, map) do
  #   Map.keys(map)
  #   |> Enum.map(fn field ->
  #     "#{field} = #{varname}.#{field}"
  #   end)
  #   |> Enum.join(", ")
  # end

  # def remove(id) do
  #   :ets.delete(:accounts, id)
  # end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end

  # def row_to_struct(row, columns) do
  #   # Convertir la lista de valores a un mapa con nombres de columnas
  #   row_kw = Enum.zip(columns, row) |> Enum.into(%{})

  #   struct!(__MODULE__, %{
  #     id: row_kw["id"],
  #     name: row_kw["name"],
  #     pubkey: row_kw["pubkey"],
  #     channel: row_kw["channel"],
  #     verified: row_kw["verified"],
  #     type_alg: row_kw["type_alg"]
  #   })
  # end
end
