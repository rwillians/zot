defmodule Zot.Type.Decimal do
  @moduledoc ~S"""
  Defines a type that accepts integers.
  """

  use Zot.Template

  import Kernel, except: [max: 2, min: 2]

  deftype min: {nil, t: p(nil | Decimal.t | number)},
          max: {nil, t: p(nil | Decimal.t | number)}

  @opts error: "expected a number less than or equal to %{expected}, got %{actual}"
  def max(%Zot.Type.Decimal{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value)
      when is_struct(value, Decimal),
      do: %{type | max: parameterized(value, @opts, opts)}

  @opts error: "expected a number greater than or equal to %{expected}, got %{actual}"
  def min(%Zot.Type.Decimal{} = type, value, opts \\ [])
      when is_nil(value)
      when is_number(value)
      when is_struct(value, Decimal),
      do: %{type | min: parameterized(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Decimal do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Decimal{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce?(opts)),
         :ok <- validate_type(value, "Decimal"),
         :ok <- validate_number(value, gte: type.min, lte: type.max),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(%Decimal{} = value, _), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, Decimal.new(value)}
  defp coerce(value, _) when is_float(value), do: {:ok, Decimal.from_float(value)}

  defp coerce(<<value::binary>>, _) do
    case Decimal.parse(value) do
      {value, ""} -> {:ok, value}
      _ -> {:error, [issue("cannot be coerced into Decimal")]}
    end
  end

  defp coerce(value, _), do: {:ok, value}
end
