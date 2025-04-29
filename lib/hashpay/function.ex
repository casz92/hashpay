defmodule Hashpay.Function do
  @moduledoc """
  Estructura para las funciones de la blockchain de Hashpay.

   Una función contiene:
   - id: Identificador único de la función
   - name: Nombre de la función
   - mod: Módulo que contiene la función
   - fun: Nombre de la función
   - auth_type: Tipo de autenticación requerida
   - segment: Segmento de la blockchain donde se ejecuta la función
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
    cost: 0,
    segment: 0
  ]

  @type t :: %__MODULE__{
          id: pos_integer(),
          name: String.t(),
          mod: module(),
          fun: atom(),
          auth_type: 0 | 1,
          cost: non_neg_integer(),
          segment: non_neg_integer()
        }
end

defmodule Hashpay.Function.Context do
  alias Hashpay.Merchant
  alias Hashpay.{Command, Account, Block, Round, DB}
  alias Hashpay.Function.Context

  defstruct [
    :cmd,
    :fun,
    :sender,
    :db,
    :batch,
    :block,
    :round
  ]

  @type t :: %__MODULE__{
          cmd: Command.t(),
          fun: Hashpay.Function.t(),
          sender: Account.t() | Merchant.t() | nil,
          db: pid(),
          batch: Xandra.Batch.t(),
          block: Block.t() | nil,
          round: Round.t() | nil
        }

  def new(cmd, fun, sender) do
    new(DB.get_conn(), cmd, fun, sender)
  end

  def new(conn, cmd, fun, sender) do
    %Context{
      cmd: cmd,
      fun: fun,
      sender: sender,
      db: conn,
      batch: DB.get_batch()
    }
  end
end
