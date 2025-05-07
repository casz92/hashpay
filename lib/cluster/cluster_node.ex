defmodule Hashpay.ClusterNode do
  @type t :: %__MODULE__{
          id: binary(),
          name: String.t(),
          ip: String.t(),
          active: boolean(),
          pubkey: binary(),
          role: String.t()
        }

  defstruct [
    :id,
    :name,
    :ip,
    :active,
    :pubkey,
    :role
  ]

  alias Hashpay.DB

  def up(conn) do
    create_table(conn)
  end

  def down(conn) do
    drop_table(conn)
  end

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS cluster (
      id UUID,
      name text,
      ip text,
      active boolean,
      pubkey blob,
      role text,
      PRIMARY KEY (id)
    );
    """

    DB.execute!(conn, statement)
  end

  def drop_table(conn) do
    statement = "DROP TABLE IF EXISTS cluster;"
    DB.execute!(conn, statement)
  end

  def new(name, ip, pubkey, role) do
    %__MODULE__{
      id: UUID.uuid4(),
      name: name,
      ip: ip,
      active: true,
      pubkey: pubkey,
      role: role
    }
  end

  def save(conn, %__MODULE__{} = node) do
    statement = """
    INSERT INTO cluster_nodes (id, name, ip, active, pubkey, role)
    VALUES ($1, $2, $3, $4, $5, $6);
    """

    params = [
      node.id,
      node.name,
      node.ip,
      node.active,
      node.pubkey,
      node.role
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, node}
      error -> error
    end
  end

  def delete(conn, id) do
    statement = "DELETE FROM cluster WHERE id = $1;"
    params = [id]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM cluster WHERE id = $1;"
    params = [id]

    case DB.execute(conn, statement, params) do
      {:ok, %Postgrex.Result{num_rows: num_rows} = result} ->
        case num_rows do
          1 -> {:ok, row_to_struct(DB.to_keyword(result))}
          _ -> {:error, :not_found}
        end

      error ->
        error
    end
  end

  def get_by_name(conn, name) do
    statement = "SELECT * FROM cluster WHERE name = $1 LIMIT 1;"
    params = [name]

    case DB.execute(conn, statement, params) do
      {:ok, %Postgrex.Result{num_rows: num_rows} = result} ->
        case num_rows do
          1 -> {:ok, row_to_struct(DB.to_keyword(result))}
          _ -> {:error, :not_found}
        end

      error ->
        error
    end
  end

  def all(conn) do
    statement = "SELECT * FROM cluster_nodes;"

    case DB.execute(conn, statement) do
      {:ok, %Postgrex.Result{num_rows: num_rows} = result} ->
        case num_rows do
          0 -> []
          _ -> DB.to_list(result, &row_to_struct/1)
        end

      error ->
        error
    end
  end

  def count(conn) do
    statement = "SELECT COUNT(*) FROM cluster_nodes;"

    case DB.execute(conn, statement) do
      {:ok, %Xandra.Page{} = page} ->
        case Enum.to_list(page) do
          [row] -> row["count"]
          [] -> 0
          _ -> 0
        end

      error ->
        error
    end
  end

  @nonce_max 99_999_999
  def generate_challenge(node_id) do
    timestamp = System.system_time(:second)
    # Genera un número aleatorio ≤ 99,999,999
    nonce = :rand.uniform(@nonce_max)
    "#{node_id}|#{timestamp}|#{nonce}"
  end

  def verify_challenge(challenge, expected_node_id) do
    case String.split(challenge, "|") do
      [node_id, timestamp_str, nonce_str] ->
        timestamp = String.to_integer(timestamp_str)
        nonce = String.to_integer(nonce_str)
        current_time = System.system_time(:second)

        valid_timestamp = abs(current_time - timestamp) <= 30
        valid_node_id = node_id == expected_node_id
        valid_nonce = nonce > 0 and nonce <= @nonce_max

        valid_timestamp and valid_node_id and valid_nonce

      _ ->
        false
    end
  end

  @spec get_and_authenticate(Xandra.conn(), String.t(), binary(), binary()) ::
          t() | nil
  def get_and_authenticate(conn, name, message, signature) do
    case get_by_name(conn, name) do
      {:ok, node} ->
        case Cafezinho.Impl.verify(signature, message, node.pubkey) do
          true -> {:ok, node}
          false -> {:error, :invalid_signature}
        end

      error ->
        error
    end
  end

  def row_to_struct(row) do
    %__MODULE__{
      id: row["id"],
      name: row["name"],
      ip: row["ip"],
      active: row["active"],
      pubkey: row["pubkey"],
      role: row["role"]
    }
  end
end
