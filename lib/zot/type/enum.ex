defmodule Zot.Type.Enum do
  @moduledoc ~S"""
  Defines a type that accepts only a predefined set of values.
  """

  import Zot.Helpers, only: [is_non_empty_string: 1]

  @typedoc """
  The `Zot.Type.Enum` struct, holding data on its configurations.

  > ### Warning {: .warning}
  > Do not manipulate the values in this struct directly as backwards
  > compatibility is not guaranteed.
  """
  @type t :: %Zot.Type.Enum{
          values: [atom, ...] | [String.t(), ...] | [integer, ...]
        }

  defstruct values: [],
            index: nil

  @doc ~s"""
  Builds a new `Zot.Type.Enum` from the given allowed values.
  """
  @spec new([value, ...]) :: t
        when value: atom | String.t() | integer

  def new([_ | _] = values) do
    with false <- Enum.all?(values, &is_atom/1),
         false <- Enum.all?(values, &is_non_empty_string/1),
         false <- Enum.all?(values, &is_integer/1) do
      raise ArgumentError,
        message: "[Zot.Type.Enum.new/1] Values must be a list of atom, non-empty string or integer, where all values are of the same type."
    else
      true -> %Zot.Type.Enum{values: values, index: build_index(values)}
    end
  end

  #
  #   PRIVATE
  #

  defp build_index(list) do
    list
    |> Enum.flat_map(&([{&1, &1}, {to_string(&1), &1}]))
    |> Enum.uniq()
    |> Enum.into(%{})
  end
end

defimpl Zot.Type, for: Zot.Type.Enum do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Enum{} = type, value, opts) do
    with :ok <- validate_required(value),
         {:ok, value} <- coerce(value, type.index, opts[:coerce] || false),
         :ok <- validate_type(value, ["atom", "string", "integer"]),
         :ok <- validate_enum(value, type.values),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, _, false), do: {:ok, value}
  defp coerce(value, _, _) when not is_binary(value), do: {:ok, value}
  defp coerce(value, index, _) when is_map_key(index, value), do: {:ok, Map.fetch!(index, value)}
  defp coerce(value, _, _), do: {:ok, value}

  def validate_enum(value, [_ | _] = expected) do
    if value in expected do
      :ok
    else
      expected_str =
        expected
        |> Enum.map(&format/1)
        |> human_readable_list(conjunction: :or)

      {:error, [issue("expected one of %{expected}, got %{actual}", expected: expected_str, actual: format(value))]}
    end
  end

  defp format(value) when is_atom(value), do: ":#{value}"
  defp format(value) when is_binary(value), do: "'#{value}'"
  defp format(value), do: to_string(value)

end
