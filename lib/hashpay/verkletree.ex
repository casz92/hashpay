defmodule VerkleTree do
  defstruct root: nil, nodes: %{}, commitments: %{}

  def new(), do: %VerkleTree{}

  def insert(tree, key, value) do
    commitment = polynomial_commitment(key, value)
    nodes = Map.put(tree.nodes, key, value)
    commitments = Map.put(tree.commitments, key, commitment)
    %{tree | nodes: nodes, commitments: commitments}
  end

  defp polynomial_commitment(key, value) do
    key_int = :erlang.phash2(key)
    value_int = :erlang.phash2(value)

    # Simulación de compromiso polinomial (puede ser mejorado con IPA Commitments)
    commitment = rem(key_int * value_int + key_int + value_int, 101)

    commitment
  end

  def compute_root(tree) do
    commitments = Enum.map(tree.commitments, fn {_key, value} -> value end)
    root_commitment = compute_digest(commitments)

    %{tree | root: root_commitment}
  end

  defp compute_digest(commitments) do
    joined_commitments =
      commitments
      |> Enum.join("-")

    :crypto.hash(:sha256, joined_commitments)
  end
end

defmodule VerkleProof do
  def generate_proof(tree, key) do
    Map.get(tree.commitments, key)
  end

  def verify_proof(tree, key, expected_commitment) do
    Map.get(tree.commitments, key) == expected_commitment
  end
end
