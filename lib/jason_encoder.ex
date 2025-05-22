defimpl Jason.Encoder, for: Hashpay.Block do
  def encode(%Hashpay.Block{hash: hash, prev: prev, signature: signature} = map, opts) do
    map =
      map
      |> Map.put(:hash, Util.encode16(hash))
      |> Map.put(:prev, Util.encode16(prev))
      |> Map.put(:signature, Util.encode64(signature))
      |> Map.delete(:__struct__)

    Jason.Encode.map(map, opts)
  end
end

defimpl Jason.Encoder, for: Hashpay.Round do
  def encode(
        %Hashpay.Round{hash: hash, prev: prev, signature: signature, blocks: blocks} = map,
        opts
      ) do
    map =
      map
      |> Map.put(:hash, Util.encode16(hash))
      |> Map.put(:prev, Util.encode16(prev))
      |> Map.put(:signature, Util.encode64(signature))
      |> Map.put(:blocks, hashes(blocks))
      |> Map.delete(:__struct__)

    Jason.Encode.map(map, opts)
  end

  defp hashes(nil), do: []
  defp hashes([]), do: []

  defp hashes(hashes) do
    Enum.map(hashes, &Base.encode16/1)
  end
end

defimpl Jason.Encoder,
  for: [Hashpay.Validator, Hashpay.Merchant, Hashpay.Account, Hashpay.Currency] do
  def encode(%{pubkey: pubkey} = map, opts) do
    map =
      map
      |> Map.put(:pubkey, Util.encode64(pubkey))
      |> Map.delete(:__struct__)

    Jason.Encode.map(map, opts)
  end
end
