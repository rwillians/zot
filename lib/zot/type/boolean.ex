defmodule Zot.Type.Boolean do
  @moduledoc ~S"""
  Describes a type that accepts boolean values.
  """
  @moduledoc since: "0.1.0"

  use Zot.Template

  deftype []
end

defimpl Zot.Type, for: Zot.Type.Boolean do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Boolean{}, value, opts \\ []) do
    with {:ok, value} <- coerce(value, get_coerce_flag(opts)),
        :ok <- validate_type(value, is: "boolean"),
        do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp coerce(value, false), do: {:ok, value}
  defp coerce(value, _) when is_boolean(value), do: {:ok, value}
  defp coerce(value, _) when value in [1, 0], do: {:ok, value == 1}

  @truthy ["true", "1", "on", "enabled"]
  @falsy ["false", "0", "off", "disabled"]
  defp coerce(value, _) when is_binary(value) do
    case String.downcase(value) do
      str when str in @truthy -> {:ok, true}
      str when str in @falsy -> {:ok, false}
      str -> {:error, [issue("cannot coerce %{value} into boolean", value: str)]}
    end
  end

  # let it fail in the type validation
  defp coerce(value, _), do: {:ok, value}
end
