defmodule Hashpay.PgAccount do
  @moduledoc """
  Módulo para gestionar cuentas de usuario en PostgreSQL.
  Basado en el módulo Hashpay.Account pero adaptado para PostgreSQL.
  """
  alias Hashpay.PgAccount
  alias Hashpay.Hits
  alias Hashpay.Postgres, as: PG

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

  @doc """
  Crea la tabla de cuentas en PostgreSQL.
  """
  def create_table do
    # Crear la tabla accounts
    PG.create_table("accounts", """
    id TEXT PRIMARY KEY,
    name TEXT UNIQUE,
    pubkey BYTEA NOT NULL,
    channel TEXT NOT NULL,
    verified BOOLEAN DEFAULT FALSE,
    type_alg INTEGER NOT NULL
    """)

    # Crear índices
    PG.query("CREATE INDEX IF NOT EXISTS idx_accounts_name ON accounts (name)")
    PG.query("CREATE INDEX IF NOT EXISTS idx_accounts_channel ON accounts (channel)")
  end

  @doc """
  Elimina la tabla de cuentas en PostgreSQL.
  """
  def drop_table do
    PG.drop_table("accounts")
  end

  @doc """
  Inicializa la tabla ETS para cuentas.
  """
  def init do
    create_ets_table()
    load_accounts_from_db()
  end

  @doc """
  Crea la tabla ETS para cuentas.
  """
  def create_ets_table do
    :ets.new(:accounts, [:set, :public, :named_table])
  end

  @doc """
  Carga todas las cuentas desde PostgreSQL a la tabla ETS.
  """
  def load_accounts_from_db do
    case PG.query("SELECT * FROM accounts") do
      {:ok, result} ->
        Enum.each(result.rows, fn row ->
          account = row_to_struct(row, result.columns)
          put(account)
        end)
        :ok
      {:error, error} ->
        {:error, error}
    end
  end

  @doc """
  Guarda una cuenta en PostgreSQL.
  """
  def save(account) do
    PG.query(
      "INSERT INTO accounts (id, name, pubkey, channel, verified, type_alg) VALUES ($1, $2, $3, $4, $5, $6) ON CONFLICT (id) DO UPDATE SET name = $2, pubkey = $3, channel = $4, verified = $5, type_alg = $6",
      [account.id, account.name, account.pubkey, account.channel, account.verified, account.type_alg]
    )
  end

  @doc """
  Elimina una cuenta de PostgreSQL.
  """
  def delete_from_db(id) do
    PG.query("DELETE FROM accounts WHERE id = $1", [id])
  end

  @doc """
  Sincroniza las cuentas en la tabla ETS con PostgreSQL.
  """
  def sync_to_db do
    # Optimizar con Stream para evitar acumulación en memoria
    fetch_all()
    |> Stream.map(fn
      {id, :delete} ->
        remove(id)
        delete_from_db(id)

      {_id, account} ->
        save(account)
    end)
    # Ejecuta el proceso sin acumular memoria innecesariamente
    |> Stream.run()
  end

  @doc """
  Cuenta el número de cuentas en PostgreSQL.
  """
  def count do
    case PG.query("SELECT COUNT(*) FROM accounts") do
      {:ok, result} ->
        [count] = hd(result.rows)
        {:ok, count}
      error ->
        error
    end
  end

  @doc """
  Obtiene una cuenta de la tabla ETS.
  """
  def fetch(id) do
    case :ets.lookup(:accounts, id) do
      [{^id, account}] ->
        Hits.hit(account.id, :account)
        {:ok, account}

      [] ->
        {:error, :not_found}
    end
  end

  @doc """
  Obtiene una cuenta de PostgreSQL o de la tabla ETS si ya está cargada.
  """
  def fetch_from_db(id) do
    case fetch(id) do
      {:ok, account} ->
        {:ok, account}

      {:error, :not_found} ->
        case get_from_db(id) do
          {:ok, account} ->
            put(account)
            {:ok, account}

          error ->
            error
        end
    end
  end

  @doc """
  Verifica si existe una cuenta con el ID dado.
  """
  def exists?(id) do
    case fetch_from_db(id) do
      {:ok, _account} ->
        true

      _error ->
        false
    end
  end

  @doc """
  Obtiene una cuenta por ID y canal.
  """
  def fetch_by_channel(id, channel) do
    case fetch(id) do
      {:ok, account} ->
        (account.channel == channel && {:ok, account}) || {:error, :not_found}

      {:error, :not_found} ->
        get_by_id_and_channel(id, channel)
    end
  end

  @doc """
  Obtiene todas las cuentas de la tabla ETS.
  """
  def fetch_all do
    :ets.tab2list(:accounts)
  end

  @doc """
  Obtiene una cuenta de PostgreSQL por ID.
  """
  def get_from_db(id) do
    case PG.query("SELECT * FROM accounts WHERE id = $1", [id]) do
      {:ok, result} ->
        case result.rows do
          [row] -> {:ok, row_to_struct(row, result.columns)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  @doc """
  Obtiene una cuenta de PostgreSQL por ID y canal.
  """
  def get_by_id_and_channel(id, channel) do
    case PG.query("SELECT * FROM accounts WHERE id = $1 AND channel = $2", [id, channel]) do
      {:ok, result} ->
        case result.rows do
          [row] -> {:ok, row_to_struct(row, result.columns)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  @doc """
  Verifica si una cuenta está verificada.
  """
  def verified?(%PgAccount{verified: verified}), do: verified

  @doc """
  Verifica si una cuenta con el ID dado está verificada.
  """
  def verified?(id) do
    case fetch_from_db(id) do
      {:ok, account} -> account.verified
      {:error, _} -> false
    end
  end

  @doc """
  Obtiene una cuenta por ID o nombre.
  """
  def get_and_exists(id, name) do
    case PG.query("SELECT * FROM accounts WHERE id = $1 OR name = $2", [id, name]) do
      {:ok, result} ->
        case result.rows do
          [row] -> {:ok, row_to_struct(row, result.columns)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  @doc """
  Obtiene una cuenta por nombre.
  """
  def get_by_name(name) do
    case PG.query("SELECT * FROM accounts WHERE name = $1", [name]) do
      {:ok, result} ->
        case result.rows do
          [row] -> {:ok, row_to_struct(row, result.columns)}
          [] -> {:error, :not_found}
          _ -> {:error, :multiple_results}
        end

      error ->
        error
    end
  end

  @doc """
  Actualiza campos específicos de una cuenta.
  """
  def update_fields(fields, id) do
    # Construir la cláusula SET
    {set_clause, values} = build_set_clause(fields)

    # Agregar el ID al final de los valores
    values = values ++ [id]

    # Construir la consulta
    query = "UPDATE accounts SET #{set_clause} WHERE id = $#{length(values)}"

    PG.query(query, values)
  end

  @doc """
  Construye una cláusula SET para una consulta UPDATE.
  """
  defp build_set_clause(fields) do
    {clause, values} =
      fields
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {{field, value}, index}, {clauses, values} ->
        {["#{field} = $#{index}" | clauses], [value | values]}
      end)

    {Enum.reverse(clause) |> Enum.join(", "), Enum.reverse(values)}
  end

  @doc """
  Guarda una cuenta en la tabla ETS.
  """
  def put(%__MODULE__{} = account) do
    :ets.insert(:accounts, {account.id, account})
    Hits.hit(account.id, :account)
  end

  @doc """
  Elimina una cuenta de la tabla ETS.
  """
  def remove(id) do
    :ets.delete(:accounts, id)
    Hits.remove(id)
  end

  @doc """
  Marca una cuenta para ser eliminada en la próxima sincronización.
  """
  def delete(id) do
    :ets.insert(:accounts, {id, :delete})
  end

  @doc """
  Convierte una fila de PostgreSQL a una estructura de cuenta.
  """
  def row_to_struct(row, columns) do
    # Convertir la lista de valores a un mapa con nombres de columnas
    row_kw = Enum.zip(columns, row) |> Enum.into(%{})

    struct!(__MODULE__, %{
      id: row_kw["id"],
      name: row_kw["name"],
      pubkey: row_kw["pubkey"],
      channel: row_kw["channel"],
      verified: row_kw["verified"],
      type_alg: row_kw["type_alg"]
    })
  end
end
