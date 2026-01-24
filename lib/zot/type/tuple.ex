defmodule Zot.Type.Tuple do
  @moduledoc ~S"""
  Describes a tuple type with a fixed number of heterogeneous elements.
  """

  use Zot.Template

  deftype shape: [t: [Zot.Type.t(), ...]]

  def shape(%Zot.Type.Tuple{} = type, value)
      when is_list(value),
      do: %{type | shape: value}

  def shape(%Zot.Type.Tuple{} = type, value) when is_tuple(value),
    do: %{type | shape: Tuple.to_list(value)}
end

defimpl Zot.Type, for: Zot.Type.Tuple do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Tuple{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "tuple"),
         :ok <- validate_tuple_size(value, type.shape),
         {:ok, value} <- parse_elements(value, type.shape, opts),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Tuple{} = type) do
    prefix_items = Enum.map(type.shape, &Zot.json_schema/1)

    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "prefixItems" => prefix_items,
      "items" => false,
      "minItems" => length(type.shape),
      "maxItems" => length(type.shape),
      "type" => maybe_nullable("array", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_tuple(value), do: {:ok, value}
  defp coerce(value, _) when is_list(value), do: {:ok, List.to_tuple(value)}
  defp coerce(value, _), do: {:ok, value}

  defp validate_tuple_size(value, shape) do
    expected = length(shape)
    actual = tuple_size(value)

    if actual == expected do
      :ok
    else
      {:error, [issue("expected a tuple with %{expected} elements, got %{actual}", expected: expected, actual: actual)]}
    end
  end

  defp parse_elements(value, shape, opts) do
    elements = Tuple.to_list(value)

    {parsed, issues} =
      elements
      |> Enum.zip(shape)
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {{element, type}, index}, {acc_parsed, acc_issues} ->
        result =
          Zot.Context.new(type, element, opts)
          |> Zot.Context.put_path([index])
          |> Zot.Context.parse()
          |> Zot.Context.unwrap()

        case result do
          {:ok, parsed} -> {[parsed | acc_parsed], acc_issues}
          {:error, issues} -> {acc_parsed, acc_issues ++ issues}
        end
      end)

    case {parsed, issues} do
      {_, []} -> {:ok, :lists.reverse(parsed) |> List.to_tuple()}
      {[], [_ | _]} -> {:error, issues}
      {[_ | _], [_ | _]} -> {:error, issues, :lists.reverse(parsed) |> List.to_tuple()}
    end
  end
end
