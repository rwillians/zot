defmodule Zot.Type.Keyword do
  @moduledoc ~S"""
  Describes a keyword list type.

  Works like the map type but takes a keyword list as input and
  produces a keyword list as output, following the shape's key order.
  The shape may be given as a map or a keyword list, but it is always
  stored as a keyword list so that the key order is preserved.
  """

  use Zot.Template

  deftype shape: [t: keyword],
          mode:  [t: :strict | :strip, default: :strip]

  def shape(%Zot.Type.Keyword{} = type, shape)
      when is_non_struct_map(shape)
      when is_list(shape),
      do: %{type | shape: Enum.to_list(shape)}

  def mode(%Zot.Type.Keyword{} = type, mode)
      when mode in [:strict, :strip],
      do: %{type | mode: mode}
end

defimpl Zot.Type, for: Zot.Type.Keyword do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Keyword{} = type, value, opts) do
    with :ok <- validate_keyword(value),
         do: do_parse(type, value, opts)
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Keyword{} = type) do
    Zot.Type.json_schema(to_map_type(type))
    |> Map.put("description", type.description)
    |> Map.put("examples", maybe_examples(type.example))
  end

  #
  #   PRIVATE
  #

  defp do_parse(%Zot.Type.Keyword{} = type, value, opts) do
    # reversed so that duplicated keys resolve to the first
    # occurrence, matching `Keyword.get/2` semantics
    input =
      value
      |> Enum.reverse()
      |> Map.new()

    case Zot.Type.parse(to_map_type(type), input, opts) do
      {:ok, result} -> {:ok, to_keyword(result, type.shape)}
      {:error, issues} -> {:error, issues}
      {:error, issues, partial} -> {:error, issues, to_keyword(partial, type.shape)}
    end
  end

  defp to_keyword(map, shape),
    do: for({key, _} <- shape, Map.has_key?(map, key), do: {key, Map.fetch!(map, key)})

  defp to_map_type(%Zot.Type.Keyword{} = type),
    do: Zot.Type.Map.new(mode: type.mode, shape: Map.new(type.shape))

  defp validate_keyword(value) when not is_list(value), do: validate_type(value, is: "keyword")

  defp validate_keyword(value) do
    case Keyword.keyword?(value) do
      true -> :ok
      false -> {:error, [issue("expected type %{expected}, got %{actual}", expected: {:escaped, "keyword"}, actual: {:escaped, "list"})]}
    end
  end
end
