defmodule Hashpay.Postgres do
  @moduledoc """
  Módulo para interactuar con la base de datos PostgreSQL.
  Proporciona funciones para ejecutar consultas y transacciones.
  """
  require Logger

  @doc """
  Ejecuta una consulta SQL en PostgreSQL.

  ## Parámetros

  - `query`: Consulta SQL a ejecutar
  - `params`: Parámetros para la consulta (opcional)
  - `opts`: Opciones adicionales para la consulta (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.query("SELECT * FROM users WHERE id = $1", [1])
      {:ok, %Postgrex.Result{...}}

  """
  def query(query, params \\ [], opts \\ []) do
    Postgrex.query(get_conn(), query, params, opts)
  end

  @doc """
  Ejecuta una consulta SQL en PostgreSQL y devuelve el resultado.
  Lanza una excepción si la consulta falla.

  ## Parámetros

  - `query`: Consulta SQL a ejecutar
  - `params`: Parámetros para la consulta (opcional)
  - `opts`: Opciones adicionales para la consulta (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.query!("SELECT * FROM users WHERE id = $1", [1])
      %Postgrex.Result{...}

  """
  def query!(query, params \\ [], opts \\ []) do
    Postgrex.query!(get_conn(), query, params, opts)
  end

  @doc """
  Ejecuta una transacción en PostgreSQL.

  ## Parámetros

  - `fun`: Función que recibe una conexión y ejecuta operaciones dentro de la transacción
  - `opts`: Opciones adicionales para la transacción (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.transaction(fn conn ->
      ...>   Postgrex.query(conn, "INSERT INTO users (name) VALUES ($1)", ["John"])
      ...>   Postgrex.query(conn, "INSERT INTO profiles (user_id) VALUES (lastval())", [])
      ...> end)
      {:ok, :ok}

  """
  def transaction(fun, opts \\ []) do
    Postgrex.transaction(get_conn(), fun, opts)
  end

  @doc """
  Obtiene la conexión a PostgreSQL.
  """
  def get_conn do
    Process.whereis(Postgrex)
  end

  @doc """
  Crea una tabla en PostgreSQL si no existe.

  ## Parámetros

  - `table_name`: Nombre de la tabla a crear
  - `columns`: Definición de columnas de la tabla

  ## Ejemplos

      iex> Hashpay.Postgres.create_table("users", "id SERIAL PRIMARY KEY, name TEXT NOT NULL")
      {:ok, %Postgrex.Result{...}}

  """
  def create_table(table_name, columns) do
    query("CREATE TABLE IF NOT EXISTS #{table_name} (#{columns})")
  end

  @doc """
  Elimina una tabla de PostgreSQL si existe.

  ## Parámetros

  - `table_name`: Nombre de la tabla a eliminar

  ## Ejemplos

      iex> Hashpay.Postgres.drop_table("users")
      {:ok, %Postgrex.Result{...}}

  """
  def drop_table(table_name) do
    query("DROP TABLE IF EXISTS #{table_name}")
  end

  @doc """
  Inserta un registro en una tabla de PostgreSQL.

  ## Parámetros

  - `table_name`: Nombre de la tabla
  - `columns`: Lista de nombres de columnas
  - `values`: Lista de valores a insertar
  - `returning`: Columnas a devolver (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.insert("users", ["name", "email"], ["John", "john@example.com"], "id")
      {:ok, %Postgrex.Result{...}}

  """
  def insert(table_name, columns, values, returning \\ "*") do
    columns_str = Enum.join(columns, ", ")
    placeholders = 1..length(values) |> Enum.map(&"$#{&1}") |> Enum.join(", ")
    
    query(
      "INSERT INTO #{table_name} (#{columns_str}) VALUES (#{placeholders}) RETURNING #{returning}",
      values
    )
  end

  @doc """
  Actualiza registros en una tabla de PostgreSQL.

  ## Parámetros

  - `table_name`: Nombre de la tabla
  - `updates`: Mapa con columnas y valores a actualizar
  - `conditions`: Mapa con condiciones para la cláusula WHERE
  - `returning`: Columnas a devolver (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.update("users", %{name: "Jane"}, %{id: 1}, "id, name")
      {:ok, %Postgrex.Result{...}}

  """
  def update(table_name, updates, conditions, returning \\ "*") do
    {update_cols, update_vals} = map_to_cols_vals(updates, 1)
    {where_cols, where_vals} = map_to_cols_vals(conditions, length(update_vals) + 1)
    
    query(
      "UPDATE #{table_name} SET #{update_cols} WHERE #{where_cols} RETURNING #{returning}",
      update_vals ++ where_vals
    )
  end

  @doc """
  Elimina registros de una tabla de PostgreSQL.

  ## Parámetros

  - `table_name`: Nombre de la tabla
  - `conditions`: Mapa con condiciones para la cláusula WHERE
  - `returning`: Columnas a devolver (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.delete("users", %{id: 1}, "id, name")
      {:ok, %Postgrex.Result{...}}

  """
  def delete(table_name, conditions, returning \\ "*") do
    {where_cols, where_vals} = map_to_cols_vals(conditions, 1)
    
    query(
      "DELETE FROM #{table_name} WHERE #{where_cols} RETURNING #{returning}",
      where_vals
    )
  end

  @doc """
  Selecciona registros de una tabla de PostgreSQL.

  ## Parámetros

  - `table_name`: Nombre de la tabla
  - `columns`: Columnas a seleccionar (opcional, por defecto "*")
  - `conditions`: Mapa con condiciones para la cláusula WHERE (opcional)
  - `opts`: Opciones adicionales como order_by, limit, offset (opcional)

  ## Ejemplos

      iex> Hashpay.Postgres.select("users", ["id", "name"], %{active: true}, %{order_by: "id DESC", limit: 10})
      {:ok, %Postgrex.Result{...}}

  """
  def select(table_name, columns \\ "*", conditions \\ nil, opts \\ %{}) do
    columns_str = if is_list(columns), do: Enum.join(columns, ", "), else: columns
    
    {where_clause, params} = if conditions do
      {where_cols, where_vals} = map_to_cols_vals(conditions, 1)
      {" WHERE #{where_cols}", where_vals}
    else
      {"", []}
    end
    
    order_by = if Map.has_key?(opts, :order_by), do: " ORDER BY #{opts.order_by}", else: ""
    limit = if Map.has_key?(opts, :limit), do: " LIMIT #{opts.limit}", else: ""
    offset = if Map.has_key?(opts, :offset), do: " OFFSET #{opts.offset}", else: ""
    
    query(
      "SELECT #{columns_str} FROM #{table_name}#{where_clause}#{order_by}#{limit}#{offset}",
      params
    )
  end

  # Función auxiliar para convertir un mapa en columnas y valores para consultas SQL
  defp map_to_cols_vals(map, start_index) do
    {cols, vals} =
      map
      |> Enum.with_index(start_index)
      |> Enum.reduce({[], []}, fn {{col, val}, idx}, {cols_acc, vals_acc} ->
        {[~s(#{col} = $#{idx}) | cols_acc], [val | vals_acc]}
      end)
    
    {Enum.reverse(cols) |> Enum.join(" AND "), Enum.reverse(vals)}
  end
end
