defmodule Zot.Type.Literal do
  @moduledoc ~S"""
  Describes a literal type that can be either:
  - `boolean`;
  - `atom`;
  - `integer`;
  - `float`; or
  - `string`.
  """

  use Zot.Template

  deftype value: [t: boolean | atom | integer | float | String.t()]

  def value(%Zot.Type.Literal{} = type, value)
      when is_boolean(value),
      do: %{type | value: value, private: %{inner_type: Zot.Type.Boolean.new()}}

  def value(%Zot.Type.Literal{} = type, value)
      when is_integer(value),
      do: %{type | value: value, private: %{inner_type: Zot.Type.Integer.new()}}

  def value(%Zot.Type.Literal{} = type, value)
      when is_float(value),
      do: %{type | value: value, private: %{inner_type: Zot.Type.Float.new()}}

  def value(%Zot.Type.Literal{} = type, value)
      when is_atom(value)
      when is_binary(value),
      do: %{type | value: value, private: %{inner_type: Zot.Type.Enum.new(values: [value])}}
end

defimpl Zot.Type, for: Zot.Type.Literal do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Literal{} = type, value, opts) do
    plain_type =
      case type.private.inner_type do
        %Zot.Type.Boolean{} -> "boolean"
        %Zot.Type.Enum{private: %{inner_type: :atom}} -> "atom"
        %Zot.Type.Enum{private: %{inner_type: :string}} -> "string"
        %Zot.Type.Integer{} -> "integer"
        %Zot.Type.Float{} -> "float"
      end

    with {:ok, value} <- coerce(value, type, coerce_flag(opts)),
         :ok <- validate_type(value, is: plain_type),
         :ok <- validate_equality(value, type.value),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Literal{} = type) do
    %{
      "const" => render(type.value),
      "description" => type.description
    }
  end

  #
  #   PRIVATE
  #

  defp coerce(value, _, false), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: %Zot.Type.Boolean{}}}, _) when is_boolean(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: %Zot.Type.Integer{}}}, _) when is_integer(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: %Zot.Type.Float{}}}, _) when is_float(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: %Zot.Type.Enum{private: %{inner_type: :atom}}}}, _) when is_atom(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: %Zot.Type.Enum{private: %{inner_type: :string}}}}, _) when is_binary(value), do: {:ok, value}
  defp coerce(value, %{private: %{inner_type: inner_type}}, flag), do: Zot.parse(inner_type, value, coerce: flag)

  defp validate_equality(same, same), do: :ok
  defp validate_equality(actual, expected), do: {:error, [issue("must be %{expected}, got %{actual}", expected: expected, actual: actual)]}
end
