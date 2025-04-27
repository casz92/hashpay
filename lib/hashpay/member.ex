defmodule Hashpay.Member do
  @moduledoc """
  Estructura y funciones para los miembros de la blockchain de Hashpay.

  Un miembro contiene:
  - group_id: Identificador del grupo al que pertenece el miembro
  - member_id: Identificador único del miembro
  - creation: Marca de tiempo de creación del miembro
  - meta: Metadatos adicionales del miembro
  """
  alias Hashpay.DB
  @behaviour Hashpay.MigrationBehaviour

  @enforce_keys [
    :group_id,
    :member_id
  ]

  defstruct [
    :group_id,
    :member_id,
    :creation,
    :meta
  ]

  @type t :: %__MODULE__{
          group_id: String.t(),
          member_id: String.t(),
          creation: non_neg_integer(),
          meta: map() | nil
        }

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS members (
      group_id text,
      member_id text,
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

  def up do
    conn = DB.get_conn_with_retry()
    create_table(conn)
  end

  def down do
    conn = DB.get_conn_with_retry()
    drop_table(conn)
  end

  def new(group_id, member_id, meta \\ %{}) do
    %__MODULE__{
      group_id: group_id,
      member_id: member_id,
      creation: Hashpay.get_last_round_id(),
      meta: meta
    }
  end

  def save(conn, %__MODULE__{} = member) do
    statement = """
    INSERT INTO members (group_id, member_id, creation, meta)
    VALUES (?, ?, ?, ?);
    """

    params = [
      {"text", member.group_id},
      {"text", member.member_id},
      {"bigint", member.creation},
      {"map<text, text>", member.meta}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, member}
      error -> error
    end
  end

  def batch_save!(conn, members) do
    batch = Xandra.Batch.new()

    statement = """
    INSERT INTO members (group_id, member_id, creation, meta)
    VALUES (?, ?, ?, ?);
    """

    prepared = Xandra.prepare!(conn, statement)

    batch =
      Enum.reduce(members, batch, fn member, batch ->
        params = [
          {"text", member.group_id},
          {"text", member.member_id},
          {"bigint", member.creation},
          {"map<text, text>", member.meta}
        ]

        Xandra.Batch.add(batch, prepared, params)
      end)

    DB.execute!(conn, batch)
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
      creation: row["creation"],
      meta: row["meta"]
    })
  end
end
