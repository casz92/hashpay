defmodule Hashpay.Governance.Proposal.Command do
  alias Hashpay.{Balance, Validator, Functions, Property}
  alias Hashpay.Governance.Proposal

  @min_end_time 2 * 3600
  @max_end_time 2 * 3600 * 24 * 30

  def propose(
        %{db: db, sender: %{id: sender_id}, cmd: %{hash: tx_hash}},
        attrs = %{
          "title" => title,
          "description" => description,
          "action" => action,
          "action_args" => action_args,
          "start_time" => start_time,
          "end_time" => end_time
        }
      )
      when (is_map(action_args) or is_list(action_args)) and
             is_binary(title) and byte_size(title) in 1..255 and
             is_binary(description) and byte_size(description) in 1..1024 and
             is_binary(action) and
             is_integer(start_time) and is_integer(end_time) do
    cond do
      end_time > @min_end_time ->
        {:error, "End date in the past"}

      end_time > @max_end_time ->
        {:error, "End date too far no more than #{@max_end_time} rounds"}

      action not in ["setVariable", "deleteVariable", "createValidator", "deleteValidator"] ->
        {:error, "Invalid action"}

      start_time > 0 ->
        {:error, "Invalid start time"}

      true ->
        case Functions.get_by_name(action) do
          {:ok, _function} ->
            proposal = Proposal.new(tx_hash, Map.put(attrs, "proposer", sender_id))
            Proposal.put(db, proposal)
            Property.put(db, proposal.id, "voters", MapSet.new())

          _ ->
            {:error, "Function not found"}
        end
    end
  end

  def propose(_ctx, _attrs), do: {:error, "Invalid arguments"}

  @doc """
  Vota por una propuesta.

  ## Parámetros

  - `ctx`: Contexto de la transacción
  - `vote`: Voto (0: yes, 1: no, 2: abstain)
  - `proposal_id`: Identificador de la propuesta

  ## Retorno

  - `:ok` si el voto se realizó correctamente
  - `{:error, reason}` si hay un error
  """
  def vote(ctx = %{db: db, sender: %{id: sender_id}}, %{
        "vote" => vote,
        "proposal_id" => proposal_id
      })
      when vote in [0, 1, 2] do
    props = Property.get(db, proposal_id)
    voters = Map.get(props, "voters")

    cond do
      is_nil(props) ->
        {:error, "Proposal not found"}

      MapSet.member?(voters, sender_id) ->
        {:error, "Already voted"}

      true ->
        case Proposal.get(db, proposal_id) do
          {:ok, %{status: status}} when status != 0 ->
            {:error, "Proposal already closed"}

          {:ok, proposal} ->
            new_voters = MapSet.put(voters, sender_id)
            Property.put(db, proposal_id, "voters", new_voters)
            result = Balance.incr(db, proposal_id, "#{vote}", 1)
            total = Validator.total(db)
            quorum = div(total, 2) + 1

            cond do
              vote == 0 and result >= quorum ->
                proposal = %{proposal | status: 2}
                Proposal.put(db, proposal)

                fun = Functions.get_by_name(proposal.action)
                apply(fun.mod, fun.fun, [ctx | proposal.action_args])

              vote == 1 and result >= quorum ->
                proposal = %{proposal | status: 3}
                Proposal.put(db, proposal)

              true ->
                :ok
            end

          _error ->
            {:error, "Proposal not found"}
        end
    end
  end

  def vote(_ctx, _attrs), do: {:error, "Invalid arguments"}

  def cancel(%{db: db, sender: %{id: sender_id}}, %{
        "proposal_id" => proposal_id
      }) do
    case Proposal.get(db, proposal_id) do
      {:ok, proposal} ->
        cond do
          proposal.status != 0 ->
            {:error, "Proposal already closed"}

          proposal.proposer != sender_id ->
            {:error, "Invalid sender"}

          true ->
            Proposal.change_status(db, proposal, 4)
        end

      _error ->
        {:error, "Proposal not found"}
    end
  end
end
