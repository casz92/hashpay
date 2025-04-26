defmodule Hashpay do
  @moduledoc """
  Documentation for `Hashpay`.
  """
  alias Hashpay.Variable

  def gen_id do
    time =
      :os.system_time(:second)

    [
      :binary.encode_unsigned(time),
      :rand.bytes(8)
    ]
    |> IO.iodata_to_binary()
    |> Base62.encode()
  end

  def gen_id(prefix) do
    time =
      :os.system_time(:second)

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
      :os.system_time(:second)

    tail =
      [
        :binary.encode_unsigned(time),
        :crypto.hash(:sha256, pubkey) |> :binary.part(0, 20)
      ]
      |> IO.iodata_to_binary()
      |> Base62.encode()

    IO.iodata_to_binary(["ac_", tail])
  end

  @doc """
  Calcula la tarifa de una transacción basado en sus atributos.
  Devuelve un entero representa las tarifas de la transacción.
  """
  def calc_fee(amount, a, b) do
    trunc(amount * a * Variable.get_factor_a() + b + Variable.get_factor_b())
  end
end
