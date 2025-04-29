defmodule Hashpay.Member do
  @moduledoc """
  Estructura y funciones para los miembros de la blockchain de Hashpay.

  Un miembro contiene:
  - group_id: Identificador del grupo al que pertenece el miembro
  - member_id: Identificador único del miembro
  - role: Rol del miembro en el grupo
  - creation: Marca de tiempo de creación del miembro
  - meta: Metadatos adicionales del miembro
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @enforce_keys [
    :group_id,
    :member_id,
    :role
  ]

  defstruct [
    :group_id,
    :member_id,
    :role,
    :creation,
    :meta
  ]

  @type t :: %__MODULE__{
          group_id: String.t(),
          member_id: String.t(),
          role: String.t() | nil,
          creation: non_neg_integer(),
          meta: map() | nil
        }

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS members (
      group_id text,
      member_id text,
      role text,
      creation bigint,
      meta MAP<text, text>,
      PRIMARY KEY (group_id, member_id)
    ) with clustering order by (member_id desc);
    """

    DB.execute(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS members;"
    DB.execute(conn, statement)
  end

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

  def new(group_id, member_id, role, meta \\ %{}) do
    %__MODULE__{
      group_id: group_id,
      member_id: member_id,
      role: role,
      creation: Hashpay.get_last_round_id(),
      meta: meta
    }
  end

  def prepare_statements!(conn) do
    insert_prepared = """
    INSERT INTO members (group_id, member_id, role, creation, meta)
    VALUES (?, ?, ?, ?, ?);
    """

    delete_statement = "DELETE FROM members WHERE group_id = ? AND member_id = ?;"

    insert_prepared = Xandra.prepare!(conn, insert_prepared)
    delete_prepared = Xandra.prepare!(conn, delete_statement)

    :persistent_term.put({:stmt, "members_insert"}, insert_prepared)
    :persistent_term.put({:stmt, "members_delete"}, delete_prepared)
  end

  def insert_prepared do
    :persistent_term.get({:stmt, "members_insert"})
  end

  def delete_prepared do
    :persistent_term.get({:stmt, "members_delete"})
  end

  def batch_save(batch, member) do
    Xandra.Batch.add(batch, insert_prepared(), [
      {"text", member.group_id},
      {"text", member.member_id},
      {"text", member.role},
      {"bigint", member.creation},
      {"map<text, text>", member.meta}
    ])
  end

  def batch_delete(batch, group_id, member_id) do
    Xandra.Batch.add(batch, delete_prepared(), [{"text", group_id}, {"text", member_id}])
  end

  @spec exists?(pid(), String.t(), String.t()) :: boolean()
  def exists?(conn, group_id, member_id) do
    statement = "SELECT member_id FROM members WHERE group_id = ? AND member_id = ? LIMIT 1"
    params = [{"text", group_id}, {"text", member_id}]

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

  def exists?(conn, group_id, member_id, role) do
    statement =
      "SELECT member_id FROM members WHERE group_id = ? AND member_id = ? AND role = ? LIMIT 1"

    params = [{"text", group_id}, {"text", member_id}, {"text", role}]

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

  def get(conn, group_id, member_id) do
    statement = "SELECT * FROM members WHERE group_id = ? AND member_id = ?;"
    params = [{"text", group_id}, {"text", member_id}]

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
    # Crear la estructura con los campos deserializados
    struct!(__MODULE__, %{
      group_id: row["group_id"],
      member_id: row["member_id"],
      role: row["role"],
      creation: row["creation"],
      meta: row["meta"]
    })
  end
end
