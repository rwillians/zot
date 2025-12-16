defmodule Zot.Type.Decimal do
  @moduledoc ~S"""
  Describes a type that accepts decimal numbers.
  """

  use Zot.Template

  import Kernel, except: [min: 2, max: 2]

  deftype is:        {nil, t: Zot.Parameterized.t(nil | Decimal.t() | number)},
          min:       {nil, t: Zot.Parameterized.t(nil | Decimal.t() | number)},
          max:       {nil, t: Zot.Parameterized.t(nil | Decimal.t() | number)},
          precision: {nil, t: nil | non_neg_integer()}

  @opts error: "must be exactly %{expected}, got %{actual}"
  def is(%Zot.Type.Decimal{} = type, value, opts \\ [])
      when is_nil(value)
      when is_struct(value, Decimal)
      when is_number(value),
      do: %{type | is: parameterized(to_decimal(value), @opts, opts)}

  @opts error: "must be greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Decimal{} = type, value, opts \\ [])
      when is_nil(value)
      when is_struct(value, Decimal)
      when is_number(value),
      do: %{type | min: parameterized(to_decimal(value), @opts, opts)}

  @opts error: "must be less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Decimal{} = type, value, opts \\ [])
      when is_nil(value)
      when is_struct(value, Decimal)
      when is_number(value),
      do: %{type | max: parameterized(to_decimal(value), @opts, opts)}

  def precision(%Zot.Type.Decimal{} = type, value)
      when is_nil(value)
      when is_integer(value) and value >= 0,
      do: %{type | precision: value}

  #
  #   PRIVATE
  #

  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
end

defimpl Zot.Type, for: Zot.Type.Decimal do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Decimal{} = type, value, opts) do
    with {:ok, value} <- coerce(value, get_coerce_flag(opts)),
         :ok <- validate_type(value, is: "Decimal"),
         :ok <- validate_number(value, is: type.is, gte: type.min, lte: type.max),
         do: {:ok, apply_precision(value, type.precision)}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(%Decimal{} = value, _), do: {:ok, value}
  defp coerce(value, _) when is_float(value), do: {:ok, Decimal.from_float(value)}
  defp coerce(value, _) when is_integer(value), do: {:ok, Decimal.new(value)}

  defp coerce(value, _) when is_binary(value) do
    case Decimal.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> {:error, [issue("cannot coerce value %{value} into Decimal", value: value)]}
    end
  end

  # let it fail in the type validation
  defp coerce(value, _), do: {:ok, value}

  defp apply_precision(%Decimal{} = value, nil), do: value
  defp apply_precision(%Decimal{} = value, places), do: Decimal.round(value, places)
end
