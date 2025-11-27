defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Defines a type that accepts integer values.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype is: {nil, t: Zot.Parameterized.t(nil | integer)},
          min: {nil, t: Zot.Parameterized.t(nil | integer)},
          max: {nil, t: Zot.Parameterized.t(nil | integer)}

  @doc ~S"""
  Defines that the value must be exactly the given integer.
  """
  @opts error: "expected the exact integer %{expected}"
  def is(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | is: {value, merge_opts(@opts, opts)}}

  @doc ~S"""
  Defines that the value must be greater than or equal to the given
  integer.
  """
  @opts error: "expected an integer greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | min: {value, merge_opts(@opts, opts)}}

  @doc ~S"""
  Defines that the value must be less than or equal to the given
  integer.
  """
  @opts error: "expected an integer less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | max: {value, merge_opts(@opts, opts)}}
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{} = type, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "integer"),
         :ok <- validate_number(value, is: type.is, min: type.min, max: type.max),
         do: {:ok, value}
  end
end
