defmodule Hashpay do
  @moduledoc """
  Documentation for `Hashpay`.
  """
  alias Hashpay.Variable

  @type object_type ::
          :account
          | :block
          | :round
          | :tx
          | :merchant
          | :currency
          | :validator
          | :member
          | :balance
          | :holding
          | :plan
          | :payday
          | :lottery

  def gen_id do
    time =
      :os.system_time(:millisecond)

    [
      :binary.encode_unsigned(time),
      :rand.bytes(8)
    ]
    |> IO.iodata_to_binary()
    |> Base62.encode()
  end

  def gen_id(prefix) do
    time =
      :os.system_time(:millisecond)

    tail =
      [
        :binary.encode_unsigned(time),
        :rand.bytes(8)
      ]
      |> IO.iodata_to_binary()
      |> Base62.encode()

    IO.iodata_to_binary([prefix, tail])
  end

  def gen_address do
    {pubkey, privkey} = Cafezinho.Impl.generate()
    address = gen_address_from_pubkey(pubkey)
    {address, pubkey, privkey}
  end

  def gen_address_from_pubkey(pubkey) do
    time =
      :os.system_time(:millisecond)

    tail =
      [
        :binary.encode_unsigned(time),
        :crypto.hash(:sha256, pubkey) |> :binary.part(0, 20)
      ]
      |> IO.iodata_to_binary()
      |> Base62.encode()

    IO.iodata_to_binary(["ac_", tail])
  end

  def get_last_round_id do
    :persistent_term.get({:var, "last_round"}, 0)
  end

  def put_last_round_id(round_id) do
    :persistent_term.put({:var, "last_round"}, round_id)
  end

  @doc """
  Calcula la tarifa de una transacción basado en sus atributos.
  Devuelve un entero representa las tarifas de la transacción.
  """
  def calc_fee(amount, a, b) do
    trunc(amount * a * Variable.get_factor_a() + b + Variable.get_factor_b())
  end
end
