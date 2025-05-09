defmodule Hashpay.Property do
  @moduledoc """
  Estructura y funciones para las propiedades de las entidades de la blockchain de Hashpay.
  """

  @trdb :properties
  import ThunderRAM, only: [key_merge: 2]

  def dbopts do
    [
      name: @trdb,
      handle: ~c"properties",
      exp: true
    ]
  end

  def get(tr, key) do
    ThunderRAM.get(tr, @trdb, key)
  end

  def get(tr, id, name) do
    key = key_merge(id, name)
    ThunderRAM.get(tr, @trdb, key)
  end

  def put(tr, key, value) do
    ThunderRAM.put(tr, @trdb, key, value)
  end

  def put(tr, id, name, value) do
    key = key_merge(id, name)
    ThunderRAM.put(tr, @trdb, key, value)
  end

  def exists?(tr, key) do
    ThunderRAM.exists?(tr, @trdb, key)
  end

  def exists?(tr, id, name) do
    key = key_merge(id, name)
    ThunderRAM.exists?(tr, @trdb, key)
  end

  def delete(tr, key) do
    ThunderRAM.delete(tr, @trdb, key)
  end

  def delete(tr, id, name) do
    key = key_merge(id, name)
    ThunderRAM.delete(tr, @trdb, key)
  end
end
