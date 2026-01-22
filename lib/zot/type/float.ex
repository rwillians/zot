defmodule Zot.Type.Float do
  @moduledoc ~S"""
  Describes a float type.
  """

  use Zot.Template

  deftype min: [t: Zot.Parameterized.t(number) | nil],
          max: [t: Zot.Parameterized.t(number) | nil],
          precision: [t: non_neg_integer | nil]

  @opts error: "must be at least %{expected}, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Float{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Float{} = type, value, opts)
      when is_number(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be at most %{expected}, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Float{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Float{} = type, value, opts)
      when is_number(value),
      do: %{type | max: p(value, @opts, opts)}

  def precision(%Zot.Type.Float{} = type, value)
      when is_nil(value)
      when is_integer(value) and value >= 0,
      do: %{type | precision: value}
end

defimpl Zot.Type, for: Zot.Type.Float do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Float{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "float"),
         :ok <- validate_number(value, min: type.min, max: type.max),
         value <- apply_precision(value, type.precision),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Float{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "maximum" => render(type.max),
      "minimum" => render(type.min),
      "type" => json_type("number", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_float(value), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, value * 1.0}
  defp coerce(%Decimal{} = value, _), do: {:ok, Decimal.to_float(value)}
  defp coerce(value, _) when is_binary(value) do
    case parse_float(value) do
      {:ok, float} -> {:ok, float}
      :error -> {:error, [issue("cannot be coerced to float")]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}

  defp apply_precision(value, nil), do: value
  defp apply_precision(value, precision), do: Float.round(value, precision)
end
