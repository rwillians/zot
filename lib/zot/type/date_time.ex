defmodule Zot.Type.DateTime do
  @moduledoc ~S"""
  A type that accepts date-time values (ISO 8601).
  """

  use Zot.Template

  @typedoc ~S"""
  A relative date-time specification.
  """
  @type relative :: {n :: integer, :millisecond | :second | :minute | :hour | :day | :week | :month | :year, :from_now}

  deftype is_after:  {nil, t: p(nil | DateTime.t() | mfa | (-> DateTime.t()) | relative)},
          is_before: {nil, t: p(nil | DateTime.t() | mfa | (-> DateTime.t()) | relative)}

  @doc ~S"""
  Defines that the input must be a date-time after the given value.
  """
  @opts error: "expected a date-time after %{expected}, got %{actual}"
  def is_after(type, value, opts \\ [])

  def is_after(%Zot.Type.DateTime{} = type, {n, unit, :from_now}, opts)
      when is_integer(n) and is_atom(unit),
      do: %{type | is_after: parameterized({__MODULE__, :from_now, [n, unit]}, @opts, opts)}

  def is_after(%Zot.Type.DateTime{} = type, value, opts)
      when is_nil(value)
      when is_struct(value, DateTime)
      when is_mfa(value)
      when is_function(value, 0),
      do: %{type | is_after: parameterized(value, @opts, opts)}

  @doc ~S"""
  Defines that the input must be a date-time before the given value.
  """
  @opts error: "expected a date-time before %{expected}, got %{actual}"
  def is_before(type, value, opts \\ [])

  def is_before(%Zot.Type.DateTime{} = type, {n, unit, :from_now}, opts)
      when is_integer(n) and is_atom(unit),
      do: %{type | is_before: parameterized({__MODULE__, :__from_now__, [n, unit]}, @opts, opts)}

  def is_before(%Zot.Type.DateTime{} = type, value, opts)
      when is_nil(value)
      when is_struct(value, DateTime)
      when is_mfa(value)
      when is_function(value, 0),
      do: %{type | is_before: parameterized(value, @opts, opts)}

  @doc false
  def __from_now__(n, unit), do: DateTime.add(DateTime.utc_now(), n, unit)
end

defimpl Zot.Type, for: Zot.Type.DateTime do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.DateTime{} = type, value, opts) do
    with {:ok, value} <- coerce(value, coerce?(opts)),
         :ok <- validate_type(value, "DateTime"),
         :ok <- validate_date_time(value, gte: type.is_after, lte: type.is_before),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(%DateTime{} = value, _), do: {:ok, value}

  defp coerce(value, _) when is_binary(value) do
    value = String.replace_trailing(value, "-00:00", "Z")

    case DateTime.from_iso8601(value) do
      {:ok, date_time, _} -> {:ok, date_time}
      {:error, :missing_offset} -> {:error, [issue("is missing the timezone offset")]}
      {:error, _} -> {:error, [issue("is not a valid ISO 8601 date-time string")]}
    end
  end

  defp coerce(value, _), do: {:ok, value}
end
