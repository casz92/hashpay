defmodule Hashpay.SystemInfo do
  alias Hashpay.Roundchain
  alias Hashpay.Variable
  alias Hashpay.Round
  alias Hashpay.Currency
  alias Hashpay.Validator

  @app :hashpay
  @default_channel Application.compile_env(@app, :default_channel)
  @default_currency Application.compile_env(@app, :default_currency)
  @round_time Application.compile_env(@app, :round_time)
  @round_timeout Application.compile_env(@app, :round_timeout)
  @env_keys ["S3_ENDPOINT", "HTTP_PORT", "HTTPS_PORT", "DATA_FOLDER", "REDIS_URL", "S3_BUCKET"]

  def get_info do
    %{
      roundchain: roundchain_callback(),
      disk_usage: disk_usage_callback(),
      system_info: info_callback()
    }
  end

  @doc false
  def roundchain_callback do
    tr = ThunderRAM.get_tr(:blockchain)
    pid = Process.whereis(Roundchain)
    status = Process.alive?(pid)

    last_round = Round.last(tr)

    validators =
      Validator.tab2list(tr)
      |> Enum.map(fn {_id, validator} -> validator end)

    total_validators = length(validators)

    currencies =
      Currency.tab2list(tr)
      |> Enum.map(fn {_id, currency} -> currency end)

    replicants =
      :ets.tab2list(:replicants)
      |> Enum.map(fn {id, _replicant} -> id end)

    total_currencies = length(currencies)

    %{
      active: status,
      round: last_round,
      blocks: last_round.blocks,
      validators: validators,
      total_validators: total_validators,
      currencies: currencies,
      total_currencies: total_currencies,
      default_channel: @default_channel,
      default_currency: @default_currency,
      round_time: @round_time,
      round_timeout: @round_timeout,
      vid: Application.get_env(@app, :id),
      replicants: replicants,
      variables: Variable.show_all()
    }
  end

  def disk_usage_callback do
    data_folder = Application.get_env(@app, :data_folder)
    blockchain_folder_size = Path.join(data_folder, "blockchain") |> FileUtils.folder_size()
    blocks_folder_size = Path.join(data_folder, "blocks") |> FileUtils.folder_size()

    %{
      blockchain: blockchain_folder_size,
      blocks: blocks_folder_size,
      total: blockchain_folder_size + blocks_folder_size
    }
  end

  @doc false
  def info_callback do
    %{
      system_info: %{
        system_version: :erlang.system_info(:version) |> String.Chars.to_string(),
        otp_version: :erlang.system_info(:otp_release) |> String.Chars.to_string(),
        elixir_version: System.version(),
        app_version: Application.spec(@app, :vsn) |> String.Chars.to_string(),
        cpu_count: :erlang.system_info(:schedulers_online)
      },
      net_info: %{
        hostname: :inet.gethostname() |> elem(1) |> String.Chars.to_string() ,
        ip_address:
          :inet.getifaddrs()
          |> elem(1)
          |> Enum.map(fn {_name, info} -> :inet.ntoa(info[:addr]) |> String.Chars.to_string() end)
      },
      os_info: os_callback(),
      system_limits: %{
        atoms: :erlang.system_info(:atom_limit),
        ports: :erlang.system_info(:port_limit),
        processes: :erlang.system_info(:process_limit)
      },
      system_usage: usage_callback(),
      environment: env_info_callback()
    }
  end

  @doc false
  def usage_callback do
    %{
      atoms: :erlang.system_info(:atom_count),
      ports: :erlang.system_info(:port_count),
      processes: :erlang.system_info(:process_count),
      io: io(),
      uptime: :erlang.statistics(:wall_clock) |> elem(0),
      memory: memory(),
      total_run_queue: :erlang.statistics(:total_run_queue_lengths_all),
      cpu_run_queue: :erlang.statistics(:total_run_queue_lengths)
    }
  end

  @doc false
  def env_info_callback do
    Enum.map(@env_keys, fn key -> {key, System.get_env(key)} end) |> Enum.into(%{})
  end

  def os_callback do
    {os_type, os_name} = :os.type()
    {major, minor, patch} = :os.version()
    os_verison = "#{major}.#{minor}.#{patch}"

    %{
      arch: :erlang.system_info(:system_architecture) |> String.Chars.to_string(),
      name: os_name,
      type: os_type,
      version: os_verison
    }
  end

  defp memory() do
    memory = :erlang.memory()
    total = memory[:total]
    process = memory[:processes]
    atom = memory[:atom]
    binary = memory[:binary]
    code = memory[:code]
    ets = memory[:ets]

    %{
      total: total,
      process: process,
      atom: atom,
      binary: binary,
      code: code,
      ets: ets,
      other: total - process - atom - binary - code - ets
    }
  end

  defp io do
    {{_input, input}, {_output, output}} = :erlang.statistics(:io)

    %{input: input, output: output}
  end
end
