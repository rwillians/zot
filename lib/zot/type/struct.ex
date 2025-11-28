defmodule Zot.Type.Struct do
  @moduledoc ~S"""
  A type that accepts a map with a fixed set of keys and value types,
  parsed into a struct.
  """

  use Zot.Template

  deftype module: {nil, t: module},
          shape:  {nil, t: map}

  @doc ~S"""
  Builds a new `Zot.Type.Struct` type.
  """
  @spec new(module, shape) :: t
        when shape: map | keyword

  def new(module, shape), do: new(module: module, shape: shape)

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
      when is_non_struct_map(value) and map_size(value) > 0
      when is_keyword(value) and length(value) > 0 do
    value = Enum.into(value, %{})
    keys = Map.keys(value)

    meta = %{
      known_fields: build_known_keys_index(value)
    }

    case Enum.all?(keys, &is_atom/1) do
      true -> %{type | shape: value, __meta__: meta}
      false -> raise(ArgumentError, "Only atom keys are allowed in a struct's shape.")
    end
  end
end

defimpl Zot.Type, for: Zot.Type.Struct do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Struct{} = type, value, opts) do
    with :ok <- validate_required(value),
         :ok <- validate_type(value, "map"),
         {:ok, value} <- parse_map(value, type, opts),
         do: {:ok, struct!(type.module, value)}
  end

  #
  #   PRIVATE
  #

  defp parse_map(value, type, opts) do
    known_fields = type.__meta__.known_fields

    unknown_field_issues =
      for key <- Map.keys(value),
          not MapSet.member?(known_fields, key),
          do: prepend_path(issue("unknown field"), [key])

    parser = &Zot.Type.parse(&1, &2, opts)
    {parsed, other_issues} = parse_known_fields(value, type.shape, parser)
    issues = unknown_field_issues ++ other_issues

    case issues do
      [] -> {:ok, parsed}
      [_ | _] -> {:error, issues}
    end
  end
end
