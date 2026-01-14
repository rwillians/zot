defmodule Zot.Type.Number do
  @moduledoc ~S"""
  Describes a number type (union of integer and float).
  """

  use Zot.Template

  deftype min: [t: Zot.Parameterized.t(number) | nil],
          max: [t: Zot.Parameterized.t(number) | nil]

  @opts error: "must be at least %{expected}, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Number{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Number{} = type, value, opts)
      when is_number(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be at most %{expected}, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Number{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Number{} = type, value, opts)
      when is_number(value),
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Number do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Number{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "number"),
         :ok <- validate_number(value, min: type.min, max: type.max),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Number{} = type) do
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
  defp coerce(value, _) when is_integer(value), do: {:ok, value}
  defp coerce(%Decimal{} = value, _), do: {:ok, Decimal.to_float(value)}
  defp coerce(value, _) when is_binary(value) do
    with :error <- parse_integer(value),
         :error <- parse_float(value) do
      {:error, [issue("cannot be coerced to number")]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}
end
