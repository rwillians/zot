defmodule Zot.Type.Map do
  @moduledoc ~S"""
  Describes a map type.
  """

  use Zot.Template

  deftype shape: [t: map],
          mode: [t: :strict | :strip, default: :strip]

  def shape(%Zot.Type.Map{} = type, shape)
      when is_non_struct_map(shape),
      do: %{type | shape: shape}

  def mode(%Zot.Type.Map{} = type, mode)
      when mode in [:strict, :strip],
      do: %{type | mode: mode}
end

defimpl Zot.Type, for: Zot.Type.Map do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Map{} = type, value, opts) do
    with :ok <- validate_type(value, is: "map"),
         do: do_parse(value, type, opts)
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Map{} = type) do
    %{
      "additionalProperties" => type.mode == :strip,
      "description" => type.description,
      "example" => type.example,
      "properties" =>
        type.shape
        |> Enum.map(fn {key, t} -> {to_string(key), Zot.json_schema(t)} end)
        |> Enum.into(%{}),
      "required" =>
        type.shape
        |> Enum.filter(fn {_, t} -> t.required end)
        |> Enum.map(fn {key, _} -> to_string(key) end),
      "type" => "object"
    }
  end

  #
  #   PRIVATE
  #

  defp do_parse(input, %Zot.Type.Map{mode: :strip} = type, opts) do
    {parsed, issues} = parse_known_fields(type.shape, input, opts)

    case {issues, map_size(parsed)} do
      {[], _} -> {:ok, parsed}
      {[_ | _], 0} -> {:error, issues}
      {[_ | _], n} when n > 0 -> {:error, issues, parsed}
    end
  end

  defp do_parse(input, %Zot.Type.Map{mode: :strict} = type, opts) do
    known_fields =
      type.shape
      |> Map.keys()
      |> Enum.map(&to_string/1)

    given_fields =
      input
      |> Map.keys()
      |> Enum.map(&to_string/1)

    unknown_field_issues =
      (given_fields -- known_fields)
      |> Enum.map(&issue([&1], "unknown field"))

    {parsed, issues} = parse_known_fields(type.shape, input, opts)
    issues = issues ++ unknown_field_issues

    case {issues, map_size(parsed)} do
      {[], _} -> {:ok, parsed}
      {[_ | _], 0} -> {:error, issues}
      {[_ | _], n} when n > 0 -> {:error, issues, parsed}
    end
  end

  defp get(map, key) do
    {:ok, value} =
      with :error <- Map.fetch(map, key),
           :error <- Map.fetch(map, to_string(key)),
           do: {:ok, nil}

    value
  end

  defp parse_known_fields(shape, map, opts) do
    Enum.reduce(shape, {%{}, []}, fn {key, type}, {acc_parsed, acc_issues} ->
      result =
        Zot.Context.new(type, get(map, key), opts)
        |> Zot.Context.put_path([key])
        |> Zot.Context.parse()
        |> Zot.Context.unwrap()

      case result do
        {:ok, val} -> {Map.put(acc_parsed, key, val), acc_issues}
        {:error, issues} -> {acc_parsed, acc_issues ++ issues}
      end
    end)
  end
end
