defmodule Hashpay.Member do
  @moduledoc """
  Estructura y funciones para los miembros de la blockchain de Hashpay.

  Un miembro contiene:
  - group_id: Identificador del grupo al que pertenece el miembro
  - member_id: Identificador único del miembro
  - role: Rol del miembro en el grupo
  - creation: Marca de tiempo de creación del miembro
  - meta: Metadatos adicionales del miembro
  """
  @enforce_keys [
    :group_id,
    :member_id,
    :role
  ]

  defstruct [
    :group_id,
    :member_id,
    :role,
    :creation,
    :meta
  ]

  @type t :: %__MODULE__{
          group_id: String.t(),
          member_id: String.t(),
          role: String.t() | nil,
          creation: non_neg_integer(),
          meta: map() | nil
        }

  @trdb :members
  import ThunderRAM, only: [key_merge: 2]

  def new(group_id, member_id, role, meta \\ %{}) do
    %__MODULE__{
      group_id: group_id,
      member_id: member_id,
      role: role,
      creation: Hashpay.get_last_round_id(),
      meta: meta
    }
  end

  def dbopts do
    [
      name: @trdb,
      exp: true
    ]
  end

  def put(tr, %__MODULE__{group_id: group_id, member_id: member_id} = member) do
    key = key_merge(group_id, member_id)
    ThunderRAM.put(tr, @trdb, key, member)
  end

  def get(tr, group_id, member_id) do
    key = key_merge(group_id, member_id)
    ThunderRAM.fetch(tr, @trdb, key)
  end

  def exists?(tr, group_id, member_id) do
    key = key_merge(group_id, member_id)
    ThunderRAM.exists?(tr, @trdb, key)
  end

  def delete(tr, group_id, member_id) do
    key = key_merge(group_id, member_id)
    ThunderRAM.delete(tr, @trdb, key)
  end
end
