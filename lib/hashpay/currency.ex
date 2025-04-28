defmodule Hashpay.Currency do
  @moduledoc """
  Estructura y funciones para las monedas de la blockchain de Hashpay.

  Una moneda contiene:
  - id: Identificador único de la moneda
  - name: Nombre de la moneda
  - pubkey: Clave pública del propietario de la moneda
  - picture: URL de la imagen de la moneda
  - decimal: Número de decimales de la moneda
  - symbol: Símbolo de la moneda
  - max_supply: Suministro máximo de la moneda
  - props: Propiedades adicionales de la moneda
  - creation: Marca de tiempo de creación de la moneda
  - updated: Marca de tiempo de última actualización de la moneda
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          pubkey: binary() | nil,
          picture: String.t() | nil,
          decimal: non_neg_integer(),
          symbol: String.t(),
          max_supply: non_neg_integer(),
          props: [String.t()] | nil,
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  @enforce_keys [
    :id,
    :name,
    :pubkey,
    :picture,
    :decimal,
    :symbol,
    :max_supply,
    :props,
    :creation,
    :updated
  ]

  defstruct [
    :id,
    :name,
    :pubkey,
    :picture,
    :decimal,
    :symbol,
    :max_supply,
    :props,
    :creation,
    :updated
  ]

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
    CREATE TABLE IF NOT EXISTS currencies (
      id text,
      name text,
      pubkey blob,
      picture text,
      decimal int,
      symbol text,
      max_supply bigint,
      props list<text>,
      creation bigint,
      updated bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS currencies;"
    DB.execute(conn, statement)
  end

  def create_ets_table do
    :ets.new(:currencies, [:ordered_set, :public, :named_table])
  end

  def load_all(conn) do
    statement = "SELECT * FROM currencies;"

    case DB.execute(conn, statement) do
      {:ok, %Xandra.Page{} = page} ->
        Enum.each(page, fn row ->
          :ets.insert(:currencies, {row["id"], row_to_struct(row)})
        end)

      error ->
        error
    end
  end

  def generate_id(id) do
    ["cu_", id] |> IO.iodata_to_binary()
  end

  def new(attrs) do
    %__MODULE__{
      id: generate_id(attrs[:id]),
      name: attrs[:name],
      pubkey: attrs[:pubkey],
      picture: attrs[:picture],
      decimal: attrs[:decimal],
      symbol: attrs[:symbol],
      max_supply: attrs[:max_supply],
      props: attrs[:props],
      creation: Hashpay.get_last_round_id(),
      updated: Hashpay.get_last_round_id()
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO currencies (id, name, pubkey, picture, decimal, symbol, max_supply, props, creation, updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM currencies WHERE id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "currencies_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "currencies_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "currencies_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "currencies_delete"})
  end

  def batch_save(batch, currency) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", currency.id},
      {"text", currency.name},
      {"blob", currency.pubkey},
      {"text", currency.picture},
      {"int", currency.decimal},
      {"text", currency.symbol},
      {"bigint", currency.max_supply},
      {"list<text>", currency.props},
      {"bigint", currency.creation},
      {"bigint", currency.updated}
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
    UPDATE currencies
    SET #{set_clause}
    WHERE id = :id;
    """

    Xandra.Batch.add(batch, statement, Map.put(map, :id, id))
  end

  def count(conn) do
    statement = "SELECT COUNT(*) FROM currencies;"
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

  def update(conn, %__MODULE__{} = currency) do
    statement = """
    UPDATE currencies
    SET name = ?, pubkey = ?, picture = ?, decimal = ?, symbol = ?, max_supply = ?, props = ?, updated = ?
    WHERE id = ?;
    """

    params = [
      {"text", currency.name},
      {"blob", currency.pubkey},
      {"text", currency.picture},
      {"int", currency.decimal},
      {"text", currency.symbol},
      {"bigint", currency.max_supply},
      {"list<text>", currency.props},
      {"bigint", currency.updated},
      {"text", currency.id}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, currency}
      error -> error
    end
  end

  def update_fields(conn, map, id) do
    set_clause =
      Enum.map_join(map, ", ", fn {field, value} ->
        "#{field} = :#{value}"
      end)

    statement = """
    UPDATE currencies
    SET #{set_clause}
    WHERE id = :id;
    """

    case DB.execute(conn, statement, Map.put(map, :id, id)) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def batch_sync(conn) do
    batch = Xandra.Batch.new()

    update_statement = """
    UPDATE currencies
    SET name = ?, pubkey = ?, picture = ?, decimal = ?, symbol = ?, max_supply = ?, props = ?, updated = ?
    WHERE id = ?;
    """

    delete_statement = "DELETE FROM currencies WHERE id = ?;"

    # Preparar consultas solo una vez
    update_prepared = Xandra.prepare!(conn, update_statement)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {id, :delete} ->
        remove(id)
        Xandra.Batch.add(batch, delete_prepared, [{"text", id}])

      {_id, currency} ->
        params = [
          {"text", currency.name},
          {"blob", currency.pubkey},
          {"text", currency.picture},
          {"int", currency.decimal},
          {"text", currency.symbol},
          {"bigint", currency.max_supply},
          {"list<text>", currency.props},
          {"bigint", currency.updated},
          {"text", currency.id}
        ]

        Xandra.Batch.add(batch, update_prepared, params)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  def remove(id) do
    :ets.delete(:currencies, id)
  end

  def delete(id) do
    :ets.insert(:currencies, {id, :delete})
  end

  def delete(conn, id) do
    statement = "DELETE FROM currencies WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def put(%__MODULE__{} = currency) do
    :ets.insert(:currencies, {currency.id, currency})
  end

  def put(conn, %__MODULE__{} = currency) do
    :ets.insert(:currencies, {currency.id, currency})
    update(conn, currency)
  end

  def exists?(conn, id) do
    statement = "SELECT id FROM currencies WHERE id = ? LIMIT 1"
    params = [{"text", id}]

    case DB.execute(conn, statement, params) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [] -> false
          _ -> true
        end

      error ->
        error
    end
  end

  def fetch(id) do
    case :ets.lookup(:currencies, id) do
      [{^id, :delete}] -> {:error, :deleted}
      [{^id, currency}] -> {:ok, currency}
      [] -> {:error, :not_found}
    end
  end

  def fetch(conn, id) do
    case fetch(id) do
      {:ok, currency} -> {:ok, currency}
      {:error, :not_found} -> get(conn, id)
      error -> error
    end
  end

  def fetch_all do
    :ets.tab2list(:currencies)
  end

  def get(conn, id) do
    statement = "SELECT * FROM currencies WHERE id = ?;"
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

  def row_to_struct(row) do
    struct!(__MODULE__, %{
      id: row["id"],
      name: row["name"],
      pubkey: row["pubkey"],
      picture: row["picture"],
      decimal: row["decimal"],
      symbol: row["symbol"],
      max_supply: row["max_supply"],
      props: row["props"],
      creation: row["creation"],
      updated: row["updated"]
    })
  end
end
