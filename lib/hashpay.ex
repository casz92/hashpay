defmodule Hashpay do
  @moduledoc """
  Documentation for `Hashpay`.
  """
  alias Hashpay.Variable

  @type object_type ::
          :account
          | :block
          | :round
          | :currency
          | :balance
          | :validator
          | :merchant
          | :member
          | :plan
          | :holding
          | :payday
          | :lottery
          | :lottery_ticket
          | :paystream

  @compile {:inline, [hash: 1]}

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

  def hash(data) do
    Blake3.Native.hash(data)
  end

  def gen_address_from_pubkey(pubkey) do
    time =
      :os.system_time(:millisecond)

    tail =
      [
        :binary.encode_unsigned(time),
        hash(pubkey) |> :binary.part(0, 20)
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
  def compute_fees(amount) do
    trunc(amount * Variable.get_factor_a() + Variable.get_factor_b())
  end

  def compute_fees(amount, 1, b) do
    trunc(amount + b)
  end

  def compute_fees(amount, a, 0) do
    trunc(amount * a)
  end

  def compute_fees(amount, a, b) do
    trunc(amount * a + b)
  end
end
