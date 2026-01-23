defmodule Zot.Type.Decimal do
  @moduledoc ~S"""
  Describes a decimal type.
  """

  use Zot.Template

  deftype min:       [t: Zot.Parameterized.t(Decimal.t()) | nil],
          max:       [t: Zot.Parameterized.t(Decimal.t()) | nil],
          precision: [t: non_neg_integer | nil]

  @opts error: "must be at least %{expected}, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Decimal{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Decimal{} = type, value, opts)
      when is_integer(value)
      when is_float(value)
      when is_struct(value, Decimal),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be at most %{expected}, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Decimal{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Decimal{} = type, value, opts)
      when is_integer(value)
      when is_float(value)
      when is_struct(value, Decimal),
      do: %{type | max: p(value, @opts, opts)}

  def precision(%Zot.Type.Decimal{} = type, value)
      when is_nil(value)
      when is_integer(value) and value >= 0,
      do: %{type | precision: value}
end

defimpl Zot.Type, for: Zot.Type.Decimal do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Decimal{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "Decimal"),
         :ok <- validate_number(value, min: type.min, max: type.max),
         value <- apply_precision(value, type.precision),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Decimal{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "maximum" => dump(type.max),
      "minimum" => dump(type.min),
      "type" => maybe_nullable("number", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(%Decimal{} = value, _), do: {:ok, value}
  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, Decimal.new(value)}
  defp coerce(value, _) when is_float(value), do: {:ok, Decimal.from_float(value)}
  defp coerce(value, _) when is_binary(value) do
    case Decimal.parse(value) do
      {%Decimal{} = dec, ""} -> {:ok, dec}
      _ -> {:error, [issue("cannot be coerced to Decimal")]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}

  defp apply_precision(value, nil), do: value
  defp apply_precision(value, precision), do: Decimal.round(value, precision)
end
