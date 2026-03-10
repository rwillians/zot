defmodule Zot.Type.Set do
  @moduledoc ~S"""
  Describes a set type (a list of unique items).
  """

  use Zot.Template

  deftype inner_type: [t: Zot.Type.t()],
          length:     [t: Zot.Parameterized.t(pos_integer) | nil],
          min:        [t: Zot.Parameterized.t(non_neg_integer) | nil],
          max:        [t: Zot.Parameterized.t(pos_integer) | nil],
          unique:     [t: Zot.Parameterized.t(boolean) | nil]

  def inner_type(%Zot.Type.Set{} = type, type(_) = inner_type),
    do: %{type | inner_type: inner_type}

  @opts error: "must have %{expected} items, got %{actual}"
  def length(type, value, opts \\ [])
  def length(%Zot.Type.Set{} = type, nil, _), do: %{type | length: nil}

  def length(%Zot.Type.Set{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | length: p(value, @opts, opts)}

  @opts error: "must have at least %{expected} items, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Set{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Set{} = type, value, opts)
      when is_integer(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must have at most %{expected} items, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Set{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Set{} = type, value, opts)
      when is_integer(value),
      do: %{type | max: p(value, @opts, opts)}

  @opts error: "expected unique values only, found duplicate at index %{index}"
  def unique(type, value \\ :enforce, opts \\ [])
  def unique(%Zot.Type.Set{} = type, nil, _), do: %{type | unique: nil}

  def unique(%Zot.Type.Set{} = type, :enforce, opts),
    do: %{type | unique: p(:enforce, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Set do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Set{} = type, value, opts) do
    with :ok <- validate_type(value, is: "list"),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
         :ok <- validate_uniqueness(value, type.unique),
         {:ok, value} <- parse_items(value, type.inner_type, opts),
         do: {:ok, Enum.uniq(value)}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Set{} = type) do
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
      "type" => maybe_nullable("array", type.required),
      "uniqueItems" => true
    }
  end

  #
  #   PRIVATE
  #

  defp validate_uniqueness(_, nil), do: :ok

  defp validate_uniqueness(values, %Zot.Parameterized{} = unique) do
    issues =
      values
      |> Enum.with_index()
      |> Enum.reduce({MapSet.new(), []}, fn {value, index}, {seen, acc_issues} ->
        if MapSet.member?(seen, value) do
          issue = %{issue(unique.params.error, index: index) | path: [index]}
          {seen, [issue | acc_issues]}
        else
          {MapSet.put(seen, value), acc_issues}
        end
      end)
      |> elem(1)
      |> :lists.reverse()

    case issues do
      [] -> :ok
      [_ | _] -> {:error, issues}
    end
  end

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
