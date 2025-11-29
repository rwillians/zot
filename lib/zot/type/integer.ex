defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Defines a type that accepts integers.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype min: {nil, t: p(nil | integer)},
          max: {nil, t: p(nil | integer)}

  @doc ~S"""
  Defines that the value must be greater than or equal to the given
  integer.
  """
  @opts error: "expected a number greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | min: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines that the value must be less than or equal to the given
  integer.
  """
  @opts error: "expected a number less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | max: parameterized(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{} = type, value, _) do
    with :ok <- validate_type(value, "integer"),
         :ok <- validate_number(value, gte: type.min, lte: type.max),
         do: {:ok, value}
  end
end
