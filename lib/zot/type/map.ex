defmodule Zot.Type.Map do
  @moduledoc ~S"""
  A type that accepts maps of a known shape.
  """

  use Zot.Template

  deftype mode:  {:strip, t: :strip | :strict},
          shape: {nil,    t: map}

  @doc ~s"""
  Builds a new `Zot.Type.Map` from the given mode and shape.
  """
  @spec new(mode, shape) :: t
        when mode: :strip | :strict,
             shape: map | keyword

  def new(mode, shape), do: new(mode: mode, shape: shape)

  @doc ~S"""
  Defines the parsing mode:
  - `:strip` - removes any keys not defined in the shape.
  - `:strict` - produces an issue for each present key that's not
    defined in the shape.
  """
  def mode(%Zot.Type.Map{} = type, value)
      when value in [:strip, :strict],
      do: %{type | mode: value}

  @doc ~S"""
  Defines the shape of the map.
  """
  def shape(%Zot.Type.Map{} = type, value)
      when is_non_struct_map(value) and map_size(value) > 0 do
    atom_keys = Map.keys(value)

    private = %{
      known_fields: build_known_keys_index(value)
    }

    case Enum.all?(atom_keys, &is_atom/1) do
      true -> %{type | shape: Enum.into(value, %{}), __private__: private}
      false -> raise(ArgumentError, "Only atom keys are allowed in a map's shape.")
    end
  end
end

defimpl Zot.Type, for: Zot.Type.Map do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Map{} = type, value, opts) do
    with :ok <- validate_type(value, "map"),
         {:ok, value} <- parse_map(value, type, opts),
         do: {:ok, value}
  end

  #
  #   PRIVATE
  #

  defp parse_map(value, %{mode: :strip} = type, opts) do
    parser = &Zot.Type.parse(&1, &2, opts)
    {parsed, issues} = parse_known_fields(value, type.shape, parser)

    case issues do
      [] -> {:ok, parsed}
      [_ | _] -> {:error, issues}
    end
  end

  defp parse_map(value, %{mode: :strict} = type, opts) do
    known_fields = type.__private__.known_fields

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

  defp parse_known_fields(input, %{} = shape, parser) do
    Enum.reduce(shape, {%{}, []}, fn {key, type}, {acc_parsed, acc_issues} ->
      {input_key, input_val} = discover_value(input, key)

      case parser.(type, input_val) do
        {:ok, val} -> {Map.put(acc_parsed, key, val), acc_issues}
        {:error, issues} -> {acc_parsed, acc_issues ++ Enum.map(issues, &prepend_path(&1, [input_key]))}
      end
    end)
  end

  defp discover_value(input, atom_key) do
    string_key = to_string(atom_key)

    with {_, :error} <- {atom_key, Map.fetch(input, atom_key)},
          {_, :error} <- {string_key, Map.fetch(input, string_key)} do
      {atom_key, nil}
    else
      {key, {:ok, value}} -> {key, value}
    end
  end
end
