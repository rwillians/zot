defmodule Zot.Type.Path do
  @moduledoc ~S"""
  Describes a path string type.

  A valid path has non-empty segments separated by single forward
  slashes and may optionally end with a trailing forward slash. It can
  be constrained to absolute paths (leading forward slash) or relative
  paths (no leading forward slash) and can optionally be matched
  against a glob pattern (see `Zot.Utils.glob/1`).
  """

  use Zot.Template

  deftype glob:   [t: Zot.Parameterized.t(Regex.t()) | nil],
          kind:   [t: :absolute | :relative | nil, default: nil],
          length: [t: Zot.Parameterized.t(pos_integer) | nil],
          max:    [t: Zot.Parameterized.t(pos_integer) | nil],
          min:    [t: Zot.Parameterized.t(non_neg_integer) | nil]

  def glob(type, value, opts \\ [])
  def glob(type, nil, _), do: %{type | glob: nil}

  def glob(%Zot.Type.Path{} = type, value, opts)
      when is_binary(value) and byte_size(value) > 0,
      do: %{type | glob: p(Zot.Utils.glob(value), [error: "does not match pattern #{inspect(value)}"], opts)}

  def kind(type, value \\ nil)

  def kind(%Zot.Type.Path{} = type, value)
      when value in [:absolute, :relative, nil],
      do: %{type | kind: value}

  @opts error: "must be %{expected} characters long, got %{actual}"
  def length(type, value, opts \\ [])
  def length(type, nil, _), do: %{type | length: nil}

  def length(%Zot.Type.Path{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | length: p(value, @opts, opts)}

  @opts error: "must be at most %{expected} characters long, got %{actual}"
  def max(type, value, opts \\ [])
  def max(type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Path{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | max: p(value, @opts, opts)}

  @opts error: "must be at least %{expected} characters long, got %{actual}"
  def min(type, value, opts \\ [])
  def min(type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Path{} = type, value, opts)
      when is_integer(value) and value > -1,
      do: %{type | min: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Path do
  use Zot.Commons

  @absolute ~r"^/([^/]{1,}(/[^/]{1,}){0,}/?)?$"
  @relative ~r"^[^/]{1,}(/[^/]{1,}){0,}/?$"
  @any ~r"^(/([^/]{1,}(/[^/]{1,}){0,}/?)?|[^/]{1,}(/[^/]{1,}){0,}/?)$"

  @impl Zot.Type
  def parse(%Zot.Type.Path{} = type, value, _) do
    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_kind(value, type.kind),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
         :ok <- validate_regex(value, type.glob),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Path{} = type) do
    %{
      "description" => type.description,
      "examples" => maybe_examples(type.example),
      "maxLength" => dump(type.max) || dump(type.length),
      "minLength" => dump(type.min) || dump(type.length),
      "pattern" => dump(type.glob) || Regex.source(pattern(type.kind)),
      "type" => maybe_nullable("string", type.required)
    }
  end

  #
  #   PRIVATE
  #

  defp validate_kind(value, kind) do
    case Regex.match?(pattern(kind), value) do
      true -> :ok
      false -> {:error, [issue(error(kind))]}
    end
  end

  defp pattern(nil), do: @any
  defp pattern(:absolute), do: @absolute
  defp pattern(:relative), do: @relative

  defp error(nil), do: "is not a valid path"
  defp error(:absolute), do: "is not a valid absolute path"
  defp error(:relative), do: "is not a valid relative path"
end
