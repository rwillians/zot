defmodule Zot.Type.Date do
  @moduledoc ~S"""
  Describes a date type.
  """

  use Zot.Template

  @typedoc ~S"""
  A time unit.
  """
  @type time_unit :: :day | :week | :month | :year

  @typedoc ~S"""
  Relative date specification.
  """
  @type relative :: {n :: integer, time_unit, :from_now}

  @time_units [:day, :week, :month, :year]

  deftype min: [t: Zot.Parameterized.t(Date.t() | (-> Date.t()) | mfa | relative) | nil],
          max: [t: Zot.Parameterized.t(Date.t() | (-> Date.t()) | mfa | relative) | nil]

  @opts error: "must be after %{value}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Date{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Date{} = type, {n, unit, :from_now} = value, opts)
      when is_integer(n) and unit in @time_units,
      do: %{type | min: p(value, @opts, opts)}

  def min(%Zot.Type.Date{} = type, value, opts)
      when is_struct(value, Date)
      when is_function(value, 0)
      when is_mfa(value),
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be before %{value}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Date{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Date{} = type, {n, unit, :from_now} = value, opts)
      when is_integer(n) and unit in @time_units,
      do: %{type | max: p(value, @opts, opts)}

  def max(%Zot.Type.Date{} = type, value, opts)
      when is_struct(value, Date)
      when is_function(value, 0)
      when is_mfa(value),
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Date do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Date{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "Date"),
         :ok <- validate_min(value, type.min),
         :ok <- validate_max(value, type.max),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Date{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "format" => "date",
      "type" => maybe_nullable("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(%Date{} = value, _), do: {:ok, value}
  defp coerce(value, false), do: {:ok, value}

  defp coerce(<<_, _::binary>> = value, _) do
    case Date.from_iso8601(value) do
      {:ok, date} -> {:ok, date}
      {:error, _} -> {:error, [issue("must be a valid ISO8601 date string")]}
    end
  end

  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}

  defp validate_min(_, nil), do: :ok

  defp validate_min(value, %Zot.Parameterized{} = min) do
    expected = resolve_date(min.value)

    frag =
      case min.value do
        {n, unit, :from_now} -> {:escaped, "#{n} #{unit}s from now"}
        _ -> expected
      end

    case Date.compare(value, expected) do
      :lt -> {:error, [issue(min.params.error, value: frag)]}
      _ -> :ok
    end
  end

  defp validate_max(_, nil), do: :ok

  defp validate_max(value, %Zot.Parameterized{} = max) do
    expected = resolve_date(max.value)

    frag =
      case max.value do
        {n, unit, :from_now} -> {:escaped, "#{n} #{unit}s from now"}
        _ -> expected
      end

    case Date.compare(value, expected) do
      :gt -> {:error, [issue(max.params.error, value: frag)]}
      _ -> :ok
    end
  end

  defp resolve_date(value) do
    case resolve(value) do
      %Date{} = date -> date
      %DateTime{} = dt -> DateTime.to_date(dt)
    end
  end
end
