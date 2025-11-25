defmodule Zot.Type.DateTime do
  @moduledoc ~S"""
  A type that accepts date-time values (ISO 8601).
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.DateTime do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.DateTime{}, value, opts) do
    with :ok <- validate_required(value),
         {:ok, value} <- coerce(value, opts[:coerce] || false),
         :ok <- validate_type(value, "DateTime"),
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
