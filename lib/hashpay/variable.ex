defmodule Hashpay.Variable do
  @moduledoc """
  Estructura y funciones para las variables globales de la blockchain de Hashpay.

  Variables globales:
  - round_rewarded_base: Cantidad recompenza base de Hashpay por ronda
  - round_rewarded_transactions: Cantidad de Hashpay recompensada por transacción
  - round_size_target: Cantidad de penalización por tamaño de ronda
  """
  @trdb :variables

  @compile {:inline, [put: 3, get: 1, get: 2, delete: 2]}

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

  def get_validator_creation_cost do
    :persistent_term.get({:var, "validator_creation_cost"}, 1_000_000)
  end

  def get_merchant_creation_cost do
    :persistent_term.get({:var, "merchant_creation_cost"}, 1_000_000)
  end

  def get_validator_withdrawal_fee do
    :persistent_term.get({:var, "validator_withdrawal_fee"}, 0.01)
  end

  def show_all do
    %{
      factor_a: get_factor_a(),
      factor_b: get_factor_b(),
      round_rewarded_base: get_round_rewarded_base(),
      round_rewarded_transactions: get_round_rewarded_transactions(),
      round_size_target: get_round_size_target(),
      currency_creation_cost: get_currency_creation_cost(),
      validator_creation_cost: get_validator_creation_cost(),
      merchant_creation_cost: get_merchant_creation_cost(),
      validator_withdrawal_fee: get_validator_withdrawal_fee()
    }
  end

  def init(tr) do
    case get("factor_a") do
      nil ->
        tr = ThunderRAM.new_batch(tr)
        ThunderRAM.put(tr, @trdb, "factor_a", 1)
        ThunderRAM.put(tr, @trdb, "factor_b", 0)
        ThunderRAM.put(tr, @trdb, "round_rewarded_base", 10)
        ThunderRAM.put(tr, @trdb, "round_rewarded_transactions", 0.1)
        ThunderRAM.put(tr, @trdb, "round_size_target", 0.05)
        ThunderRAM.put(tr, @trdb, "currency_creation_cost", 1_000_000_000)
        ThunderRAM.put(tr, @trdb, "validator_creation_cost", 5_000_000)
        ThunderRAM.put(tr, @trdb, "merchant_creation_cost", 10_000_000)
        ThunderRAM.put(tr, @trdb, "validator_withdrawal_fee", 0.005)
        ThunderRAM.sync(tr)

      _value ->
        :ignore
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

  def get(key) do
    :persistent_term.get({:var, key}, nil)
  end

  def get(key, default) do
    :persistent_term.get({:var, key}, default)
  end

  def put(tr, key, value) do
    is_valid =
      case key do
        "factor_a" -> is_integer(value)
        "factor_b" -> is_integer(value)
        "round_rewarded_base" -> is_integer(value)
        "round_rewarded_transactions" -> is_float(value)
        "round_size_target" -> is_float(value)
        "currency_creation_cost" -> is_number(value)
        "validator_creation_cost" -> is_number(value)
        "merchant_creation_cost" -> is_number(value)
        "validator_withdrawal_fee" -> is_float(value)
        _ -> true
      end

    if is_valid do
      :persistent_term.put({:var, key}, value)
      ThunderRAM.put(tr, @trdb, key, value)
    end
  end

  def delete(tr, key) do
    :persistent_term.erase({:var, key})
    ThunderRAM.delete(tr, @trdb, key)
  end
end
