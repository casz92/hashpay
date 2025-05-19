defmodule Hashpay.Functions do
  alias Hashpay.Function

  @doc """
  Lista de funciones disponibles en la blockchain de Hashpay.
  Order commands: variable, account, balance/coins, currency, validator, merchant, member, holding, payday, paystream, plan, lottery
  """
  @functions [
    %Function{
      id: 1,
      name: "createAccount",
      mod: Hashpay.Account.Commands,
      fun: :create,
      auth_type: 0,
      thread: :type_and_args
    },
    %Function{
      id: 2,
      name: "changePubkeyAccount",
      mod: Hashpay.Account.Commands,
      fun: :change_pubkey,
      auth_type: 1
    },
    %Function{
      id: 3,
      name: "changeNameAccount",
      mod: Hashpay.Account.Commands,
      fun: :change_name,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 4,
      name: "changeChannelAccount",
      mod: Hashpay.Account.Commands,
      fun: :change_channel,
      auth_type: 1
    },
    %Function{
      id: 5,
      name: "deleteAccount",
      mod: Hashpay.Account.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 6,
      name: "verifyAccount",
      mod: Hashpay.Account.Commands,
      fun: :verify,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 100,
      name: "createCurrency",
      mod: Hashpay.Currency.Commands,
      fun: :create,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 101,
      name: "changeNameCurrency",
      mod: Hashpay.Currency.Commands,
      fun: :change_name,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 102,
      name: "changePubkeyCurrency",
      mod: Hashpay.Currency.Commands,
      fun: :change_pubkey,
      auth_type: 1
    },
    %Function{
      id: 103,
      name: "updateCurrency",
      mod: Hashpay.Currency.Commands,
      fun: :update,
      auth_type: 1
    },
    %Function{
      id: 104,
      name: "deleteCurrency",
      mod: Hashpay.Currency.Commands,
      fun: :delete,
      auth_type: 1
    },
    %Function{
      id: 200,
      name: "mintCoins",
      mod: Hashpay.Balance.Commands,
      fun: :mint,
      auth_type: 1,
      thread: :type
    },
    %Function{
      id: 201,
      name: "transferCoins",
      mod: Hashpay.Balance.Commands,
      fun: :transfer,
      auth_type: 1
    },
    %Function{
      id: 202,
      name: "frozenCoins",
      mod: Hashpay.Balance.Commands,
      fun: :frozen,
      auth_type: 1,
      thread: :type
    },
    %Function{
      id: 203,
      name: "unfrozenCoins",
      mod: Hashpay.Balance.Commands,
      fun: :unfrozen,
      auth_type: 1,
      thread: :type
    },
    %Function{
      id: 204,
      name: "burnCoins",
      mod: Hashpay.Balance.Commands,
      fun: :burn,
      auth_type: 1
    },
    %Function{
      id: 300,
      name: "createValidator",
      mod: Hashpay.Validator.Commands,
      fun: :create,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 301,
      name: "changeNameValidator",
      mod: Hashpay.Validator.Commands,
      fun: :change_name,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 302,
      name: "changePubkeyValidator",
      mod: Hashpay.Validator.Commands,
      fun: :change_pubkey,
      auth_type: 1
    },
    %Function{
      id: 303,
      name: "changeChannelValidator",
      mod: Hashpay.Validator.Commands,
      fun: :change_channel,
      auth_type: 1
    },
    %Function{
      id: 304,
      name: "updateValidator",
      mod: Hashpay.Validator.Commands,
      fun: :update,
      auth_type: 1
    },
    %Function{
      id: 305,
      name: "deleteValidator",
      mod: Hashpay.Validator.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 306,
      name: "withdrawValidator",
      mod: Hashpay.Validator.Commands,
      fun: :withdraw,
      auth_type: 1
    },
    %Function{
      id: 400,
      name: "createMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :create,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 401,
      name: "changeNameMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :change_name,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 402,
      name: "changePubkeyMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :change_pubkey,
      auth_type: 1
    },
    %Function{
      id: 403,
      name: "changeChannelMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :change_channel,
      auth_type: 1
    },
    %Function{
      id: 404,
      name: "updateMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :update,
      auth_type: 1
    },
    %Function{
      id: 405,
      name: "deleteMerchant",
      mod: Hashpay.Merchant.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 500,
      name: "addMember",
      mod: Hashpay.Member.Commands,
      fun: :create,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 501,
      name: "removeMember",
      mod: Hashpay.Member.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 600,
      name: "startHolding",
      mod: Hashpay.Holding.Commands,
      fun: :start_holding,
      auth_type: 1
    },
    %Function{
      id: 601,
      name: "endHolding",
      mod: Hashpay.Holding.Commands,
      fun: :end_holding,
      auth_type: 1
    },
    %Function{
      id: 700,
      name: "createPlan",
      mod: Hashpay.Plan.Commands,
      fun: :create,
      auth_type: 1
    },
    %Function{
      id: 701,
      name: "updatePlan",
      mod: Hashpay.Plan.Commands,
      fun: :update,
      auth_type: 1
    },
    %Function{
      id: 702,
      name: "deletePlan",
      mod: Hashpay.Plan.Commands,
      fun: :delete,
      auth_type: 1
    },
    %Function{
      id: 800,
      name: "createPayday",
      mod: Hashpay.Payday.Commands,
      fun: :create,
      auth_type: 1
    },
    %Function{
      id: 801,
      name: "claimPayday",
      mod: Hashpay.Payday.Commands,
      fun: :claim,
      auth_type: 1
    },
    %Function{
      id: 802,
      name: "withdrawPayday",
      mod: Hashpay.Payday.Commands,
      fun: :withdraw,
      auth_type: 1
    },
    %Function{
      id: 900,
      name: "sendPaystream",
      mod: Hashpay.Paystream.Commands,
      fun: :send,
      auth_type: 1
    },
    %Function{
      id: 901,
      name: "withdrawPaystream",
      mod: Hashpay.Paystream.Commands,
      fun: :withdraw,
      auth_type: 1
    },
    %Function{
      id: 1000,
      name: "createLottery",
      mod: Hashpay.Lottery.Commands,
      fun: :create,
      auth_type: 1
    },
    %Function{
      id: 1001,
      name: "buyLotteryTicket",
      mod: Hashpay.Lottery.Commands,
      fun: :buy_ticket,
      auth_type: 1
    },
    %Function{
      id: 1002,
      name: "claimLottery",
      mod: Hashpay.Lottery.Commands,
      fun: :claim,
      auth_type: 1
    },
    %Function{
      id: 1100,
      name: "setVariable",
      mod: Hashpay.Variable.Commands,
      fun: :set,
      auth_type: 1,
      thread: :type
    },
    %Function{
      id: 1101,
      name: "deleteVariable",
      mod: Hashpay.Variable.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :type
    },
    %Function{
      id: 1200,
      name: "setProp",
      mod: Hashpay.Property.Commands,
      fun: :set,
      auth_type: 1,
      thread: :args
    },
    %Function{
      id: 1201,
      name: "deleteProp",
      mod: Hashpay.Property.Commands,
      fun: :delete,
      auth_type: 1,
      thread: :args
    },
    %Function{
      id: 1300,
      name: "proposeGovernance",
      mod: Hashpay.GovProposal.Command,
      fun: :propose,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 1301,
      name: "voteGovernance",
      mod: Hashpay.GovProposal.Command,
      fun: :vote,
      auth_type: 1,
      thread: :type_and_args
    },
    %Function{
      id: 1302,
      name: "cancelGovernance",
      mod: Hashpay.GovProposal.Command,
      fun: :cancel,
      auth_type: 1,
      thread: :type_and_args
    }
  ]

  @funcs_by_id @functions |> Enum.map(fn func -> {func.id, func} end) |> Enum.into(%{})
  @funcs_by_name @functions |> Enum.map(fn func -> {func.name, func} end) |> Enum.into(%{})

  @spec get(pos_integer()) :: {:ok, Function.t()} | :error
  def get(id) do
    Map.fetch(@funcs_by_id, id)
  end

  @spec get_by_name(String.t()) :: {:ok, Function.t()} | :error
  def get_by_name(name) do
    Map.fetch(@funcs_by_name, name)
  end

  @spec list() :: [Function.t()]
  def list do
    @functions
  end
end
