defmodule S3Client do
  @moduledoc """
  Cliente para interactuar con S3.

  usage:

  # Subir archivo
  S3Client.upload_file("path/to/file.png", "uploads/image.png")

  # Obtener URL presignada
  {:ok, url} = S3Client.get_file_url("uploads/image.png")
  IO.puts(url)

  # Listar archivos en el bucket
  IO.inspect(S3Client.list_files())

  # Eliminar archivo
  S3Client.delete_file("uploads/image.png")

  """
  alias ExAws.S3

  @bucket "my-bucket"

  # 🔹 Subir un archivo a S3
  def upload_file(path, key) do
    File.read!(path)
    |> S3.put_object(@bucket, key)
    |> ExAws.request()
  end

  # 🔹 Obtener un archivo desde S3
  def get_file_url(key) do
    ExAws.Config.new(:s3)
    |> S3.presigned_url(:get, @bucket, key)
  end

  # 🔹 Listar archivos en el bucket
  def list_files do
    S3.list_objects(@bucket)
    |> ExAws.request()
    |> Map.get(:body)
  end

  # 🔹 Eliminar un archivo de S3
  def delete_file(key) do
    S3.delete_object(@bucket, key)
    |> ExAws.request()
  end
end
