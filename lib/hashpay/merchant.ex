defmodule Hashpay.Merchant do
  @moduledoc """
  Estructura y funciones para los comercios de la blockchain de Hashpay.

  Un comercio contiene:
  - id: Identificador único del comercio
  - name: Nombre del comercio
  - channel: Canal donde opera el comercio
  - pubkey: Clave pública del comercio
  - picture: URL de la imagen del comercio
  - active: Estado del comercio (activo o no)
  - creation: Marca de tiempo de creación del comercio
  - updated: Marca de tiempo de última actualización del comercio
  """
  alias Hashpay.Hits
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          channel: String.t(),
          pubkey: binary(),
          picture: String.t() | nil,
          active: boolean(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :channel,
    :pubkey,
    :picture,
    :active,
    :creation,
    :updated
  ]

  @prefix "mc_"
  @regex ~r/^mc_[a-zA-Z0-9]*$/

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
    CREATE TABLE IF NOT EXISTS merchants (
      id text,
      name text,
      channel text,
      pubkey blob,
      picture text,
      active boolean,
      creation bigint,
      updated bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute!(conn, statement)

    indices = [
      "CREATE INDEX IF NOT EXISTS ON merchants (name);"
    ]

    Enum.each(indices, fn index ->
      DB.execute!(conn, index)
    end)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS merchants;"
    DB.execute!(conn, statement)
  end

  @impl true
  def init(conn) do
    create_ets_table()
    prepare_statements!(conn)
  end

  def create_ets_table do
    :ets.new(:merchants, [:set, :public, :named_table])
  end

  def generate_id(pubkey) do
    <<first16bytes::binary-16, _rest::binary>> = :crypto.hash(:sha3_256, pubkey)
    IO.iodata_to_binary([@prefix, Base62.encode(first16bytes)])
  end

  def match?(id) do
    Regex.match?(@regex, id)
  end

  def new(attrs) do
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(attrs[:pubkey]),
      name: attrs[:name],
      channel: attrs[:channel],
      pubkey: attrs[:pubkey],
      picture: attrs[:picture],
      active: true,
      creation: last_round_id,
      updated: last_round_id
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO merchants (id, name, channel, pubkey, picture, active, creation, updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM merchants WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "merchants_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "merchants_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "merchants_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "merchants_delete"})
  end

  def batch_save(batch, merchant) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", merchant.id},
      {"text", merchant.name},
      {"text", merchant.channel},
      {"blob", merchant.pubkey},
      {"text", merchant.picture},
      {"boolean", merchant.active},
      {"bigint", merchant.creation},
      {"bigint", merchant.updated}
    ])
  end

  def batch_delete(batch, id) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", id}])
  end

  def count(conn) do
    statement = "SELECT COUNT(*) FROM merchants;"
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

  def batch_update_fields(batch, map, id) do
    set_clause =
      Enum.map_join(map, ", ", fn {field, value} ->
        "#{field} = :#{value}"
      end)

    statement = """
    UPDATE merchants
    SET #{set_clause}
    WHERE id = :id;
    """

    Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  end

  def remove(id) do
    :ets.delete(:merchants, id)
    Hits.remove(id)
  end

  def delete(conn, id) do
    statement = "DELETE FROM merchants WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM merchants WHERE id = ?;"
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
    statement = "SELECT * FROM merchants WHERE id = ? AND channel = ?;"
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

  def get_by_name(conn, name) do
    statement = "SELECT * FROM merchants WHERE name = ?;"
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

  def fetch(id) do
    case :ets.lookup(:merchants, id) do
      [{^id, merchant}] ->
        Hits.hit(id, :merchants)
        {:ok, merchant}

      [] ->
        {:error, :not_found}
    end
  end

  def fetch(conn, id) do
    case fetch(id) do
      {:ok, merchant} ->
        {:ok, merchant}

      {:error, :not_found} ->
        case get(conn, id) do
          {:ok, merchant} ->
            put(merchant)
            {:ok, merchant}

          error ->
            error
        end
    end
  end

  def fetch_by_channel(conn, id, channel) do
    case fetch(id) do
      {:ok, merchant} ->
        (merchant.channel == channel && {:ok, merchant}) || {:error, :not_found}

      {:error, :not_found} ->
        get(conn, id, channel)
    end
  end

  def put(%__MODULE__{} = merchant) do
    :ets.insert(:merchants, {merchant.id, merchant})
    Hits.hit(merchant.id, :merchants)
  end

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      name: row["name"],
      channel: row["channel"],
      pubkey: row["pubkey"],
      picture: row["picture"],
      active: row["active"],
      creation: row["creation"],
      updated: row["updated"]
    })
  end
end
