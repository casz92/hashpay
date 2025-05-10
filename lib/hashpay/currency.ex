defmodule Hashpay.Currency do
  @moduledoc """
  Estructura y funciones para las monedas de la blockchain de Hashpay.

  Una moneda contiene:
  - id: Identificador único de la moneda
  - name: Nombre de la moneda
  - pubkey: Clave pública del propietario de la moneda
  - picture: URL de la imagen de la moneda
  - decimals: Número de decimales de la moneda
  - symbol: Símbolo de la moneda
  - max_supply: Suministro máximo de la moneda
  - props: Propiedades adicionales de la moneda
  - creation: Marca de tiempo de creación de la moneda
  - updated: Marca de tiempo de última actualización de la moneda
  """
  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          pubkey: binary() | nil,
          picture: String.t() | nil,
          decimals: non_neg_integer(),
          symbol: String.t(),
          max_supply: non_neg_integer(),
          creation: non_neg_integer(),
          updated: non_neg_integer()
        }

  defstruct [
    :id,
    :name,
    :pubkey,
    :picture,
    :decimals,
    :symbol,
    :max_supply,
    :creation,
    :updated
  ]

  alias Hashpay.Property

  @prefix "cu_"
  # @regex ~r/^(cu_)[A-Z]{1,5}$/
  @regex_name ~r/^[A-Z]{1,5}$/
  @trdb :currencies
  @default_currency Application.compile_env(:hashpay, :default_currency)

  def match?(<<@prefix, _::binary>>), do: true
  def match?(_), do: false

  def match_name?(name) do
    Regex.match?(@regex_name, name)
  end

  def ticker(<<@prefix, ticker::binary>>), do: ticker

  def generate_id(id) do
    [@prefix, id] |> IO.iodata_to_binary()
  end

  def new(
        attrs = %{
          "id" => id,
          "name" => name,
          "pubkey" => pubkey,
          "decimals" => decimals,
          "symbol" => symbol,
          "max_supply" => max_supply
        }
      ) do
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(id),
      name: name,
      pubkey: Base.decode64!(pubkey),
      picture: Map.get(attrs, "picture", nil),
      decimals: decimals,
      symbol: symbol,
      max_supply: max_supply,
      creation: last_round_id,
      updated: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"currencies",
      exp: false
    ]
  end

  def init(tr) do
    if exists?(tr, @default_currency) do
      default =
        %{
          "ticker" => @default_currency,
          "name" => "Hashpay",
          "pubkey" => nil,
          "decimals" => 6,
          "symbol" => "ℏ",
          "max_supply" => 500_000_000_000_000_000_000
        }
        |> new()

      ThunderRAM.put(tr, @trdb, default.id, default)

      Property.put(tr, default.id, %{
        "mint" => true,
        "burn" => true,
        "frozen" => true,
        "payday" => 100,
        "min_payday_withdrawal_amount" => 100,
        "payday_period" => 172_800,
        "payday_max_to_claim" => 60,
        "paystream_withdrawal_fee" => 0.01
      })
    end
  end

  def get(tr, id) do
    ThunderRAM.get(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = currency) do
    ThunderRAM.put(tr, @trdb, currency.id, currency)
  end

  def exists?(tr, id) do
    ThunderRAM.exists?(tr, @trdb, id)
  end

  def merge(tr, id, attrs) do
    case get(tr, id) do
      {:ok, currency} ->
        currency = Map.merge(currency, struct(__MODULE__, attrs))
        ThunderRAM.put(tr, @trdb, currency.id, currency)

      _ ->
        {:error, :not_found}
    end
  end

  def delete(tr, %__MODULE__{} = currency) do
    ThunderRAM.delete(tr, @trdb, currency.id)
  end

  def delete(tr, id) do
    ThunderRAM.delete(tr, @trdb, id)
  end
end
