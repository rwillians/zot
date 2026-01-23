defmodule Zot.Type.List do
  @moduledoc ~S"""
  Describes a list type.
  """

  use Zot.Template

  deftype inner_type: [t: Zot.Type.t()],
          length:     [t: Zot.Parameterized.t(pos_integer) | nil],
          min:        [t: Zot.Parameterized.t(non_neg_integer) | nil],
          max:        [t: Zot.Parameterized.t(pos_integer) | nil]

  def inner_type(%Zot.Type.List{} = type, zot_type(_) = inner_type),
    do: %{type | inner_type: inner_type}

  @opts error: "must have %{expected} items, got %{actual}"
  def length(type, value, opts \\ [])
  def length(%Zot.Type.List{} = type, nil, _), do: %{type | length: nil}

  def length(%Zot.Type.List{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | length: p(value, @opts, opts)}

  @opts error: "must have at least %{expected} items, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.List{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.List{} = type, value, opts)
      when is_integer(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must have at most %{expected} items, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.List{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.List{} = type, value, opts)
      when is_integer(value),
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.List do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.List{} = type, value, opts) do
    with :ok <- validate_type(value, is: "list"),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
         {:ok, value} <- parse_items(value, type.inner_type, opts),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.List{} = type) do
    {min_items, max_items} =
      case type.length do
        nil -> {dump(type.min), dump(type.max)}
        %{value: length} -> {length, length}
      end

    %{
      "description" => type.description,
      "items" => Zot.json_schema(type.inner_type),
      "maxItems" => max_items,
      "minItems" => min_items,
      "type" => maybe_nullable("array", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp parse_items(values, inner_type, opts) do
    {parsed, issues} =
      values
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {value, index}, {acc_parsed, acc_issues} ->
        result =
          Zot.Context.new(inner_type, value, opts)
          |> Zot.Context.put_path([index])
          |> Zot.Context.parse()
          |> Zot.Context.unwrap()

        case result do
          {:ok, parsed} -> {[parsed | acc_parsed], acc_issues}
          {:error, issues} -> {acc_parsed, acc_issues ++ issues}
        end
      end)

    case {parsed, issues} do
      {_, []} -> {:ok, :lists.reverse(parsed)}
      {[], [_ | _]} -> {:error, issues}
      {[_ | _], [_ | _]} -> {:error, issues, :lists.reverse(parsed)}
    end
  end
end
