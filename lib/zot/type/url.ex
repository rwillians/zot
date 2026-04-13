defmodule Zot.Type.URL do
  @moduledoc ~S"""
  Describes a URL string type.
  """

  use Zot.Template

  deftype allow_loopback:  [t: boolean,                                       default: true],
          allowed_schemes: [t: Zot.Parameterized.t([String.t(), ...]) | nil,  default: nil],
          allowed_ports:   [t: Zot.Parameterized.t([pos_integer, ...]) | nil, default: nil],
          forbidden_ports: [t: Zot.Parameterized.t([pos_integer, ...]) | nil, default: nil],
          query_string:    [t: Zot.Parameterized.t(:keep | :forbid | :trim),  default: :keep],
          require_path:    [t: boolean,                                       default: false],
          trailing_slash:  [t: :always | :keep | :trim,                       default: :keep]

  def allow_loopback(%Zot.Type.URL{} = type, value \\ true)
      when is_boolean(value),
      do: %{type | allow_loopback: value}

  @opts error: "scheme must be %{expected}, got %{actual}"
  def allowed_schemes(type, value, opts \\ [])
  def allowed_schemes(%Zot.Type.URL{} = type, nil, _), do: %{type | allowed_schemes: nil}

  def allowed_schemes(%Zot.Type.URL{} = type, value, opts)
      when is_list(value) do
    unless Enum.all?(value, &(is_binary(&1) and String.length(&1) > 0)) do
      raise ArgumentError,
            "allowed_schemes must all be strings, got #{inspect(value)}"
    end

    %{type | allowed_schemes: p(value, @opts, opts)}
  end

  @opts error: "port must be %{expected}, got %{actual}"
  def allowed_ports(type, value, opts \\ [])
  def allowed_ports(%Zot.Type.URL{} = type, nil, _), do: %{type | allowed_ports: nil}

  def allowed_ports(%Zot.Type.URL{forbidden_ports: fp} = type, value, opts)
      when is_list(value) do
    if fp, do: raise(ArgumentError, "cannot set allowed_ports when forbidden_ports is already set")

    unless Enum.all?(value, &(is_integer(&1) and &1 > 0)) do
      raise ArgumentError,
            "allowed_ports must all be positive integers, got #{inspect(value)}"
    end

    %{type | allowed_ports: p(value, @opts, opts)}
  end

  @opts error: "port %{actual} is not allowed"
  def forbidden_ports(type, value, opts \\ [])
  def forbidden_ports(%Zot.Type.URL{} = type, nil, _), do: %{type | forbidden_ports: nil}

  def forbidden_ports(%Zot.Type.URL{allowed_ports: ap} = type, value, opts)
      when is_list(value) do
    if ap, do: raise(ArgumentError, "cannot set forbidden_ports when allowed_ports is already set")

    unless Enum.all?(value, &(is_integer(&1) and &1 > 0)) do
      raise ArgumentError,
            "forbidden_ports must all be positive integers, got #{inspect(value)}"
    end

    %{type | forbidden_ports: p(value, @opts, opts)}
  end

  def require_path(%Zot.Type.URL{} = type, value \\ true)
      when is_boolean(value),
      do: %{type | require_path: value}

  @opts error: "query string is not allowed"
  def query_string(%Zot.Type.URL{} = type, value, opts \\ [])
      when value in [:forbid, :keep, :trim],
      do: %{type | query_string: p(value, @opts, opts)}

  def trailing_slash(%Zot.Type.URL{} = type, value)
      when value in [:always, :keep, :trim],
      do: %{type | trailing_slash: value}
end

defimpl Zot.Type, for: Zot.Type.URL do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.URL{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         {:ok, value} <- parse_uri(value),
         :ok <- validate_inclusion(value.scheme, type.allowed_schemes),
         :ok <- validate_host(value),
         :ok <- validate_loopback(value, type.allow_loopback),
         :ok <- validate_port(value, type.allowed_ports, type.forbidden_ports),
         :ok <- validate_path_required(value, type.require_path),
         {:ok, value} <- validate_query_string(value, type.query_string),
         {:ok, value} <- validate_trailing_slash(value, type.trailing_slash),
         do: {:ok, URI.to_string(value)}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.URL{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "format" => "uri",
      "type" => maybe_nullable("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp parse_uri(value), do: with({:error, _} <- URI.new(value), do: {:error, [issue("is invalid")]})

  defp validate_host(%URI{host: host}) when is_binary(host) and byte_size(host) > 0, do: :ok
  defp validate_host(_), do: {:error, [issue("host is required")]}

  defp validate_loopback(_, true), do: :ok

  defp validate_loopback(%URI{host: host}, false) do
    cond do
      host == "localhost" -> {:error, [issue("loopback addresses are not allowed")]}
      String.ends_with?(host, ".localhost") -> {:error, [issue("loopback addresses are not allowed")]}
      Zot.Ip.is_ip?(host) and Zot.Ip.loopback?(host) -> {:error, [issue("loopback addresses are not allowed")]}
      true -> :ok
    end
  end

  defp validate_port(_, nil, nil), do: :ok
  defp validate_port(%URI{port: nil}, _, _), do: :ok

  defp validate_port(%URI{port: port}, %Zot.Parameterized{} = allowed, _) do
    case port in allowed.value do
      true -> :ok
      false -> {:error, [issue(allowed.params.error, expected: {:disjunction, allowed.value}, actual: port)]}
    end
  end

  defp validate_port(%URI{port: port}, _, %Zot.Parameterized{} = forbidden) do
    case port in forbidden.value do
      true -> {:error, [issue(forbidden.params.error, actual: port)]}
      false -> :ok
    end
  end

  defp validate_path_required(_, false), do: :ok
  defp validate_path_required(%URI{path: path}, true) when is_binary(path) and path not in ["", "/"], do: :ok
  defp validate_path_required(_, true), do: {:error, [issue("path is required")]}

  defp validate_query_string(%URI{query: <<_, _::binary>>}, %Zot.Parameterized{value: :forbid} = qs), do: {:error, [issue(qs.params.error)]}
  defp validate_query_string(%URI{query: <<_, _::binary>>} = value, %Zot.Parameterized{value: :trim}), do: {:ok, %{value | query: nil}}
  defp validate_query_string(%URI{} = value, _), do: {:ok, value}

  defp validate_trailing_slash(value, :keep), do: {:ok, value}
  defp validate_trailing_slash(%URI{path: nil} = value, :trim), do: {:ok, value}
  defp validate_trailing_slash(%URI{path: "/"} = value, :trim), do: {:ok, %{value | path: nil}}

  defp validate_trailing_slash(%URI{path: path} = value, :trim) do
    case String.match?(path, ~r/\.[a-z]+$/) do
      true -> {:ok, value}
      false -> {:ok, %{value | path: String.trim_trailing(path, "/")}}
    end
  end

  defp validate_trailing_slash(%URI{path: nil} = value, :always), do: {:ok, %{value | path: "/"}}
  defp validate_trailing_slash(%URI{path: "/"} = value, :always), do: {:ok, value}

  defp validate_trailing_slash(%URI{path: path} = value, :always) do
    case {String.ends_with?(path, "/"), String.match?(path, ~r/\.[a-z]+$/)} do
      {true, _} -> {:ok, value}
      {false, true} -> {:ok, value}
      {false, false} -> {:ok, %{value | path: value.path <> "/"}}
    end
  end
end
