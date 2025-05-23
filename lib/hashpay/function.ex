defmodule Hashpay.Function do
  @moduledoc """
  Estructura para las funciones de la blockchain de Hashpay.

   Una función contiene:
   - id: Identificador único de la función
   - name: Nombre de la función
   - mod: Módulo que contiene la función
   - fun: Nombre de la función
   - auth_type: Tipo de autenticación requerida
   - thread: Thread de ejecución
   - cost: Costo de ejecución de la función

   auth_type: 0: ninguna, 1: firma digital

   segment: 0: blockchain, 1: offchain
  """

  defstruct [
    :id,
    :name,
    :mod,
    :fun,
    auth_type: 1,
    cost: 1,
    thread: :roundrobin
  ]

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          mod: module(),
          fun: atom(),
          auth_type: 0 | 1,
          cost: non_neg_integer(),
          thread: atom()
        }
end

defmodule Hashpay.Function.Context do
  @compile {:inline, [new: 5]}

  alias Hashpay.Merchant
  alias Hashpay.{Command, Account, Block, Round}
  alias Hashpay.Function.Context

  defstruct [
    :cmd,
    :fun,
    :sender,
    :sender_type,
    :db,
    :batch,
    :block,
    :round
  ]

  @type t :: %__MODULE__{
          cmd: Command.t(),
          fun: Hashpay.Function.t(),
          sender: Account.t() | Merchant.t() | nil,
          sender_type: Hashpay.object_type(),
          db: ThunderRAM.t(),
          # batch: Xandra.Batch.t(),
          block: Block.t() | nil,
          round: Round.t() | nil
        }

  def new(tr = %ThunderRAM{}, cmd, fun, sender, sender_type) do
    %Context{
      cmd: cmd,
      fun: fun,
      sender: sender,
      sender_type: sender_type,
      db: tr
    }
  end
end
