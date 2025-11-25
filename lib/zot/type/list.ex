defmodule Zot.Type.List do
  @moduledoc ~S"""
  Defines a type that accepts a list of a given value.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype inner_type: {nil, t: Zot.Type.t()},
          length:     {nil, t: Zot.Parameterized.t(nil | pos_integer)},
          min:        {nil, t: Zot.Parameterized.t(nil | non_neg_integer)},
          max:        {nil, t: Zot.Parameterized.t(nil | pos_integer)}

  @doc ~S"""
  Alias to `new/1`.
  """
  def new(%_{} = inner_type, opts) when is_list(opts), do: new([{:inner_type, inner_type} | opts])

  @doc ~S"""
  Defines the type of the values inside the list.
  """
  def inner_type(%Zot.Type.List{} = type, %_{} = value), do: %{type | inner_type: value}

  @doc ~S"""
  Defines the exact expected length of the list.
  """
  @opts error: "should have exactly %{expected} items, got %{actual} items"
  def length(%Zot.Type.List{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > 0,
      do: %{type | length: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines the minimum expected length of the list.
  """
  @opts error: "should have at least %{expected} items, got %{actual} items"
  def min(%Zot.Type.List{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value >= 0,
      do: %{type | min: {value, merge_params(@opts, opts)}}

  @doc ~S"""
  Defines the maximum expected length of the list.
  """
  @opts error: "should have at most %{expected} items, got %{actual} items"
  def max(%Zot.Type.List{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value) and value > 0,
      do: %{type | max: {value, merge_params(@opts, opts)}}
end

defimpl Zot.Type, for: Zot.Type.List do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.List{} = type, value, opts) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "list"),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
         {:ok, value} <- parse_items({type.inner_type, opts}, value),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp parse_items(_, []), do: {:ok, []}

  defp parse_items({inner_type, opts}, [_ | _] = value) do
    {parsed, issues} =
      value
      |> Enum.with_index()
      |> Enum.reduce({[], []}, fn {item, index}, {ok, err} ->
        case Zot.Type.parse(inner_type, item, opts) do
          {:ok, parsed} -> {[parsed | ok], err}
          {:error, issues} -> {ok, err ++ Enum.map(issues, &prepend_path(&1, [index]))}
        end
      end)

    case issues do
      [] -> {:ok, :lists.reverse(parsed)}
      [_ | _] -> {:error, issues}
    end
  end
end
