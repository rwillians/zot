defmodule Zot.Type.Boolean do
  @moduledoc ~S"""
  Describes a boolean type.
  """

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Boolean do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Boolean{}, value, opts) do
    with {:ok, value} <- coerce(value, coerce_flag(opts)),
         :ok <- validate_type(value, is: "boolean"),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Boolean{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "type" => maybe_nullable("boolean", type.required)
    }
  end

  #
  #   PRIVATE
  #

  @boolean_like ["true", "enabled", "on", "yes", "false", "disabled", "off", "no"]

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_boolean(value), do: {:ok, value}
  defp coerce(1, _), do: {:ok, true}
  defp coerce(0, _), do: {:ok, false}
  defp coerce(value, _) when is_binary(value) do
    case String.downcase(value) do
      "enabled" -> {:ok, true}
      "on" -> {:ok, true}
      "true" -> {:ok, true}
      "yes" -> {:ok, true}
      "disabled" -> {:ok, false}
      "off" -> {:ok, false}
      "false" -> {:ok, false}
      "no" -> {:ok, false}
      actual -> {:error, [issue("expected a boolean-like string (%{expected}), got %{actual}", expected: {:disjunction, @boolean_like}, actual: actual)]}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _), do: {:ok, value}
end
