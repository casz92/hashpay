defmodule Hashpay.Serializable do
  @moduledoc """
  Behaviour y funciones para serialización y deserialización de estructuras.

  Este módulo define un behaviour que deben implementar las estructuras
  que quieran ser serializables a diferentes formatos como mapas, CBOR y JSON.

  También proporciona funciones de utilidad para facilitar la implementación.
  """

  @doc """
  Callback para convertir una estructura a un mapa.
  """
  @callback to_map(struct :: struct()) :: map()

  @doc """
  Callback para convertir un mapa a una estructura.
  """
  @callback from_map(map :: map()) :: struct()

  @doc """
  Callback para serializar una estructura a formato CBOR.
  """
  @callback to_cbor(struct :: struct()) :: binary()

  @doc """
  Callback para deserializar datos CBOR a una estructura.
  """
  @callback from_cbor(cbor_data :: binary()) :: struct()

  @doc """
  Callback para serializar una estructura a formato JSON.
  """
  @callback to_json(struct :: struct()) :: String.t()

  @doc """
  Callback para deserializar datos JSON a una estructura.
  """
  @callback from_json(json_data :: String.t()) :: struct()

  @doc """
  Convierte una estructura a un mapa para serialización.

  ## Parámetros

  - `struct`: La estructura a convertir

  ## Retorno

  Un mapa con los campos de la estructura
  """
  def to_map(struct) do
    Map.from_struct(struct)
  end

  @doc """
  Convierte un mapa a una estructura específica.

  ## Parámetros

  - `map`: El mapa a convertir
  - `module`: El módulo de la estructura destino

  ## Retorno

  Una estructura del tipo especificado
  """
  def from_map(map, module) when is_map(map) and is_atom(module) do
    # Convertir claves string a átomos si es necesario
    map = if map_has_string_keys?(map), do: string_keys_to_atoms(map), else: map
    struct!(module, map)
  end

  @doc """
  Verifica si un mapa tiene claves de tipo string.
  """
  def map_has_string_keys?(map) when is_map(map) and map_size(map) > 0 do
    map
    |> Map.keys()
    |> hd()
    |> is_binary()
  end

  def map_has_string_keys?(_), do: false

  @doc """
  Convierte las claves string de un mapa a átomos.

  ## Advertencia

  Esta función debe usarse con precaución ya que convertir strings a átomos
  de forma dinámica puede llevar a fugas de memoria si se usa con datos no confiables.
  """
  def string_keys_to_atoms(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {String.to_atom(k), v} end)
  end

  @doc """
  Serializa una estructura a formato CBOR.

  ## Parámetros

  - `struct`: La estructura a serializar

  ## Retorno

  Datos en formato CBOR (binario)
  """
  def to_cbor(struct) do
    struct
    |> to_map()
    |> CBOR.encode()
  end

  @doc """
  Deserializa datos CBOR a una estructura específica.

  ## Parámetros

  - `cbor_data`: Los datos CBOR a deserializar
  - `module`: El módulo de la estructura destino

  ## Retorno

  Una estructura del tipo especificado
  """
  def from_cbor(cbor_data, module) when is_atom(module) do
    result =
      cbor_data
      |> CBOR.decode()

    :erlang.element(2, result)
    |> from_map(module)
  end

  @doc """
  Serializa una estructura a formato JSON.

  ## Parámetros

  - `struct`: La estructura a serializar

  ## Retorno

  String en formato JSON
  """
  def to_json(struct) do
    struct
    |> to_map()
    |> Jason.encode!()
  end

  @doc """
  Deserializa datos JSON a una estructura específica.

  ## Parámetros

  - `json_data`: Los datos JSON a deserializar
  - `module`: El módulo de la estructura destino

  ## Retorno

  Una estructura del tipo especificado
  """
  def from_json(json_data, module) when is_binary(json_data) and is_atom(module) do
    json_data
    |> Jason.decode!()
    |> from_map(module)
  end

  @doc """
  Macro para implementar el behaviour Serializable en un módulo.

  ## Ejemplo

      defmodule MyStruct do
        use Hashpay.Serializable
        defstruct [:field1, :field2]
      end
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour Hashpay.Serializable

      def to_map(struct), do: Hashpay.Serializable.to_map(struct)
      def from_map(map), do: Hashpay.Serializable.from_map(map, __MODULE__)
      def to_cbor(struct), do: Hashpay.Serializable.to_cbor(struct)
      def from_cbor(cbor_data), do: Hashpay.Serializable.from_cbor(cbor_data, __MODULE__)
      def to_json(struct), do: Hashpay.Serializable.to_json(struct)
      def from_json(json_data), do: Hashpay.Serializable.from_json(json_data, __MODULE__)

      defoverridable to_map: 1, from_map: 1, to_cbor: 1, from_cbor: 1, to_json: 1, from_json: 1
    end
  end
end
