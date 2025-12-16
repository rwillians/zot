defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Describes a type that accepts integer numbers.
  """

  use Zot.Template

  import Kernel, except: [min: 2, max: 2]

  deftype is:  {nil, t: Zot.Parameterized.t(nil | integer)},
          min: {nil, t: Zot.Parameterized.t(nil | integer)},
          max: {nil, t: Zot.Parameterized.t(nil | integer)}

  @opts error: "must be exactly %{expected}, got %{actual}"
  def is(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | is: parameterized(value, @opts, opts)}

  @opts error: "must be greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | min: parameterized(value, @opts, opts)}

  @opts error: "must be less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Integer{} = type, value, opts \\ [])
      when is_nil(value)
      when is_integer(value),
      do: %{type | max: parameterized(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{} = type, value, opts) do
    with {:ok, value} <- coerce(value, get_coerce_flag(opts)),
         :ok <- validate_type(value, is: "integer"),
         :ok <- validate_number(value, is: type.is, gte: type.min, lte: type.max),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, value}
  defp coerce(value, _) when is_float(value), do: {:ok, round(value)}

  defp coerce(value, _) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> {:ok, round(num)}
      _ -> {:error, [issue("cannot be coerced into integer")]}
    end
  end

  # let the type validation handle it
  defp coerce(value, _), do: {:ok, value}
end
