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

  def create_table(conn) do
    statement = """
    CREATE TABLE IF NOT EXISTS cluster_nodes (
      id UUID,
      name text UNIQUE,
      ip text,
      active boolean,
      pubkey blob,
      role text,
      PRIMARY KEY (id)
    );
    """

    DB.execute(conn, statement)
  end

  def new(name, ip, pubkey, role) do
    %__MODULE__{
      id: Hashpay.gen_id("node_"),
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
    VALUES (?, ?, ?, ?, ?, ?);
    """

    params = [
      {"uuid", node.id},
      {"text", node.name},
      {"text", node.ip},
      {"boolean", node.active},
      {"blob", node.pubkey},
      {"text", node.role}
    ]

    case DB.execute(conn, statement, params) do
      {:ok, _} -> {:ok, node}
      error -> error
    end
  end

  def delete(conn, id) do
    statement = "DELETE FROM cluster_nodes WHERE id = ?;"
    params = [{"uuid", id}]

    DB.execute(conn, statement, params)
  end

  def get(conn, id) do
    statement = "SELECT * FROM cluster_nodes WHERE id = ?;"
    params = [{"uuid", id}]

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
    statement = "SELECT * FROM cluster_nodes WHERE name = ?;"
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

  def all(conn) do
    statement = "SELECT * FROM cluster_nodes;"

    case DB.execute(conn, statement) do
      {:ok, %Xandra.Page{} = page} ->
        Enum.map(page, &row_to_struct/1)

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
