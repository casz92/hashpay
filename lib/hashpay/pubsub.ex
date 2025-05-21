defmodule Hashpay.PubSub do
  @moduledoc """
  Módulo para manejar la publicación y suscripción de mensajes.
  Utiliza Phoenix.PubSub para implementar el patrón de publicación/suscripción.
  """
  @pubsub_name Hashpay.PubSub

  @doc """
  Inicia el servidor PubSub.
  """
  def start_link(_opts \\ []) do
    Phoenix.PubSub.Supervisor.start_link(name: @pubsub_name)
  end

  @doc """
  Implementación de child_spec para supervisores.
  """
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent,
      shutdown: 500
    }
  end

  @doc """
  Suscribe el proceso actual a un canal.
  """
  def subscribe(channel) do
    Phoenix.PubSub.subscribe(@pubsub_name, channel_name(channel))
  end

  @doc """
  Cancela la suscripción del proceso actual a un canal.
  """
  def unsubscribe(channel) do
    Phoenix.PubSub.unsubscribe(@pubsub_name, channel_name(channel))
  end

  @doc """
  Publica un mensaje en un canal.
  """
  def broadcast(channel, message) do
    Phoenix.PubSub.broadcast(@pubsub_name, channel_name(channel), message)
  end

  @doc """
  Publica un mensaje en un canal, excluyendo al proceso actual.
  """
  def broadcast_from(channel, message) do
    Phoenix.PubSub.broadcast_from(@pubsub_name, self(), channel_name(channel), message)
  end

  def broadcast_from(pid, channel, message) when is_pid(pid) do
    Phoenix.PubSub.broadcast_from(@pubsub_name, pid, channel_name(channel), message)
  end

  @doc """
  Publica un mensaje directo a un proceso específico.
  """
  def direct_message(pid, channel, message) when is_pid(pid) do
    Phoenix.PubSub.direct_broadcast(@pubsub_name, pid, channel_name(channel), message)
  end

  # Función auxiliar para normalizar los nombres de los canales
  defp channel_name(channel) when is_binary(channel), do: "channel:#{channel}"
  defp channel_name(channel), do: "channel:#{inspect(channel)}"
end
