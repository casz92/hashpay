defmodule Hashpay.Validator do
  @moduledoc """
  Estructura y funciones para los validadores de la blockchain de Hashpay.

  Un validador contiene:
  - id: Identificador único del validador
  - hostname: Nombre de host del validador
  - port: Puerto de escucha del validador
  - name: Nombre del validador
  - owner: Propietario del validador (dirección pública)
  - channel: Canal al que pertenece el validador
  - pubkey: Clave pública del validador
  - picture: URL de la imagen del validador
  - factor_a: Factor de ajuste A
  - factor_b: Factor de ajuste B
  - active: Estado del validador (activo o no)
  - failures: Contador de fallos del validador
  - creation: Marca de tiempo de creación del validador
  - updated: Marca de tiempo de última actualización del validador
  """
  alias Hashpay.DB

  @behaviour Hashpay.MigrationBehaviour

  @type t :: %__MODULE__{
          id: String.t(),
          hostname: String.t(),
          port: integer(),
          name: String.t(),
          owner: binary(),
          channel: String.t(),
          pubkey: binary(),
          picture: Path.t() | String.t() | nil,
          factor_a: number(),
          factor_b: non_neg_integer(),
          active: boolean(),
          failures: integer(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :hostname,
    :port,
    :name,
    :owner,
    :channel,
    :pubkey,
    :picture,
    :factor_a,
    :factor_b,
    :active,
    :failures,
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
    CREATE TABLE IF NOT EXISTS validators (
      id text,
      hostname text,
      port int,
      name text,
      owner blob,
      channel text,
      pubkey blob,
      picture text,
      factor_a double,
      factor_b int,
      active boolean,
      failures int,
      creation bigint,
      updated bigint,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def create_ets_table do
    :ets.new(:validators, [:ordered_set, :public, :named_table])
  end

  def load_all(conn) do
    statement = "SELECT * FROM validators;"

    case DB.execute(conn, statement) do
      {:ok, %Xandra.Page{} = page} ->
        Enum.each(page, fn row ->
          :ets.insert(:validators, {row["id"], row_to_struct(row)})
        end)

      error ->
        error
    end
  end

  def generate_id do
    Hashpay.gen_id("val_")
  end

  def new(attrs) do
    %__MODULE__{
      id: generate_id(),
      hostname: attrs[:hostname],
      port: attrs[:port],
      name: attrs[:name],
      owner: attrs[:owner],
      channel: attrs[:channel],
      pubkey: attrs[:pubkey],
      picture: attrs[:picture],
      factor_a: attrs[:factor_a],
      factor_b: attrs[:factor_b],
      active: attrs[:active],
      failures: attrs[:failures],
      creation: System.os_time(:second),
      updated: System.os_time(:second)
    }
  end

  def save(conn, %__MODULE__{} = validator) do
    statement = """
    INSERT INTO validators (id, hostname, port, name, owner, channel, pubkey, picture, factor_a, factor_b, active, failures, creation, updated)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
    """

    params = [
      {"text", validator.id},
      {"text", validator.hostname},
      {"int", validator.port},
      {"text", validator.name},
      {"blob", validator.owner},
      {"text", validator.channel},
      {"blob", validator.pubkey},
      {"text", validator.picture},
      {"double", validator.factor_a},
      {"int", validator.factor_b},
      {"boolean", validator.active},
      {"int", validator.failures},
      {"bigint", validator.creation},
      {"bigint", validator.updated}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, validator}
      error -> error
    end
  end

  def get(conn, id) do
    statement = "SELECT * FROM validators WHERE id = ?;"
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

  def fetch(id) do
    case :ets.lookup(:validators, id) do
      [{^id, validator}] -> {:ok, validator}
      [] -> {:error, :not_found}
    end
  end

  def fetch(conn, id) do
    case fetch(id) do
      {:ok, validator} -> {:ok, validator}
      {:error, :not_found} -> get(conn, id)
    end
  end

  def fetch_all do
    :ets.tab2list(:validators)
  end

  def remove(id) do
    :ets.delete(:validators, id)
  end

  def remove(conn, id) do
    :ets.delete(:validators, id)
    delete(conn, id)
  end

  def delete(conn, id) do
    statement = "DELETE FROM validators WHERE id = ?;"
    params = [{"text", id}]

    DB.execute(conn, statement, params)
  end

  def put(%__MODULE__{} = validator) do
    :ets.insert(:validators, {validator.id, validator})
  end

  def put(conn, %__MODULE__{} = validator) do
    :ets.insert(:validators, {validator.id, validator})
    update(conn, validator)
  end

  def exists?(conn, id) do
    statement = "SELECT id FROM validators WHERE id = ? LIMIT 1"
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

  # def update(conn, %__MODULE__{} = validator, fields \\ []) do
  #   if Enum.empty?(fields) do
  #     update_all(conn, validator)
  #   else
  #     update_fields(conn, validator, fields)
  #   end
  # end

  def update(conn, %__MODULE__{} = validator) do
    statement = """
    UPDATE validators
    SET hostname = ?, port = ?, name = ?, owner = ?, channel = ?, pubkey = ?, picture = ?, factor_a = ?, factor_b = ?, active = ?, failures = ?, updated = ?
    WHERE id = ?;
    """

    params = [
      {"text", validator.hostname},
      {"int", validator.port},
      {"text", validator.name},
      {"blob", validator.owner},
      {"text", validator.channel},
      {"blob", validator.pubkey},
      {"text", validator.picture},
      {"double", validator.factor_a},
      {"int", validator.factor_b},
      {"boolean", validator.active},
      {"int", validator.failures},
      {"bigint", validator.updated},
      {"text", validator.id}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, validator}
      error -> error
    end
  end

  def update_fields(conn, map, id) do
    set_clause =
      Enum.map_join(map, ", ", fn {field, value} ->
        "#{field} = :#{value}"
      end)

    statement = """
    UPDATE validators
    SET #{set_clause}
    WHERE id = :id;
    """

    case DB.execute(conn, statement, Map.put(map, :id, id)) do
      {:ok, _} -> :ok
      error -> error
    end
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS validators;"
    DB.execute(conn, statement)
  end

  def row_to_struct(row) do
    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{
      id: row["id"],
      hostname: row["hostname"],
      port: row["port"],
      name: row["name"],
      owner: row["owner"],
      channel: row["channel"],
      pubkey: row["pubkey"],
      picture: row["picture"],
      factor_a: row["factor_a"],
      factor_b: row["factor_b"],
      active: row["active"],
      failures: row["failures"],
      creation: row["creation"],
      updated: row["updated"]
    })
  end
end
