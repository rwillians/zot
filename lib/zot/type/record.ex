defmodule Zot.Type.Record do
  @moduledoc ~S"""
  Describes a Record type, which is a map where keys are unknown.
  """

  use Zot.Template

  deftype keys_type:   [t: Zot.Type.t(), default: Zot.Type.String.new()],
          values_type: [t: Zot.Type.t()]

  def keys_type(%Zot.Type.Record{} = type, type(_) = value),
    do: %{type | keys_type: value}

  def values_type(%Zot.Type.Record{} = type, type(_) = value),
    do: %{type | values_type: value}
end

defimpl Zot.Type, for: Zot.Type.Record do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Record{} = type, value, opts) do
    with :ok <- validate_type(value, is: "map"),
         {:ok, value} <- parse_map(value, type, opts),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Record{} = type) do
    %{
      "additionalProperties" => Zot.json_schema(type.values_type),
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "properties" => %{},
      "required" => [],
      "type" => "object"
    }
  end

  #
  #   PRIVATE
  #

  defp parse_map(input, type, opts) do
    {parsed, issues} =
      Enum.reduce(input, {%{}, []}, fn {key, value}, {acc_parsed, acc_issues} ->
        with {:ok, key} <- do_parse([key], key, type.keys_type, opts),
             {:ok, value} <- do_parse([key], value, type.values_type, opts) do
          {Map.put(acc_parsed, key, value), acc_issues}
        else
          {:error, issues} -> {acc_parsed, acc_issues ++ issues}
        end
      end)

    case {issues, map_size(parsed)} do
      {[], _} -> {:ok, parsed}
      {[_ | _], 0} -> {:error, issues}
      {[_ | _], n} when n > 0 -> {:error, issues, parsed}
    end
  end

  defp do_parse(path, value, type, opts) do
    Zot.Context.new(type, value, opts)
    |> Zot.Context.put_path(path)
    |> Zot.Context.parse()
    |> Zot.Context.unwrap()
  end
end
