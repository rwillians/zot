defmodule Zot.Type.IP do
  @moduledoc ~S"""
  Describes an IP address type (IPv4 or IPv6).
  """

  use Zot.Template

  # Predefined CIDR sets
  @private_v4 ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
  @private_v6 ["fc00::/7"]
  @loopback_v4 ["127.0.0.0/8"]
  @loopback_v6 ["::1/128"]
  @link_local_v4 ["169.254.0.0/16"]
  @link_local_v6 ["fe80::/10"]

  deftype version: [t: :any | :v4 | :v6, default: :any],
          output:  [t: :string | :tuple, default: :string],
          cidr:    [t: [Zot.Parameterized.t(term)] | nil, default: nil]

  def version(%Zot.Type.IP{} = type, value)
      when value in [:any, :v4, :v6],
      do: %{type | version: value}

  def output(%Zot.Type.IP{} = type, value)
      when value in [:string, :tuple],
      do: %{type | output: value}

  def cidr(type, range, opts \\ [])

  def cidr(%Zot.Type.IP{} = type, nil, _),
    do: %{type | cidr: nil}

  @opts error: "must be a private IP address"
  def cidr(%Zot.Type.IP{} = type, :private, opts) do
    ranges = @private_v4 ++ @private_v6

    add_cidr_constraint(type, p(ranges, @opts, opts))
  end

  @opts error: "must be a loopback IP address"
  def cidr(%Zot.Type.IP{} = type, :loopback, opts) do
    ranges = @loopback_v4 ++ @loopback_v6

    add_cidr_constraint(type, p(ranges, @opts, opts))
  end

  @opts error: "must be a link-local IP address"
  def cidr(%Zot.Type.IP{} = type, :link_local, opts) do
    ranges = @link_local_v4 ++ @link_local_v6

    add_cidr_constraint(type, p(ranges, @opts, opts))
  end

  @opts error: "must be within CIDR range %{expected}"
  def cidr(%Zot.Type.IP{} = type, range, opts)
      when is_binary(range)
      when is_list(range),
      do: add_cidr_constraint(type, p(List.wrap(range), @opts, opts))

  #
  #   PRIVATE
  #

  defp add_cidr_constraint(type, constraint) do
    case type.cidr do
      nil -> %{type | cidr: [constraint]}
      existing -> %{type | cidr: existing ++ [constraint]}
    end
  end
end

defimpl Zot.Type, for: Zot.Type.IP do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.IP{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "string"),
         {:ok, tuple} <- parse_ip(type.version, value),
         :ok <- validate_cidr(type.cidr, tuple),
         do: {:ok, format_output(type.output, tuple)}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.IP{} = type) do
    ipv4 = %{
      "type" => maybe_nullable("string", type.required),
      "format" => "ipv4"
    }

    ipv6 = %{
      "type" => maybe_nullable("string", type.required),
      "format" => "ipv6"
    }

    details = %{
      "description" => type.description,
      "examples" => maybe_examples(type.example)
    }

    case type.version do
      :v4 -> Map.merge(ipv4, details)
      :v6 -> Map.merge(ipv6, details)
      :any -> Map.merge(%{"oneOf" => [ipv4, ipv6]}, details)
    end
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false),
    do: {:ok, value}

  defp coerce(value, _) when is_binary(value),
    do: {:ok, value}

  defp coerce(value, _) when is_tuple(value) and tuple_size(value) == 4 do
    case :inet.ntoa(value) do
      {:error, _} -> {:error, [issue("cannot be coerced to IP address")]}
      charlist -> {:ok, List.to_string(charlist)}
    end
  end

  defp coerce(value, _) when is_tuple(value) and tuple_size(value) == 8 do
    case :inet.ntoa(value) do
      {:error, _} -> {:error, [issue("cannot be coerced to IP address")]}
      charlist -> {:ok, List.to_string(charlist)}
    end
  end

  # let validate_type/2 handle it
  defp coerce(value, _),
    do: {:ok, value}

  defp parse_ip(:any, value) do
    case :inet.parse_address(String.to_charlist(value)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("is invalid")]}
    end
  end

  defp parse_ip(:v4, value) do
    case :inet.parse_ipv4strict_address(String.to_charlist(value)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("must be a valid IPv4 address")]}
    end
  end

  defp parse_ip(:v6, value) do
    case :inet.parse_ipv6strict_address(String.to_charlist(value)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("must be a valid IPv6 address")]}
    end
  end

  defp format_output(:string, tuple) do
    tuple
    |> :inet.ntoa()
    |> List.to_string()
  end

  defp format_output(:tuple, tuple),
    do: tuple

  defp validate_cidr(nil, _),
    do: :ok

  defp validate_cidr(constraints, ip_tuple) when is_list(constraints) do
    Enum.reduce_while(constraints, :ok, fn constraint, _ ->
      case check_cidr_constraint(constraint.value, ip_tuple) do
        true -> {:halt, :ok}
        false -> {:cont, {:error, [issue(constraint.params.error, expected: format_cidr_ranges(constraint.value))]}}
      end
    end)
  end

  defp check_cidr_constraint(ranges, ip_tuple) when is_list(ranges),
    do: Enum.any?(ranges, &ip_in_cidr?(ip_tuple, &1))

  defp ip_in_cidr?(ip_tuple, cidr_string) do
    case parse_cidr(cidr_string) do
      {:ok, base_tuple, prefix_len} -> ip_matches_cidr?(ip_tuple, base_tuple, prefix_len)
      :error -> false
    end
  end

  defp parse_cidr(cidr_string) do
    case String.split(cidr_string, "/") do
      [ip_str, prefix_str] ->
        case {Integer.parse(prefix_str), :inet.parse_address(String.to_charlist(ip_str))} do
          {{prefix_len, ""}, {:ok, base_tuple}} -> {:ok, base_tuple, prefix_len}
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp ip_matches_cidr?(ip_tuple, base_tuple, prefix_len)
       when tuple_size(ip_tuple) == 4 and tuple_size(base_tuple) == 4 do
    ip_int = ipv4_to_integer(ip_tuple)
    base_int = ipv4_to_integer(base_tuple)
    mask = ipv4_mask(prefix_len)

    Bitwise.band(ip_int, mask) == Bitwise.band(base_int, mask)
  end

  defp ip_matches_cidr?(ip_tuple, base_tuple, prefix_len)
       when tuple_size(ip_tuple) == 8 and tuple_size(base_tuple) == 8 do
    ip_int = ipv6_to_integer(ip_tuple)
    base_int = ipv6_to_integer(base_tuple)
    mask = ipv6_mask(prefix_len)

    Bitwise.band(ip_int, mask) == Bitwise.band(base_int, mask)
  end

  # Mismatched IP versions (e.g., IPv4 address against IPv6 CIDR)
  defp ip_matches_cidr?(_, _, _),
    do: false

  defp ipv4_to_integer({a, b, c, d}) do
    Bitwise.bsl(a, 24)
    |> Bitwise.bor(Bitwise.bsl(b, 16))
    |> Bitwise.bor(Bitwise.bsl(c, 8))
    |> Bitwise.bor(d)
  end

  defp ipv4_mask(prefix_len) when prefix_len >= 0 and prefix_len <= 32 do
    Bitwise.bsl(0xFFFFFFFF, 32 - prefix_len) |> Bitwise.band(0xFFFFFFFF)
  end

  defp ipv6_to_integer({a, b, c, d, e, f, g, h}) do
    Bitwise.bsl(a, 112)
    |> Bitwise.bor(Bitwise.bsl(b, 96))
    |> Bitwise.bor(Bitwise.bsl(c, 80))
    |> Bitwise.bor(Bitwise.bsl(d, 64))
    |> Bitwise.bor(Bitwise.bsl(e, 48))
    |> Bitwise.bor(Bitwise.bsl(f, 32))
    |> Bitwise.bor(Bitwise.bsl(g, 16))
    |> Bitwise.bor(h)
  end

  defp ipv6_mask(prefix_len) when prefix_len >= 0 and prefix_len <= 128 do
    max_val = Bitwise.bsl(1, 128) - 1
    Bitwise.bsl(max_val, 128 - prefix_len) |> Bitwise.band(max_val)
  end

  defp format_cidr_ranges([single]),
    do: {:escaped, single}

  defp format_cidr_ranges(ranges),
    do: {:escaped, Enum.join(ranges, ", ")}
end
