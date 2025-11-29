defmodule Zot.Type.Struct do
  @moduledoc ~S"""
  A type that accepts a map with a fixed set of keys and value types,
  parsed into a struct.
  """

  use Zot.Template

  deftype mode:   {:strict, t: :strip | :strict},
          module: {nil,     t: module},
          shape:  {nil,     t: map}

  @doc ~S"""
  Builds a new `Zot.Type.Struct` type.
  """
  @spec new(module, shape) :: t
        when shape: map | keyword

  def new(module, shape), do: new(module: module, shape: shape)

  @doc ~S"""
  Defines the behaviour for unknown fields.
  """
  def mode(%Zot.Type.Struct{} = type, value)
      when value in [:strip, :strict],
      do: %{type | mode: value}

  @doc ~S"""
  Defines the struct's module.
  """
  def module(%Zot.Type.Struct{} = type, value)
      when is_atom(value),
      do: %{type | module: value}

  @doc ~S"""
  Defines the shape of the struct.
  """
  def shape(%Zot.Type.Struct{} = type, value)
      when is_non_struct_map(value) and map_size(value) > 0 do
    case Enum.all?(Map.keys(value), &is_atom/1) do
      true -> %{type | shape: value}
      false -> raise(ArgumentError, "Only atom keys are allowed in a struct's shape.")
    end
  end
end

defimpl Zot.Type, for: Zot.Type.Struct do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Struct{} = type, value, opts) do
    map_type = Zot.Type.Map.new(mode: type.mode, shape: type.shape)

    with {:ok, value} <- Zot.Type.parse(map_type, value, opts),
         do: {:ok, struct!(type.module, value)}
  end
end
