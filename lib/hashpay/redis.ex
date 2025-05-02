defmodule Hashpay.Redis do
  require Logger
  @type value :: String.t() | integer() | float()
  @type response :: {:ok, term()} | {:error, term()}

  @module_name Module.split(__MODULE__) |> Enum.join(".")

  def child_spec(opts) do
    name = Keyword.get(opts, :name, __MODULE__)

    %{
      id: name,
      start: {__MODULE__, :start_link, [name, Keyword.delete(opts, :name)]}
    }
  end

  def start_link(name, opts) do
    with {:ok, conn} <- :eredis.start_link(opts) do
      put_conn(name, conn)
      Logger.debug("Running #{@module_name}:#{name} ✅")
      {:ok, conn}
    else
      ex ->
        Logger.debug("Running #{@module_name}:#{name} ❌")
        ex
    end
  end

  def conn(name) do
    :persistent_term.get(name)
  end

  defp put_conn(name, conn) do
    :persistent_term.put(name, conn)
  end

  @spec fetch(db :: atom(), key :: String.t()) :: {:ok, value()} | {:error, term()}
  def fetch(db, key) do
    :eredis.q(conn(db), ["GET", key])
  end

  @spec get(db :: atom(), key :: String.t()) :: value()
  def get(db, key) do
    :eredis.q(conn(db), ["GET", key])
    |> catch_result()
  end

  def get_integer(db, key) do
    case :eredis.q(conn(db), ["GET", key]) do
      {:ok, :undefined} ->
        nil

      {:ok, x} ->
        :erlang.binary_to_integer(x)

      err ->
        err
    end
  end

  def get_float(db, key) do
    case :eredis.q(conn(db), ["GET", key]) do
      {:ok, :undefined} ->
        nil

      {:ok, x} ->
        :erlang.binary_to_float(x)

      err ->
        err
    end
  end

  @spec getdel(db :: atom(), key :: String.t()) :: response()
  def getdel(db, key) do
    :eredis.q(conn(db), ["GETDEL", key])
    |> catch_result()
  end

  @spec set(db :: atom(), key :: String.t(), value :: value()) :: :ok | :error
  def set(db, key, value) when is_integer(value) do
    :eredis.q(conn(db), ["SET", key, Integer.to_string(value)])
    |> catch_status()
  end

  def set(db, key, value) when is_float(value) do
    :eredis.q(conn(db), ["SET", key, Float.to_string(value)])
    |> catch_status()
  end

  def set(db, key, value) do
    :eredis.q(conn(db), ["SET", key, value])
    |> catch_status()
  end

  @spec setEx(db :: atom(), key :: String.t(), value :: value(), expiry_seconds :: integer()) ::
          :ok | :error
  def setEx(db, key, value, expiry_seconds) when is_integer(value) do
    :eredis.q(conn(db), [
      "SETEX",
      key,
      Integer.to_string(expiry_seconds),
      Integer.to_string(value)
    ])
    |> catch_status()
  end

  def setEx(db, key, value, expiry) when is_float(value) do
    :eredis.q(conn(db), ["SETEX", key, Integer.to_string(expiry), Float.to_string(value)])
    |> catch_status()
  end

  def setEx(db, key, value, expiry) do
    :eredis.q(conn(db), ["SETEX", key, Integer.to_string(expiry), value])
    |> catch_status()
  end

  @spec del(atom(), list() | String.t()) :: term()
  def del(db, keys) when is_list(keys) do
    case :eredis.q(conn(db), ["DEL" | keys]) do
      {:ok, n} -> String.to_integer(n)
      _ -> 0
    end
  end

  @spec del(atom(), String.t()) :: integer()
  def del(db, key) do
    case :eredis.q(conn(db), ["DEL", key]) do
      {:ok, n} -> String.to_integer(n)
      _ -> 0
    end
  end

  def exists?(db, key) do
    case :eredis.q(conn(db), ["EXISTS", key]) do
      {:ok, "1"} -> true
      _ -> false
    end
  end

  @spec incr(atom(), String.t(), integer()) :: integer() | {:error, term()}
  def incr(db, key, num) do
    case :eredis.q(conn(db), ["INCRBY", key, num]) do
      {:ok, n} -> String.to_integer(n)
      err -> err
    end
  end

  # defp empty!({:ok, :undefined}), do: raise(ArgumentError, "Redis undefined variable")
  # defp empty!({:ok, result}), do: result
  # defp empty!({:error, _}), do: raise(ArgumentError, "Redis connection")

  defp catch_status({:ok, _}), do: :ok
  defp catch_status({:error, x}) do

  IO.inspect(x)
    :error
  end

  defp catch_result({:ok, :undefined}), do: nil
  defp catch_result({:ok, result}), do: result
  defp catch_result({:error, _}), do: :error

  def stop(db) do
    :eredis.stop(conn(db))
  end
end
