# defmodule Hashpay.Storable do
#   @moduledoc """
#   Behaviour para estructuras que pueden ser almacenadas en la base de datos.

#   Este módulo define un behaviour que deben implementar las estructuras
#   que quieran ser almacenadas en ScyllaDB. Define operaciones CRUD y
#   funciones para crear y eliminar tablas.
#   """

#   alias Hashpay.DB

#   @doc """
#   Callback para crear la tabla en la base de datos.
#   """
#   @callback create_table(conn :: pid(), keyspace :: String.t() | nil) ::
#               {:ok, term()} | {:error, term()}

#   @doc """
#   Callback para eliminar la tabla de la base de datos.
#   """
#   @callback drop_table(conn :: pid(), keyspace :: String.t() | nil) ::
#               {:ok, term()} | {:error, term()}

#   @doc """
#   Callback para guardar una estructura en la base de datos.
#   """
#   @callback save(conn :: pid(), struct :: struct()) :: {:ok, struct()} | {:error, term()}

#   @doc """
#   Callback para actualizar una estructura en la base de datos.
#   """
#   @callback update(conn :: pid(), struct :: struct()) :: {:ok, struct()} | {:error, term()}

#   @doc """
#   Callback para eliminar una estructura de la base de datos.
#   """
#   @callback delete(conn :: pid(), id :: term()) :: {:ok, term()} | {:error, term()}

#   @doc """
#   Callback para obtener una estructura por su ID.
#   """
#   @callback get(conn :: pid(), id :: term()) :: {:ok, struct()} | {:error, term()}

#   @doc """
#   Callback para obtener una estructura por su hash.
#   """
#   @callback get_by_hash(conn :: pid(), hash :: binary()) :: {:ok, struct()} | {:error, term()}

#   @doc """
#   Callback para obtener todas las estructuras que cumplen con ciertos parámetros.
#   """
#   @callback all(conn :: pid(), params :: map()) :: {:ok, [struct()]} | {:error, term()}

#   @doc """
#   Macro para implementar el behaviour Storable en un módulo.

#   ## Parámetros

#   - `opts`: Opciones para la implementación
#     - `:table_name`: Nombre de la tabla en la base de datos
#     - `:primary_key`: Campo que se usará como clave primaria
#     - `:fields`: Lista de campos con sus tipos para la tabla
#     - `:indices`: Lista de campos para crear índices

#   ## Ejemplo

#       defmodule MyStruct do
#         use Hashpay.Storable,
#           table_name: "my_structs",
#           primary_key: :id,
#           fields: [
#             id: "bigint",
#             name: "text",
#             value: "int"
#           ],
#           indices: [:name]

#         defstruct [:id, :name, :value]
#       end
#   """
#   defmacro __using__(opts) do
#     table_name = Keyword.get(opts, :table_name)
#     primary_key = Keyword.get(opts, :primary_key, :id)
#     fields = Keyword.get(opts, :fields, [])
#     indices = Keyword.get(opts, :indices, [])

#     quote do
#       @behaviour Hashpay.Storable

#       # Definir atributos del módulo
#       @table_name unquote(table_name) || raise("table_name is required")
#       @primary_key unquote(primary_key)
#       @fields unquote(fields)
#       @indices unquote(indices)

#       @doc """
#       Crea la tabla en la base de datos.
#       """
#       def create_table(conn, keyspace \\ nil) do
#         if keyspace do
#           DB.use_keyspace(conn, keyspace)
#         end

#         # Construir la definición de la tabla
#         fields_def =
#           Enum.map_join(@fields, ",\n      ", fn {field, type} -> "#{field} #{type}" end)

#         primary_key_def = "PRIMARY KEY (#{@primary_key})"

#         statement = """
#         CREATE TABLE IF NOT EXISTS #{@table_name} (
#           #{fields_def},
#           #{primary_key_def}
#         );
#         """

#         # Crear índices para búsquedas eficientes
#         indices =
#           Enum.map(@indices, fn field ->
#             "CREATE INDEX IF NOT EXISTS ON #{@table_name} (#{field});"
#           end)

#         with {:ok, _} <- DB.execute(conn, statement),
#              {:ok, _} <- create_indices(conn, indices) do
#           {:ok, :table_created}
#         end
#       end

#       defp create_indices(conn, indices) do
#         Enum.reduce_while(indices, {:ok, nil}, fn index, _acc ->
#           case DB.execute(conn, index) do
#             {:ok, result} -> {:cont, {:ok, result}}
#             error -> {:halt, error}
#           end
#         end)
#       end

#       @doc """
#       Elimina la tabla de la base de datos.
#       """
#       def drop_table(conn, keyspace \\ nil) do
#         if keyspace do
#           DB.use_keyspace(conn, keyspace)
#         end

#         statement = "DROP TABLE IF EXISTS #{@table_name};"
#         DB.execute(conn, statement)
#       end

#       @doc """
#       Guarda una estructura en la base de datos.
#       """
#       def save(conn, struct) do
#         # Extraer valores de los campos
#         values = Enum.map(@fields, fn {field, _} -> Map.get(struct, field) end)

#         # Construir placeholders para la consulta
#         placeholders = Enum.map_join(1..length(@fields), ", ", fn _ -> "?" end)

#         # Construir nombres de campos
#         field_names = Enum.map_join(@fields, ", ", fn {field, _} -> "#{field}" end)

#         statement = """
#         INSERT INTO #{@table_name} (#{field_names})
#         VALUES (#{placeholders});
#         """

#         # Construir parámetros con tipos
#         params = Enum.zip(Enum.map(@fields, fn {_, type} -> type end), values)

#         case DB.execute(conn, statement, params) do
#           {:ok, _} -> {:ok, struct}
#           error -> error
#         end
#       end

#       @doc """
#       Actualiza una estructura en la base de datos.
#       """
#       def update(conn, struct) do
#         # Extraer valores de los campos
#         values = Enum.map(@fields, fn {field, _} -> Map.get(struct, field) end)

#         # Construir cláusula SET
#         set_clause =
#           Enum.map_join(Enum.with_index(@fields), ", ", fn {{field, _}, i} ->
#             "#{field} = ?#{i + 1}"
#           end)

#         statement = """
#         UPDATE #{@table_name}
#         SET #{set_clause}
#         WHERE #{@primary_key} = ?;
#         """

#         # Construir parámetros con tipos
#         params = Enum.zip(Enum.map(@fields, fn {_, type} -> type end), values)
#         primary_key_value = Map.get(struct, @primary_key)
#         primary_key_type = Keyword.get(@fields, @primary_key)
#         params = params ++ [{primary_key_type, primary_key_value}]

#         case DB.execute(conn, statement, params) do
#           {:ok, _} -> {:ok, struct}
#           error -> error
#         end
#       end

#       @doc """
#       Elimina una estructura de la base de datos por su ID.
#       """
#       def delete(conn, id) do
#         statement = "DELETE FROM #{@table_name} WHERE #{@primary_key} = ?;"
#         primary_key_type = Keyword.get(@fields, @primary_key)
#         params = [{primary_key_type, id}]

#         DB.execute(conn, statement, params)
#       end

#       @doc """
#       Obtiene una estructura por su ID.
#       """
#       def get(conn, id) do
#         statement = "SELECT * FROM #{@table_name} WHERE #{@primary_key} = ? LIMIT 1;"
#         primary_key_type = Keyword.get(@fields, @primary_key)
#         params = [{primary_key_type, id}]

#         case DB.execute(conn, statement, params) do
#           {:ok, %Xandra.Page{} = page} ->
#             case Enum.to_list(page) do
#               [row] -> {:ok, row_to_struct(row)}
#               [] -> {:error, :not_found}
#               _ -> {:error, :multiple_results}
#             end

#           error ->
#             error
#         end
#       end

#       @doc """
#       Obtiene una estructura por su hash.
#       """
#       def get_by_hash(conn, hash) do
#         statement = "SELECT * FROM #{@table_name} WHERE hash = ? ALLOW FILTERING;"
#         params = [{"blob", hash}]

#         case DB.execute(conn, statement, params) do
#           {:ok, %Xandra.Page{} = page} ->
#             case Enum.to_list(page) do
#               [row] -> {:ok, row_to_struct(row)}
#               [] -> {:error, :not_found}
#               _ -> {:error, :multiple_results}
#             end

#           error ->
#             error
#         end
#       end

#       @doc """
#       Obtiene todas las estructuras que cumplen con ciertos parámetros.
#       """
#       def all(conn, params \\ %{}) do
#         {statement, query_params} = build_all_query(params)

#         case DB.execute(conn, statement, query_params) do
#           {:ok, %Xandra.Page{} = page} ->
#             structs = Enum.map(page, &row_to_struct/1)
#             {:ok, structs}

#           error ->
#             error
#         end
#       end

#       defp build_all_query(params) do
#         base_query = "SELECT * FROM #{@table_name}"
#         {where_clauses, query_params} = build_where_clauses(params)

#         statement =
#           if where_clauses == [] do
#             base_query
#           else
#             base_query <> " WHERE " <> Enum.join(where_clauses, " AND ")
#           end

#         statement =
#           if Map.has_key?(params, "limit") do
#             statement <> " LIMIT ?"
#           else
#             statement
#           end

#         query_params =
#           if Map.has_key?(params, "limit") do
#             query_params ++ [{"int", params.limit}]
#           else
#             query_params
#           end

#         {statement, query_params}
#       end

#       defp build_where_clauses(params) do
#         # Implementación específica para cada módulo
#         # Esta es una implementación básica que debe ser sobrescrita
#         {[], []}
#       end

#       defp row_to_struct(row) do
#         # Convertir una fila de la base de datos a una estructura
#         # Esta es una implementación básica que debe ser sobrescrita
#         fields = Enum.map(@fields, fn {field, _} -> {field, row[Atom.to_string(field)]} end)
#         struct!(__MODULE__, Map.new(fields))
#       end

#       # Permitir sobrescribir las funciones
#       defoverridable create_table: 2,
#                      drop_table: 2,
#                      save: 2,
#                      update: 2,
#                      delete: 2,
#                      get: 2,
#                      get_by_hash: 2,
#                      all: 2,
#                      build_where_clauses: 1,
#                      row_to_struct: 1
#     end
#   end
# end
