defmodule Zot.Type.DateTime do
  @moduledoc ~S"""
  Describes a date-time type.
  """

  use Zot.Template

  @typedoc ~S"""
  A time unit.
  """
  @type time_unit :: :second | :minute | :hour | :day | :week | :month | :year

  @typedoc ~S"""
  Relative date time specification.
  """
  @type relative :: {n :: integer, time_unit, :from_now}

  deftype min: [t: Zot.Parameterized.t(DateTime.t() | (-> DateTime.t()) | mfa | relative) | nil],
          max: [t: Zot.Parameterized.t(DateTime.t() | (-> DateTime.t()) | mfa | relative) | nil]

  @opts error: "must be after %{value}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.DateTime{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.DateTime{} = type, value, opts)
      when is_struct(value, DateTime)
      when is_function(value, 0)
      when is_mfa(value)
      when is_relative(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be before %{value}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.DateTime{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.DateTime{} = type, value, opts)
      when is_struct(value, DateTime)
      when is_function(value, 0)
      when is_mfa(value)
      when is_relative(value),
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.DateTime do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.DateTime{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "DateTime"),
         :ok <- validate_min(value, type.min),
         :ok <- validate_max(value, type.max),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.DateTime{} = type) do
    %{
      "description" => type.description,
      "example" => "2026-01-10T10:23:45.123Z",
      "format" => "date-time",
      "nullable" => not type.required,
      "type" => "string"
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(%DateTime{} = value, _), do: {:ok, value}
  defp coerce(value, false), do: {:ok, value}
  defp coerce(<<_, _::binary>> = value, _) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> {:ok, dt}
      {:error, _} -> {:error, [issue("must be a valid ISO8601 date-time string")]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}

  defp validate_min(_, nil), do: :ok
  defp validate_min(value, %Zot.Parameterized{} = min) do
    expected = resolve(min.value)

    frag =
      case min.value do
        {n, unit, :from_now} -> {:escaped, "#{n} #{unit}s from now"}
        _ -> expected
      end

    case DateTime.compare(value, expected) do
      :lt -> {:error, [issue(min.params.error, value: frag)]}
      _ -> :ok
    end
  end

  defp validate_max(_, nil), do: :ok
  defp validate_max(value, %Zot.Parameterized{} = max) do
    expected = resolve(max.value)

    frag =
      case max.value do
        {n, unit, :from_now} -> {:escaped, "#{n} #{unit}s from now"}
        _ -> expected
      end

    case DateTime.compare(value, expected) do
      :gt -> {:error, [issue(max.params.error, value: frag)]}
      _ -> :ok
    end
  end
end
