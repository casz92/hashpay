defmodule Hashpay.Property do
  @moduledoc """
  Estructura y funciones para las propiedades de las entidades de la blockchain de Hashpay.
  """

  @trdb :properties

  def dbopts do
    [
      name: @trdb,
      exp: true
    ]
  end

  def get(tr, key) do
    case ThunderRAM.get(tr, @trdb, key) do
      nil -> nil
      props -> props
    end
  end

  def get(tr, key, name, default \\ nil) do
    case ThunderRAM.get(tr, @trdb, key) do
      nil ->
        default

      props ->
        Map.get(props, name, nil)
    end
  end

  def put(tr, key, value) do
    ThunderRAM.put(tr, @trdb, key, value)
  end

  def put(tr, key, name, value) do
    case get(tr, key) do
      nil ->
        ThunderRAM.put(tr, @trdb, key, %{name => value})

      props ->
        props = Map.put(props, name, value)
        ThunderRAM.put(tr, @trdb, key, props)
    end
  end

  def exists?(tr, key) do
    ThunderRAM.exists?(tr, @trdb, key)
  end

  def exists?(tr, id, name) do
    case get(tr, id) do
      nil ->
        false

      props ->
        Map.has_key?(props, name)
    end
  end

  def delete(tr, key) do
    ThunderRAM.delete(tr, @trdb, key)
  end

  def delete(tr, id, name) do
    case get(tr, id) do
      nil ->
        nil

      props ->
        props = Map.delete(props, name)

        if map_size(props) == 0 do
          ThunderRAM.delete(tr, @trdb, id)
        else
          ThunderRAM.put(tr, @trdb, id, props)
        end
    end
  end
end
