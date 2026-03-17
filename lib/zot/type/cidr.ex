defmodule Zot.Type.CIDR do
  @moduledoc ~S"""
  Describes a CIDR notation type (IPv4 or IPv6 network addresses).
  """

  use Zot.Template

  deftype version:      [t: :any | :v4 | :v6, default: :any],
          output:       [t: :string | :tuple | :map, default: :string],
          canonicalize: [t: boolean, default: false],
          min_prefix:   [t: Zot.Parameterized.t(non_neg_integer) | nil],
          max_prefix:   [t: Zot.Parameterized.t(pos_integer) | nil]

  def version(%Zot.Type.CIDR{} = type, value)
      when value in [:any, :v4, :v6],
      do: %{type | version: value}

  def output(%Zot.Type.CIDR{} = type, value)
      when value in [:string, :tuple, :map],
      do: %{type | output: value}

  def canonicalize(%Zot.Type.CIDR{} = type, value)
      when is_boolean(value),
      do: %{type | canonicalize: value}

  def min_prefix(type, value, opts \\ [])

  def min_prefix(%Zot.Type.CIDR{} = type, nil, _),
    do: type

  @opts error: "prefix length must be at least %{expected}, got %{actual}"
  def min_prefix(%Zot.Type.CIDR{} = type, value, opts)
      when is_integer(value) and value >= 0,
      do: %{type | min_prefix: p(value, @opts, opts)}

  def max_prefix(type, value, opts \\ [])

  def max_prefix(%Zot.Type.CIDR{} = type, nil, _),
    do: type

  @opts error: "prefix length must be at most %{expected}, got %{actual}"
  def max_prefix(%Zot.Type.CIDR{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | max_prefix: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.CIDR do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.CIDR{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "string"),
         {:ok, ip_tuple, prefix} <- parse_cidr(type.version, value),
         :ok <- validate_prefix_bounds(type, ip_tuple, prefix),
         {:ok, network_addr, broadcast_addr} <- validate_and_canonicalize(type, ip_tuple, prefix, value),
         do: {:ok, format_output(type.output, network_addr, broadcast_addr, prefix)}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.CIDR{} = type) do
    # IPv4 CIDR pattern: simplified regex for CIDR notation
    ipv4_pattern = "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(?:3[0-2]|[12]?[0-9])$"

    # IPv6 CIDR pattern: simplified
    ipv6_pattern = "^(?:[0-9a-fA-F]{1,4}:){0,7}[0-9a-fA-F]{0,4}(?::(?:[0-9a-fA-F]{1,4}:){0,6}[0-9a-fA-F]{0,4})?/(?:12[0-8]|1[01][0-9]|[1-9]?[0-9])$"

    ipv4 = %{
      "type" => maybe_nullable("string", type.required),
      "pattern" => ipv4_pattern
    }

    ipv6 = %{
      "type" => maybe_nullable("string", type.required),
      "pattern" => ipv6_pattern
    }

    details = %{
      "description" => type.description,
      "examples" => maybe_examples(type.example)
    }

    case type.version do
      :v4 -> Map.merge(ipv4, details)
      :v6 -> Map.merge(ipv6, details)
      :any -> Map.merge(%{"anyOf" => [ipv4, ipv6]}, details)
    end
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false),
    do: {:ok, value}

  defp coerce(value, _) when is_binary(value),
    do: {:ok, value}

  # Coerce from {ip_tuple, prefix}
  defp coerce({ip_tuple, prefix}, _)
       when is_tuple(ip_tuple) and (tuple_size(ip_tuple) == 4 or tuple_size(ip_tuple) == 8) and is_integer(prefix) do
    {:ok, "#{Zot.Ip.to_string(ip_tuple)}/#{prefix}"}
  end

  # Coerce from %{ip: tuple, prefix: int} or %{address: tuple, prefix: int}
  defp coerce(%{ip: ip_tuple, prefix: prefix}, flag),
    do: coerce({ip_tuple, prefix}, flag)

  defp coerce(%{address: ip_tuple, prefix: prefix}, flag),
    do: coerce({ip_tuple, prefix}, flag)

  # Let validate_type/2 handle it
  defp coerce(value, _),
    do: {:ok, value}

  defp parse_cidr(version, value) do
    case String.split(value, "/") do
      [ip_str, prefix_str] ->
        with {:ok, prefix} <- parse_prefix(prefix_str),
             {:ok, ip_tuple} <- parse_ip(version, ip_str) do
          {:ok, ip_tuple, prefix}
        end

      _ ->
        {:error, [issue("is invalid")]}
    end
  end

  defp parse_prefix(prefix_str) do
    case Integer.parse(prefix_str) do
      {prefix, ""} when prefix >= 0 -> {:ok, prefix}
      _ -> {:error, [issue("is invalid")]}
    end
  end

  defp parse_ip(:any, ip_str) do
    case :inet.parse_address(String.to_charlist(ip_str)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("is invalid")]}
    end
  end

  defp parse_ip(:v4, ip_str) do
    case :inet.parse_ipv4strict_address(String.to_charlist(ip_str)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("must be a valid IPv4 CIDR")]}
    end
  end

  defp parse_ip(:v6, ip_str) do
    case :inet.parse_ipv6strict_address(String.to_charlist(ip_str)) do
      {:ok, tuple} -> {:ok, tuple}
      {:error, _} -> {:error, [issue("must be a valid IPv6 CIDR")]}
    end
  end

  defp validate_prefix_bounds(type, ip_tuple, prefix) do
    max_prefix_for_version = if tuple_size(ip_tuple) == 4, do: 32, else: 128

    cond do
      prefix < 0 or prefix > max_prefix_for_version ->
        {:error, [issue("prefix length must be between %{min} and %{max}, got %{actual}", min: 0, max: max_prefix_for_version, actual: prefix)]}

      type.min_prefix != nil and prefix < type.min_prefix.value ->
        {:error, [issue(type.min_prefix.params.error, expected: type.min_prefix.value, actual: prefix)]}

      type.max_prefix != nil and prefix > type.max_prefix.value ->
        {:error, [issue(type.max_prefix.params.error, expected: type.max_prefix.value, actual: prefix)]}

      true ->
        :ok
    end
  end

  defp validate_and_canonicalize(type, ip_tuple, prefix, original_value) do
    network_addr = Zot.Ip.network_address(ip_tuple, prefix)
    broadcast_addr = Zot.Ip.broadcast_address(ip_tuple, prefix)

    is_canonical = ip_tuple == network_addr

    cond do
      is_canonical ->
        {:ok, network_addr, broadcast_addr}

      type.canonicalize ->
        {:ok, network_addr, broadcast_addr}

      true ->
        {:error, [issue("must be in canonical form (network address), got '%{actual}'", actual: {:escaped, original_value})]}
    end
  end

  defp format_output(:string, network_addr, _, prefix) do
    "#{Zot.Ip.to_string(network_addr)}/#{prefix}"
  end

  defp format_output(:tuple, network_addr, broadcast_addr, prefix),
    do: {network_addr, broadcast_addr, prefix}

  defp format_output(:map, network_addr, broadcast_addr, prefix),
    do: %{start: network_addr, end: broadcast_addr, prefix: prefix}

end
