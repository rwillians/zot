defmodule Zot.Type.SlugRFC1123 do
  @moduledoc ~S"""
  Describes an RFC 1123 slug (DNS label) string type.

  A valid slug contains only lowercase alphanumeric characters and
  hyphens, starts and ends with an alphanumeric character and is at
  most 63 characters long.
  """

  use Zot.Template

  deftype length: [t: Zot.Parameterized.t(pos_integer) | nil],
          max:    [t: Zot.Parameterized.t(pos_integer), default: 63],
          min:    [t: Zot.Parameterized.t(pos_integer), default: 1],
          trim:   [t: boolean, default: false]

  @opts error: "must be %{expected} characters long, got %{actual}"
  def length(type, value, opts \\ [])
  def length(type, nil, _), do: %{type | length: nil}

  def length(%Zot.Type.SlugRFC1123{} = type, value, opts)
      when is_integer(value) and value > 0 and value < 64,
      do: %{type | length: p(value, @opts, opts)}

  @opts error: "must be at most %{expected} characters long, got %{actual}"
  def max(type, value, opts \\ [])
  def max(type, nil, _), do: %{type | max: p(63, @opts, [])}

  def max(%Zot.Type.SlugRFC1123{} = type, value, opts)
      when is_integer(value) and value > 0 and value < 64,
      do: %{type | max: p(value, @opts, opts)}

  @opts error: "must be at least %{expected} characters long, got %{actual}"
  def min(type, value, opts \\ [])
  def min(type, nil, _), do: %{type | min: p(1, @opts, [])}

  def min(%Zot.Type.SlugRFC1123{} = type, value, opts)
      when is_integer(value) and value > 0 and value < 64,
      do: %{type | min: p(value, @opts, opts)}

  def trim(%Zot.Type.SlugRFC1123{} = type, value \\ true)
      when is_boolean(value),
      do: %{type | trim: value}
end

defimpl Zot.Type, for: Zot.Type.SlugRFC1123 do
  use Zot.Commons

  @regex ~r/^[a-z0-9]([a-z0-9-]{0,}[a-z0-9])?$/
  @error "is not a valid RFC 1123 slug"

  @impl Zot.Type
  def parse(%Zot.Type.SlugRFC1123{} = type, value, opts),
    do: Zot.Type.parse(to_string_type(type), value, opts)

  @impl Zot.Type
  def json_schema(%Zot.Type.SlugRFC1123{} = type) do
    Zot.Type.json_schema(to_string_type(type))
    |> Map.put("description", type.description)
    |> Map.put("examples", maybe_examples(type.example))
  end

  #
  #   PRIVATE
  #

  defp to_string_type(%Zot.Type.SlugRFC1123{} = type) do
    %{
      Zot.Type.String.new(trim: type.trim)
      | length: type.length,
        max: type.max,
        min: type.min,
        regex: Zot.Parameterized.new(@regex, error: @error),
        required: type.required
    }
  end
end
