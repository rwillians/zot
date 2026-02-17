defmodule Zot.Type.Branded do
  @moduledoc ~S"""
  Describes a branded type.
  """

  use Zot.Template

  deftype brand:      [t: atom],
          inner_type: [t: Zot.Type.t()]

  def brand(%Zot.Type.Branded{} = type, value)
      when is_atom(value),
      do: %{type | brand: value}

  def inner_type(%Zot.Type.Branded{} = type, type(_) = value)
      when is_struct(value),
      do: %{type | inner_type: value}
end

defimpl Zot.Type, for: Zot.Type.Branded do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Branded{} = type, value, opts) do
    case Zot.parse(type.inner_type, value, opts) do
      {:ok, value} -> {:ok, {type.brand, value}}
      error -> error
    end
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Branded{} = type) do
    examples =
      with {:a, nil} <- {:a, type.example},
           {:b, nil} <- {:b, type.inner_type.example} do
        nil
      else
        {:a, {brand, value}} -> [[Atom.to_string(brand), dump(value)]]
        {:b, value} -> [[Atom.to_string(type.brand), dump(value)]]
      end

    %{
      "description" => type.description,
      "examples" => examples,
      "items" => false,
      "maxItems" => 2,
      "minItems" => 2,
      "prefixItems" => [
        %{"const" => Atom.to_string(type.brand)},
        Zot.json_schema(type.inner_type)
      ],
      "type" => "array",
    }
  end
end
