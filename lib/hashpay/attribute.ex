defmodule Hashpay.Attribute do
  @moduledoc """
  Estructura y funciones para los atributos de las entidades de la blockchain de Hashpay.
  """

  @trdb :attributes

  def dbopts do
    [
      name: @trdb,
      exp: true
    ]
  end

  def get(tr, key) do
    case ThunderRAM.get(tr, @trdb, key) do
      nil -> nil
      attrs -> attrs
    end
  end

  def get(tr, key, name, default \\ nil) do
    case ThunderRAM.get(tr, @trdb, key) do
      nil ->
        default

      attrs ->
        Map.get(attrs, name, nil)
    end
  end

  def put(tr, key, value) do
    ThunderRAM.put(tr, @trdb, key, value)
  end

  def put(tr, key, name, value) do
    case get(tr, key) do
      nil ->
        ThunderRAM.put(tr, @trdb, key, %{name => value})

      attrs ->
        attrs = Map.put(attrs, name, value)
        ThunderRAM.put(tr, @trdb, key, attrs)
    end
  end

  def exists?(tr, key) do
    ThunderRAM.exists?(tr, @trdb, key)
  end

  def exists?(tr, id, name) do
    case get(tr, id) do
      nil ->
        false

      attrs ->
        Map.has_key?(attrs, name)
    end
  end

  def delete(tr, key) do
    ThunderRAM.delete(tr, @trdb, key)
  end

  def delete(tr, id, name) do
    case get(tr, id) do
      nil ->
        nil

      attrs ->
        attrs = Map.delete(attrs, name)

        if map_size(attrs) == 0 do
          ThunderRAM.delete(tr, @trdb, id)
        else
          ThunderRAM.put(tr, @trdb, id, attrs)
        end
    end
  end
end
