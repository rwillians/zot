defmodule Zot.Type.Integer do
  @moduledoc ~S"""
  Describes a integer type.
  """

  use Zot.Template

  deftype min: [t: Zot.Parameterized.t(integer) | nil],
          max: [t: Zot.Parameterized.t(integer) | nil]

  @opts error: "must be at least %{expected}, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Integer{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Integer{} = type, value, opts)
      when is_integer(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be at most %{expected}, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Integer{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Integer{} = type, value, opts)
      when is_integer(value),
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Integer do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Integer{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "integer"),
         :ok <- validate_number(value, min: type.min, max: type.max),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Integer{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "maximum" => render(type.max),
      "minimum" => render(type.min),
      "type" => json_type("integer", type.required)
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
end
