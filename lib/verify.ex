defmodule Verify do
  defguard is_par(number) when rem(number, 2) == 0
  defguard is_impar(number) when rem(number, 2) != 0
  defguard is_money_positive(number) when is_integer(number) and number > 0
  defguard valid_port?(number) when is_integer(number) and number >= 0 and number <= 65535
  defguard pubkey?(pubkey) when is_binary(pubkey) and byte_size(pubkey) == 32
  defguard pubkey64?(pubkey) when is_binary(pubkey) and byte_size(pubkey) in 32..44

  @domain_regex ~r/^(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$/
  @ipv4_regex ~r/^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$/
  @ipv6_regex ~r/^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))$/

  def domain?(domain) do
    Regex.match?(@domain_regex, domain)
  end

  def ipv4?(ip) do
    Regex.match?(@ipv4_regex, ip)
  end

  def ipv6?(ip) do
    Regex.match?(@ipv6_regex, ip)
  end

  def host?(host) do
    domain?(host) or ipv4?(host) or ipv6?(host)
  end
end
