defmodule Hashpay.Blockfile do
  @version 1
  @hash_module Blake3.Native

  def encode(commands) do
    CBOR.encode(%{"txs" => commands, "vsn" => @version})
  end

  def decode!(encoded_block) do
    case CBOR.decode(encoded_block) do
      {:ok, decoded_block, _rest} -> decoded_block
      {:error, reason} -> raise "Failed to decode block: #{inspect(reason)}"
    end
  end

  def build(block_id, commands) do
    encoded_block = encode(commands)
    save(encoded_block, block_id)
    # upload(block_id)
  end

  def save(encoded_block, block_id) do
    path = pathfile(block_id)
    File.write!(path, encoded_block)
  end

  def compute_hash(block_id) do
    path = pathfile(block_id)
    state = @hash_module.new()

    File.stream!(path, [], 2048)
    |> Enum.reduce(state, &@hash_module.update(&2, &1))
    |> @hash_module.finalize()
  end

  def upload(block_id) do
    path = pathfile(block_id)
    S3Client.upload_file(path, "blocks/#{block_id}.cbor")
  end

  def donwload(block_id) do
    url = remote_url(block_id)
    local_path = pathfile(block_id)

    case Download.from(url, path: local_path) do
      {:error, reason} -> {:error, reason}
      ok_url -> ok_url
    end
  end

  def remote_url(block_id) do
    [
      Application.get_env(:ex_aws, :s3_endpoint),
      "/blocks/",
      block_id,
      ".cbor"
    ]
    |> IO.iodata_to_binary()
  end

  defp pathfile(block_id) do
    folder = Application.get_env(:hashpay, :block_folder)

    [
      folder,
      "blocks",
      "#{block_id}.cbor"
    ]
    |> Path.join()
  end
end
