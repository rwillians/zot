defmodule Zot.Type.Enum do
  @moduledoc ~S"""
  Describes an enum type.
  """

  use Zot.Template

  deftype values: [t: [atom, ...] | [String.t(), ...]]

  @opts error: "must be %{expected}, got %{actual}"
  def values(%Zot.Type.Enum{} = type, [_ | _] = values, opts \\ []) do
    inner_type =
      cond do
        Enum.all?(values, &is_atom/1) -> :atom
        Enum.all?(values, &is_binary/1) -> :string
        true -> raise ArgumentError, "values must be a list of all atoms or all strings"
      end

    %{type | values: p(values, @opts, opts), private: %{inner_type: inner_type}}
  end
end

defimpl Zot.Type, for: Zot.Type.Enum do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Enum{} = type, value, opts) do
    with {:ok, value} <- coerce(value, type, coerce_flag(opts)),
         :ok <- validate_inclusion(value, type.values),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Enum{} = type) do
    %{
      "description" => type.description,
      "enum" => render(type.values),
      "example" => render(type.example || List.first(type.values)),
      "type" => json_type("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, _, false), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: :atom}}, _) when is_atom(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: :string}}, _) when is_binary(value), do: {:ok, value}
  # ↓ coerce from string to atom
  defp coerce(value, %{private: %{inner_type: :atom}, values: %Zot.Parameterized{} = values}, _) when is_binary(value) do
    string_values = Enum.map(values.value, &to_string/1)

    case value in string_values do
      true -> {:ok, String.to_existing_atom(value)}
      false -> {:ok, value}
    end
  end
  # ↓ coerce from atom to string
  defp coerce(value, %{private: %{inner_type: :string}, values: %Zot.Parameterized{} = values}, _) when is_atom(value) do
    string_value = to_string(value)

    case string_value in values.value do
      true -> {:ok, string_value}
      false -> {:ok, value}
    end
  end
  # ↓ let validate_type/2 handle it
  defp coerce(value, _, _), do: {:ok, value}
end
