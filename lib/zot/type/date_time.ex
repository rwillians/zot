defmodule Zot.Type.DateTime do
  @moduledoc ~S"""
  Describes a type that accepts DateTime or ISO 8601 strings (when
  coercion is enabled).
  """
  @moduledoc since: "0.1.0"

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.DateTime do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.DateTime{}, value, opts) do
    with {:ok, value} <- coerce(value, opts[:coerce] || false),
         :ok <- validate_type(value, is: "DateTime"),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(%DateTime{} = value, _), do: {:ok, value}

  defp coerce(value, _) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _} -> {:ok, dt}
      {:error, _} -> {:error, [issue("cannot coerce %{value} into DateTime", value: value)]}
    end
  end

  defp coerce(value, _), do: {:ok, value}
end
