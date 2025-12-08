defmodule Zot.Type.Boolean do
  @moduledoc ~S"""
  Describes a type that accepts boolean values.
  """
  @moduledoc since: "0.1.0"

  use Zot.Template

  deftype []

  def new, do: %__MODULE__{}
end

defimpl Zot.Type, for: Zot.Type.Boolean do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Boolean{}, value, opts \\ []) do
    with {:ok, value} <- coerce(opts[:coerce], value),
        :ok <- validate_type(value, is: "boolean"),
        do: {:ok, value}
  end

  defp coerce(nil, value), do: {:ok, value}
  defp coerce(false, value), do: {:ok, value}
  defp coerce(_, value) when is_boolean(value), do: {:ok, value}
  defp coerce(_, value) when value in [1, 0], do: {:ok, value == 1}

  @truthy ["true", "1", "on", "enabled"]
  @falsy ["false", "0", "off", "disabled"]
  defp coerce(_, value) when is_binary(value) do
    case String.downcase(value) do
      str when str in @truthy -> {:ok, true}
      str when str in @falsy -> {:ok, false}
      str -> {:error, [issue("cannot coerce %{value} into boolean", value: str)]}
    end
  end

  # let it fail in the type validation
  defp coerce(_, value), do: {:ok, value}
end
