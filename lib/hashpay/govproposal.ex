defmodule Hashpay.GovProposal do
  @moduledoc """
  Estructura y funciones para las propuestas de gobernabilidad de la blockchain de Hashpay.
  Una propuesta contiene:
  - id: Identificador único de la propuesta
  - title: Título de la propuesta
  - description: Descripción de la propuesta
  - proposer: Creador de la propuesta
  - status: Estado de la propuesta (0: pending, 1: passed, 2: exceuted, 3: rejected, 4: cancelled, 5: expired)
  - action: Nombre de la funcion que se ejecutara
  - action_args: Argumentos de la acción
  - start_time: Fecha de inicio de la propuesta
  - end_time: Fecha de finalización de la propuesta
  - creation: Marca de tiempo de creación de la propuesta
  - vsn: Versión de la propuesta
  """

  @type t :: %__MODULE__{
          id: String.t(),
          title: String.t(),
          description: String.t(),
          proposer: String.t(),
          status: 0 | 1 | 2 | 3 | 4,
          action: String.t(),
          action_args: list(),
          start_time: non_neg_integer(),
          end_time: non_neg_integer(),
          creation: non_neg_integer(),
          vsn: pos_integer()
        }

  defstruct [
    :id,
    :title,
    :description,
    :proposer,
    :action,
    :action_args,
    :start_time,
    :end_time,
    :creation,
    status: 0,
    vsn: 1
  ]

  @prefix "gprop_"
  # @regex ~r/^gprop_[a-zA-Z0-9]*$/
  @trdb :gproposals
  @max_end_time 2 * 3600 * 24 * 30

  def match?(<<@prefix, _::binary>>), do: true
  def match?(_), do: false

  def max_end_time(current_round_id), do: current_round_id + @max_end_time

  def generate_id(tx_hash) do
    hash = Base62.encode(tx_hash)

    IO.iodata_to_binary([@prefix, hash])
  end

  def new(
        tx_hash,
        %{
          "title" => title,
          "description" => description,
          "proposer" => proposer,
          "action" => action,
          "action_args" => action_args,
          "start_time" => start_time,
          "end_time" => end_time
        }
      ) do
    last_round_id = Hashpay.get_last_round_id()

    %__MODULE__{
      id: generate_id(tx_hash),
      title: title,
      description: description,
      proposer: proposer,
      action: action,
      action_args: action_args,
      start_time: start_time,
      end_time: end_time,
      creation: last_round_id
    }
  end

  def dbopts do
    [
      name: @trdb,
      handle: ~c"gproposals",
      exp: true
    ]
  end

  def fetch(tr, id) do
    ThunderRAM.fetch(tr, @trdb, id)
  end

  def put(tr, %__MODULE__{} = govproposal) do
    ThunderRAM.put(tr, @trdb, govproposal.id, govproposal)
  end

  def change_status(tr, govproposal = %__MODULE__{}, status) when status in [0, 1, 2, 3, 4] do
    ThunderRAM.put(tr, @trdb, govproposal.id, %{govproposal | status: status})
  end

  def cancel(tr, govproposal = %__MODULE__{}) do
    ThunderRAM.put(tr, @trdb, govproposal.id, %{govproposal | status: 3})
  end
end
