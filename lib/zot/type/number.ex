defmodule Zot.Type.Number do
  @moduledoc ~S"""
  Defines a type that accepts number values (integer or float).
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype is: {nil, t: Zot.Parameterized.t(nil | number)},
          min: {nil, t: Zot.Parameterized.t(nil | number)},
          max: {nil, t: Zot.Parameterized.t(nil | number)}

  @doc ~S"""
  Defines that the value must be exactly the given float.
  """
  @opts error: "expected the exact number %{expected}"
  def is(%Zot.Type.Number{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | is: {value, merge_opts(@opts, opts)}}

  @doc ~S"""
  Defines that the value must be greater than or equal to the given
  float.
  """
  @opts error: "expected a number greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Number{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | min: {value, merge_opts(@opts, opts)}}

  @doc ~S"""
  Defines that the value must be less than or equal to the given
  number.
  """
  @opts error: "expected a number less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Number{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | max: {value, merge_opts(@opts, opts)}}
end

defimpl Zot.Type, for: Zot.Type.Number do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Number{} = type, value, _) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, ["integer", "float"]),
         :ok <- validate_number(value, is: type.is, min: type.min, max: type.max),
         do: {:ok, value}
  end
end
