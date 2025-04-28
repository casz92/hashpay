defmodule Hashpay.Blockfile do
  def encode(txs) do
    CBOR.encode(%{"txs" => txs, "vsn" => 1})
  end

  def decode!(encoded_block) do
    case CBOR.decode(encoded_block) do
      {:ok, decoded_block, _rest} -> decoded_block
      {:error, reason} -> raise "Failed to decode block: #{inspect(reason)}"
    end
  end

  def save(encoded_block, block_id) do
    path = pathfile(block_id)
    File.write!(path, encoded_block)
  end

  def upload(block_id) do
    path = pathfile(block_id)
    S3Client.upload_file(path, "blocks/#{block_id}.cbor")
  end

  def donwload(block_id) do
    url = remote_url(block_id)

    case Download.from(url, pathfile(block_id)) do
      {:ok, _} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  def remote_url(block_id) do
    [
      "https://",
      Application.get_env(:hashpay, :s3_bucket, "my-bucket"),
      ".s3.amazonaws.com",
      "/blocks/",
      block_id,
      ".cbor"
    ]
    |> IO.iodata_to_binary()
  end

  defp pathfile(block_id) do
    folder = Application.get_env(:hashpay, :block_folder, "blocks")

    [
      folder,
      "#{block_id}.cbor"
    ]
    |> Path.join()
  end
end
