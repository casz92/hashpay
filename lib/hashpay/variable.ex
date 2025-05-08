defmodule Hashpay.Variable do
  @moduledoc """
  Estructura y funciones para las variables globales de la blockchain de Hashpay.

  Variables globales:
  - round_rewarded_base: Cantidad recompenza base de Hashpay por ronda
  - round_rewarded_transactions: Cantidad de Hashpay recompensada por transacción
  - round_size_target: Cantidad de penalización por tamaño de ronda
  """
  @trdb :variables

  @compile {:inline, [put: 3, get: 2, delete: 2]}

  defstruct [:key, :value]

  def get_factor_a do
    :persistent_term.get({:var, "factor_a"}, 1)
  end

  def get_factor_b do
    :persistent_term.get({:var, "factor_b"}, 0)
  end

  def get_round_rewarded_base do
    :persistent_term.get({:var, "round_rewarded_base"}, 10)
  end

  def get_round_rewarded_transactions do
    :persistent_term.get({:var, "round_rewarded_transactions"}, 0.1)
  end

  def get_round_size_target do
    :persistent_term.get({:var, "round_size_target"}, 0.05)
  end

  def get_currency_creation_cost do
    :persistent_term.get({:var, "currency_creation_cost"}, 1000)
  end

  def put_factor_a(tr, value) do
    :persistent_term.put({:var, "factor_a"}, value)
    ThunderRAM.put(tr, @trdb, "factor_a", value)
  end

  def put_factor_b(tr, value) do
    :persistent_term.put({:var, "factor_b"}, value)
    ThunderRAM.put(tr, @trdb, "factor_b", value)
  end

  def init(tr) do
    case get(tr, "factor_a") do
      {:ok, _value} ->
        :ignore

      _ ->
        tr = ThunderRAM.new_batch(tr)
        ThunderRAM.put(tr, @trdb, "factor_a", 1)
        ThunderRAM.put(tr, @trdb, "factor_b", 0)
        ThunderRAM.put(tr, @trdb, "round_rewarded_base", 10)
        ThunderRAM.put(tr, @trdb, "round_rewarded_transactions", 0.1)
        ThunderRAM.put(tr, @trdb, "round_size_target", 0.05)
        ThunderRAM.put(tr, @trdb, "currency_creation_cost", 1_000_000)
        ThunderRAM.sync(tr)
    end

    load_all(tr)
  end

  def load_all(tr) do
    ThunderRAM.foreach(tr, @trdb, fn key, value ->
      :persistent_term.put({:var, key}, value)
    end)
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"variables",
      exp: false
    ]
  end

  def get(tr, key) do
    ThunderRAM.get(tr, @trdb, key)
  end

  def put(tr, key, value) do
    ThunderRAM.put(tr, @trdb, key, value)
  end

  def delete(tr, key) do
    ThunderRAM.delete(tr, @trdb, key)
  end
end
