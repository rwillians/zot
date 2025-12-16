defmodule Zot.Type.Float do
  @moduledoc ~S"""
  Describes a type that accepts floating-point numbers.
  """

  use Zot.Template

  import Kernel, except: [min: 2, max: 2]

  deftype is:        {nil, t: Zot.Parameterized.t(nil | float | integer)},
          min:       {nil, t: Zot.Parameterized.t(nil | float | integer)},
          max:       {nil, t: Zot.Parameterized.t(nil | float | integer)},
          precision: {nil, t: nil | non_neg_integer()}

  @opts error: "must be exactly %{expected}, got %{actual}"
  def is(%Zot.Type.Float{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | is: parameterized(to_float(value), @opts, opts)}

  @opts error: "must be greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Float{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | min: parameterized(to_float(value), @opts, opts)}

  @opts error: "must be less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Float{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value),
      do: %{type | max: parameterized(to_float(value), @opts, opts)}

  def precision(%Zot.Type.Float{} = type, value)
      when is_nil(value)
      when is_integer(value) and value >= 0,
      do: %{type | precision: value}

  #
  #   PRIVATE
  #

  defp to_float(nil), do: nil
  defp to_float(value), do: value * 1.0
end

defimpl Zot.Type, for: Zot.Type.Float do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Float{} = type, value, opts) do
    with {:ok, value} <- coerce(value, get_coerce_flag(opts)),
         :ok <- validate_type(value, is: "float"),
         :ok <- validate_number(value, is: type.is, gte: type.min, lte: type.max),
         do: {:ok, apply_precision(value, type.precision)}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_float(value), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, value * 1.0}

  defp coerce(value, _) when is_binary(value) do
    case Float.parse(value) do
      {num, ""} -> {:ok, num}
      _ -> {:error, [issue("cannot be coerced into float")]}
    end
  end

  # let the type validation handle it
  defp coerce(value, _), do: {:ok, value}

  defp apply_precision(value, nil), do: value
  defp apply_precision(value, places), do: Float.round(value, places)
end
