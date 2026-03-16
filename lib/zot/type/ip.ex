defmodule Zot.Type.IP do
  @moduledoc ~S"""
  Describes an IP address type (IPv4 or IPv6).
  """

  use Zot.Template

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
    ranges = Zot.Ip.cidrs(:private)

    add_cidr_constraint(type, p(ranges, @opts, opts))
  end

  @opts error: "must be a loopback IP address"
  def cidr(%Zot.Type.IP{} = type, :loopback, opts) do
    ranges = Zot.Ip.cidrs(:loopback)

    add_cidr_constraint(type, p(ranges, @opts, opts))
  end

  @opts error: "must be a link-local IP address"
  def cidr(%Zot.Type.IP{} = type, :link_local, opts) do
    ranges = Zot.Ip.cidrs(:link_local)

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
    do: Zot.Ip.in_cidr?(ip_tuple, ranges)

  defp format_cidr_ranges([single]),
    do: {:escaped, single}

  defp format_cidr_ranges(ranges),
    do: {:escaped, Enum.join(ranges, ", ")}
end
