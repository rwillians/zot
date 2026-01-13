defmodule Zot.Type.URI do
  @moduledoc ~S"""
  Describes a URI string type.
  """

  use Zot.Template

  deftype allowed_schemes: [t: Zot.Parameterized.t([String.t(), ...]) | nil],
          query_string:    [t: Zot.Parameterized.t(:keep | :forbid | :trim), default: :keep],
          trailing_slash:  [t: :always | :keep | :trim,                      default: :keep]

  @opts error: "scheme must be %{expected}, got %{actual}"
  def allowed_schemes(type, value, opts \\ [])
  def allowed_schemes(%Zot.Type.URI{} = type, nil, _), do: %{type | allowed_schemes: nil}

  def allowed_schemes(%Zot.Type.URI{} = type, value, opts)
      when is_list(value) do
    unless Enum.all?(value, &(is_binary(&1) and String.length(&1) > 0)) do
      raise ArgumentError,
            "allowed_schemes must all be strings, got #{inspect(value)}"
    end

    %{type | allowed_schemes: p(value, @opts, opts)}
  end

  @opts error: "query string is not allowed"
  def query_string(%Zot.Type.URI{} = type, value, opts \\ [])
      when value in [:forbid, :keep, :trim],
      do: %{type | query_string: p(value, @opts, opts)}

  def trailing_slash(%Zot.Type.URI{} = type, value)
      when value in [:always, :keep, :trim],
      do: %{type | trailing_slash: value}
end

defimpl Zot.Type, for: Zot.Type.URI do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.URI{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         {:ok, value} <- parse_uri(value),
         :ok <- validate_inclusion(value.scheme, type.allowed_schemes),
         {:ok, value} <- validate_query_string(value, type.query_string),
         {:ok, value} <- validate_trailing_slash(value, type.trailing_slash),
         do: {:ok, URI.to_string(value)}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.URI{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "format" => "uri",
      "nullable" => not type.required,
      "type" => "string"
    }
  end

  #
  #   PRIVATE
  #

  defp parse_uri(value), do: with({:error, _} <- URI.new(value), do: {:error, [issue("is invalid")]})

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
