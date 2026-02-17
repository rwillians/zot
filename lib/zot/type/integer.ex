defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Describes a integer type.
  """

  use Zot.Template

  deftype min:   [t: Zot.Parameterized.t(integer) | nil],
          max:   [t: Zot.Parameterized.t(integer) | nil],
          range: [t: Zot.Parameterized.t(Range.t()) | nil]

  @opts error: "must be within range %{expected}, got %{actual}"
  def range(type, value, opts \\ [])
  def range(%Zot.Type.Integer{} = type, nil, _), do: %{type | range: nil}

  def range(%Zot.Type.Integer{min: nil, max: nil} = type, %Range{} = value, opts),
    do: %{type | range: p(value, @opts, opts)}

  def range(%Zot.Type.Integer{}, %Range{}, _),
    do: raise(ArgumentError, "cannot use :range when :min or :max is defined")

  @opts error: "must be at least %{expected}, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Integer{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Integer{range: nil} = type, value, opts)
      when is_integer(value),
      do: %{type | min: p(value, @opts, opts)}

  def min(%Zot.Type.Integer{range: %Zot.Parameterized{}}, _, _),
    do: raise(ArgumentError, "cannot use :min when a :range is defined")

  @opts error: "must be at most %{expected}, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Integer{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Integer{range: nil} = type, value, opts)
      when is_integer(value),
      do: %{type | max: p(value, @opts, opts)}

  def max(%Zot.Type.Integer{range: %Zot.Parameterized{}}, _, _),
    do: raise(ArgumentError, "cannot use :max when a :range is defined")
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "integer"),
         :ok <- validate_number(value, min: type.min, max: type.max),
         :ok <- validate_range(value, type.range),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Integer{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "maximum" => dump(first(type.range)) || dump(type.max),
      "minimum" => dump(last(type.range)) || dump(type.min),
      "type" => maybe_nullable("integer", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_integer(value), do: {:ok, value}
  defp coerce(value, _) when is_float(value), do: {:ok, round(value)}
  defp coerce(%Decimal{} = value, _), do: {:ok, value |> Decimal.round(0) |> Decimal.to_integer()}
  defp coerce(value, _) when is_binary(value) do
    case parse_integer(value) do
      {:ok, int} -> {:ok, int}
      :error -> {:error, [issue("cannot be coerced to integer")]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}

  defp first(%Range{} = range), do: range.first
  defp first(_), do: nil

  defp last(%Range{} = range), do: range.last
  defp last(_), do: nil
end
