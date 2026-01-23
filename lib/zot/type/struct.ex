defmodule Zot.Type.Struct do
  @moduledoc ~S"""
  Describes a struct type that works like a strict map but converts
  the result to an Elixir struct.
  """

  use Zot.Template

  deftype module: [t: module],
          shape:  [t: map]

  def module(%Zot.Type.Struct{} = type, module)
      when is_atom(module),
      do: %{type | module: module}

  def shape(%Zot.Type.Struct{} = type, shape)
      when is_non_struct_map(shape),
      do: %{type | shape: shape}
end

defimpl Zot.Type, for: Zot.Type.Struct do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Struct{} = type, value, opts) do
    map_type = Zot.Type.Map.new(mode: :strict, shape: type.shape)

    case Zot.Type.parse(map_type, value, opts) do
      {:ok, result} -> {:ok, struct!(type.module, result)}
      {:error, issues} -> {:error, issues}
      {:error, issues, partial} -> {:error, issues, partial}
    end
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Struct{} = type) do
    map_type = Zot.Type.Map.new(mode: :strict, shape: type.shape)

    Zot.Type.json_schema(map_type)
    |> Map.put("description", type.description)
    |> Map.put("examples", maybe_examples(type.example))
  end
end
