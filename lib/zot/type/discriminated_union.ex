defmodule Zot.Type.DiscriminatedUnion do
  @moduledoc ~S"""
  Describes a discriminated union type, which allows values to be one
  of many map types, distinguished by a discriminator field.

  This provides more precise error reporting than regular `union` by
  using a discriminator field to determine which variant to parse.
  """

  use Zot.Template

  deftype discriminator: [t: atom],
          inner_types:   [t: [Zot.Type.Map.t(), ...], default: []]

  def discriminator(%Zot.Type.DiscriminatedUnion{} = type, value)
      when is_atom(value),
      do: %{type | discriminator: value}

  def inner_types(%Zot.Type.DiscriminatedUnion{discriminator: field} = type, [_, _ | _] = value)
      when not is_nil(field) do
    for inner_type <- value,
        do: validate_inner_type!(inner_type, field)

    %{type | inner_types: value}
  end

  #
  #   PRIVATE
  #

  defp validate_inner_type!(%Zot.Type.Map{} = inner_type, discriminator) do
    unless Map.has_key?(inner_type.shape, discriminator) do
      raise ArgumentError,
            "the discriminator field #{inspect(discriminator)} must exist in all map types"
    end

    case inner_type.shape[discriminator] do
      %Zot.Type.Literal{} ->
        :ok

      %mod{} ->
        raise ArgumentError,
              "the discriminator field #{inspect(discriminator)} must be a literal type, got #{inspect(mod)}"
    end
  end

  defp validate_inner_type!(%mod{}, _) do
    raise ArgumentError,
          "discriminated union only accepts map types, got #{inspect(mod)}"
  end
end

defimpl Zot.Type, for: Zot.Type.DiscriminatedUnion do
  use Zot.Commons

  @template "expected field %{field} to be one of %{expected}, got %{actual}"

  @impl Zot.Type
  def parse(%Zot.Type.DiscriminatedUnion{} = type, value, opts) do
    with :ok <- validate_type(value, is: "map") do
      discriminator_value = get_discriminator_value(value, type.discriminator)

      case find_matching_type(type.inner_types, type.discriminator, discriminator_value) do
        {:ok, matching_type} ->
          Zot.parse(matching_type, value, opts)

        :error ->
          expected_values =
            type.inner_types
            |> Enum.map(& &1.shape[type.discriminator])
            |> Enum.map(&get_literal_value/1)
            |> Enum.reject(&is_nil/1)

          ctx = [
            field: {:escaped, to_string(type.discriminator)},
            expected: {:disjunction, expected_values},
            actual: discriminator_value
          ]

          {:error, [issue(@template, ctx)]}
      end
    end
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.DiscriminatedUnion{} = type) do
    %{
      "oneOf" => Enum.map(type.inner_types, &Zot.json_schema/1),
      "discriminator" => %{
        "propertyName" => to_string(type.discriminator)
      }
    }
  end

  #
  #   PRIVATE
  #

  defp get_discriminator_value(map, discriminator) do
    case Map.fetch(map, discriminator) do
      {:ok, value} -> value
      :error -> Map.get(map, to_string(discriminator))
    end
  end

  defp find_matching_type(inner_types, discriminator, discriminator_value) do
    Enum.find_value(inner_types, :error, fn inner_type ->
      expected_value = get_literal_value(inner_type.shape[discriminator])

      if values_match?(expected_value, discriminator_value) do
        {:ok, inner_type}
      else
        nil
      end
    end)
  end

  defp get_literal_value(%Zot.Type.Literal{value: value}), do: value
  defp get_literal_value(_), do: nil

  defp values_match?(expected, actual)
       when is_atom(expected) and is_binary(actual),
       do: to_string(expected) == actual

  defp values_match?(expected, actual)
       when is_binary(expected) and is_atom(actual),
       do: expected == to_string(actual)

  defp values_match?(expected, actual), do: expected == actual
end
