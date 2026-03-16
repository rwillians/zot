defmodule Zot.Ip do
  @moduledoc """
  Standalone utility module for IP address and CIDR operations.

  Provides parsing, predicate checks, and network calculations for both
  IPv4 and IPv6 addresses. Accepts both string and `:inet` tuple
  representations where applicable.
  """

  import Bitwise, only: [band: 2, bor: 2, bsl: 2, bsr: 2, bxor: 2]

  # -- Types ---------------------------------------------------------

  @type ipv4_tuple :: {0..255, 0..255, 0..255, 0..255}
  @type ipv6_tuple :: {0..65535, 0..65535, 0..65535, 0..65535, 0..65535, 0..65535, 0..65535, 0..65535}
  @type ip_tuple :: ipv4_tuple | ipv6_tuple
  @type ip :: String.t()
  @type prefix :: non_neg_integer
  @type cidr_set :: :private | :loopback | :link_local

  # -- Predefined CIDR sets ------------------------------------------

  @private_cidrs ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"]
  @loopback_cidrs ["127.0.0.0/8", "::1/128"]
  @link_local_cidrs ["169.254.0.0/16", "fe80::/10"]

  @doc """
  Returns a list of CIDR strings for the given predefined set.

  ## Examples

      iex> Zot.Ip.cidrs(:private)
      ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"]

      iex> Zot.Ip.cidrs(:loopback)
      ["127.0.0.0/8", "::1/128"]

      iex> Zot.Ip.cidrs(:link_local)
      ["169.254.0.0/16", "fe80::/10"]

  """
  @spec cidrs(cidr_set) :: [String.t()]

  def cidrs(:private), do: @private_cidrs
  def cidrs(:loopback), do: @loopback_cidrs
  def cidrs(:link_local), do: @link_local_cidrs

  # -- Parsing -------------------------------------------------------

  @doc """
  Parses an IP address string into an `:inet` tuple.

  Wraps `:inet.parse_address/1`.

  ## Examples

      iex> Zot.Ip.parse_ip("192.168.1.1")
      {:ok, {192, 168, 1, 1}}

      iex> Zot.Ip.parse_ip("::1")
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}}

      iex> Zot.Ip.parse_ip("not_an_ip")
      :error

  """
  @spec parse_ip(String.t()) :: {:ok, ip_tuple} | :error

  def parse_ip(string) when is_binary(string) do
    case :inet.parse_address(String.to_charlist(string)) do
      {:ok, ip} -> {:ok, ip}
      {:error, _} -> :error
    end
  end

  @doc """
  Parses an IP address string into an `:inet` tuple, raising on failure.

  ## Examples

      iex> Zot.Ip.parse_ip!("10.0.0.1")
      {10, 0, 0, 1}

  """
  @spec parse_ip!(String.t()) :: ip_tuple

  def parse_ip!(string) when is_binary(string) do
    case parse_ip(string) do
      {:ok, ip} -> ip
      :error -> raise ArgumentError, "invalid IP address: #{inspect(string)}"
    end
  end

  @doc """
  Parses a CIDR string (e.g. `"192.168.0.0/24"`) into a tuple of
  `{ip_tuple, prefix_length}`.

  ## Examples

      iex> Zot.Ip.parse_cidr("192.168.0.0/24")
      {:ok, {{192, 168, 0, 0}, 24}}

      iex> Zot.Ip.parse_cidr("fc00::/7")
      {:ok, {{64512, 0, 0, 0, 0, 0, 0, 0}, 7}}

      iex> Zot.Ip.parse_cidr("garbage")
      :error

  """
  @spec parse_cidr(String.t()) :: {:ok, {ip_tuple, prefix}} | :error

  def parse_cidr(string) when is_binary(string) do
    with [ip_str, prefix_str] <- String.split(string, "/", parts: 2),
         {:ok, ip} <- parse_ip(ip_str),
         {prefix_len, ""} <- Integer.parse(prefix_str),
         true <- valid_prefix?(ip, prefix_len) do
      {:ok, {ip, prefix_len}}
    else
      _ -> :error
    end
  end

  @doc """
  Parses a CIDR string, raising on failure.

  ## Examples

      iex> Zot.Ip.parse_cidr!("10.0.0.0/8")
      {{10, 0, 0, 0}, 8}

  """
  @spec parse_cidr!(String.t()) :: {ip_tuple, prefix}

  def parse_cidr!(string) when is_binary(string) do
    case parse_cidr(string) do
      {:ok, result} -> result
      :error -> raise ArgumentError, "invalid CIDR: #{inspect(string)}"
    end
  end

  # -- Predicates ----------------------------------------------------

  @doc """
  Checks whether an IP address falls within a CIDR range, a list of CIDR
  ranges, or a predefined CIDR set.

  The IP can be given as a string or an `:inet` tuple.

  ## Examples

      iex> Zot.Ip.in_cidr?("10.0.0.1", "10.0.0.0/8")
      true

      iex> Zot.Ip.in_cidr?("10.0.0.1", ["10.0.0.0/8", "172.16.0.0/12"])
      true

      iex> Zot.Ip.in_cidr?("10.0.0.1", :private)
      true

      iex> Zot.Ip.in_cidr?("8.8.8.8", :private)
      false

  """
  @spec in_cidr?(ip | ip_tuple, String.t() | [String.t()] | cidr_set) :: boolean()

  def in_cidr?(ip, set) when is_atom(set) do
    in_cidr?(ip, cidrs(set))
  end

  def in_cidr?(ip, cidrs) when is_list(cidrs) do
    Enum.any?(cidrs, &in_cidr?(ip, &1))
  end

  def in_cidr?(ip, cidr) when is_binary(cidr) do
    {base, prefix_len} = parse_cidr!(cidr)

    ip_tuple = resolve_ip(ip)
    version = ip_version(ip_tuple)

    with true <- version == ip_version(base),
         mask <- mask(prefix_len, version),
         do: band(to_integer(ip_tuple), mask) == band(to_integer(base), mask)
  end

  @doc """
  Returns `true` if the IP address is in a private range.

  ## Examples

      iex> Zot.Ip.private?("192.168.1.1")
      true

      iex> Zot.Ip.private?("8.8.8.8")
      false

  """
  @spec private?(ip | ip_tuple) :: boolean()

  def private?(ip), do: in_cidr?(ip, :private)

  @doc """
  Returns `true` if the IP address is a loopback address.

  ## Examples

      iex> Zot.Ip.loopback?("127.0.0.1")
      true

      iex> Zot.Ip.loopback?({0, 0, 0, 0, 0, 0, 0, 1})
      true

  """
  @spec loopback?(ip | ip_tuple) :: boolean()

  def loopback?(ip), do: in_cidr?(ip, :loopback)

  @doc """
  Returns `true` if the IP address is a link-local address.

  ## Examples

      iex> Zot.Ip.link_local?("169.254.1.1")
      true

      iex> Zot.Ip.link_local?("10.0.0.1")
      false

  """
  @spec link_local?(ip | ip_tuple) :: boolean()

  def link_local?(ip), do: in_cidr?(ip, :link_local)

  # -- Network calculations ------------------------------------------

  @doc """
  Computes the network address for a given IP and prefix length.

  ## Examples

      iex> Zot.Ip.network_address({192, 168, 1, 130}, 24)
      {192, 168, 1, 0}

  """
  @spec network_address(ip_tuple, prefix) :: ip_tuple

  def network_address(ip_tuple, prefix_len) do
    version = ip_version(ip_tuple)
    m = mask(prefix_len, version)
    ip_int = to_integer(ip_tuple)

    from_integer(band(ip_int, m), version)
  end

  @doc """
  Computes the broadcast address for a given IP and prefix length.

  ## Examples

      iex> Zot.Ip.broadcast_address({192, 168, 1, 130}, 24)
      {192, 168, 1, 255}

  """
  @spec broadcast_address(ip_tuple, prefix) :: ip_tuple

  def broadcast_address(ip_tuple, prefix_len) do
    version = ip_version(ip_tuple)
    m = mask(prefix_len, version)
    ip_int = to_integer(ip_tuple)

    inverse =
      case version do
        :v4 -> bxor(m, 0xFFFFFFFF)
        :v6 -> bxor(m, bsl(1, 128) - 1)
      end

    from_integer(bor(band(ip_int, m), inverse), version)
  end

  # -- Private helpers -----------------------------------------------

  defp resolve_ip(ip) when is_binary(ip), do: parse_ip!(ip)
  defp resolve_ip(ip) when is_tuple(ip), do: ip

  defp ip_version({_, _, _, _}), do: :v4
  defp ip_version({_, _, _, _, _, _, _, _}), do: :v6

  defp valid_prefix?({_, _, _, _}, prefix) when prefix >= 0 and prefix <= 32, do: true
  defp valid_prefix?({_, _, _, _, _, _, _, _}, prefix) when prefix >= 0 and prefix <= 128, do: true
  defp valid_prefix?(_, _), do: false

  defp to_integer({a, b, c, d}) do
    bsl(a, 24)
    |> bor(bsl(b, 16))
    |> bor(bsl(c, 8))
    |> bor(d)
  end

  defp to_integer({a, b, c, d, e, f, g, h}) do
    bsl(a, 112)
    |> bor(bsl(b, 96))
    |> bor(bsl(c, 80))
    |> bor(bsl(d, 64))
    |> bor(bsl(e, 48))
    |> bor(bsl(f, 32))
    |> bor(bsl(g, 16))
    |> bor(h)
  end

  defp from_integer(int, :v4) do
    {
      band(bsr(int, 24), 0xFF),
      band(bsr(int, 16), 0xFF),
      band(bsr(int, 8), 0xFF),
      band(int, 0xFF)
    }
  end

  defp from_integer(int, :v6) do
    {
      band(bsr(int, 112), 0xFFFF),
      band(bsr(int, 96), 0xFFFF),
      band(bsr(int, 80), 0xFFFF),
      band(bsr(int, 64), 0xFFFF),
      band(bsr(int, 48), 0xFFFF),
      band(bsr(int, 32), 0xFFFF),
      band(bsr(int, 16), 0xFFFF),
      band(int, 0xFFFF)
    }
  end

  defp mask(prefix_len, :v4) when prefix_len >= 0 and prefix_len <= 32,
    do: bsl(0xFFFFFFFF, 32 - prefix_len) |> band(0xFFFFFFFF)

  defp mask(prefix_len, :v6) when prefix_len >= 0 and prefix_len <= 128 do
    max_val = bsl(1, 128) - 1
    bsl(max_val, 128 - prefix_len) |> band(max_val)
  end
end
