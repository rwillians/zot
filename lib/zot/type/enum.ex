defmodule Zot.Type.Enum do
  @moduledoc ~S"""
  Defines a type that accepts only a predefined set of values.
  """

  use Zot.Template

  @new false
  deftype values: {nil, t: [atom, ...] | [String.t(), ...] | [integer, ...]}

  @doc ~s"""
  Builds a new `Zot.Type.Enum` from the given allowed values.
  """
  @spec new([value, ...]) :: t
        when value: atom | String.t() | integer

  def new([_ | _] = values) do
    {inner_type, true} =
      with {:atom, false} <- {:atom, Enum.all?(values, &is_atom/1)},
           {:string, false} <- {:string, Enum.all?(values, &is_non_empty_string/1)},
           {:integer, false} <- {:integer, Enum.all?(values, &is_integer/1)} do
        raise ArgumentError,
          message: "Values must be a list of atom, non-empty string or integer, where all values are of the same type."
      end

    %Zot.Type.Enum{
      values: values,
      __private__: %{inner_type: inner_type, index: build_index(values)}
    }
  end

  #
  #   PRIVATE
  #

  defp build_index(list) do
    list
    |> Enum.flat_map(&[{&1, &1}, {to_string(&1), &1}])
    |> Enum.uniq()
    |> Enum.into(%{})
  end
end

defimpl Zot.Type, for: Zot.Type.Enum do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Enum{} = type, value, opts) do
    with {:ok, value} <- coerce(value, type.__private__, coerce?(opts)),
         :ok <- validate_type(value, ["atom", "string", "integer"]),
         :ok <- validate_inclusion(value, type.values),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, _, false), do: {:ok, value}
  defp coerce(value, %{inner_type: :atom}, _) when is_atom(value), do: {:ok, value}
  defp coerce(value, %{inner_type: :string}, _) when is_binary(value), do: {:ok, value}
  defp coerce(value, %{inner_type: :integer}, _) when is_integer(value), do: {:ok, value}
  defp coerce(value, %{index: index}, _) when is_map_key(index, value), do: {:ok, Map.fetch!(index, value)}
  defp coerce(value, _, _), do: {:ok, value}
end
