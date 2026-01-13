defmodule Zot.Type.String do
  @moduledoc ~S"""
  Describes a string type.
  """

  use Zot.Template

  deftype contains:    [t: Zot.Parameterized.t(String.t()) | nil],
          ends_with:   [t: Zot.Parameterized.t(String.t()) | nil],
          length:      [t: Zot.Parameterized.t(pos_integer) | nil],
          max:         [t: Zot.Parameterized.t(pos_integer) | nil],
          min:         [t: Zot.Parameterized.t(non_neg_integer) | nil],
          regex:       [t: Zot.Parameterized.t(Regex.t()) | nil],
          starts_with: [t: Zot.Parameterized.t(String.t()) | nil],
          trim:        [t: boolean, default: false]

  @opts error: "must contain %{substring}"
  def contains(type, value, opts \\ [])
  def contains(type, nil, _), do: %{type | contains: nil}

  def contains(%Zot.Type.String{} = type, value, opts)
      when is_binary(value) and byte_size(value) > 0,
      do: %{type | contains: p(value, @opts, opts)}

  @opts error: "must end with %{substring}"
  def ends_with(type, value, opts \\ [])
  def ends_with(type, nil, _), do: %{type | ends_with: nil}

  def ends_with(%Zot.Type.String{} = type, value, opts)
      when is_binary(value) and byte_size(value) > 0,
      do: %{type | ends_with: p(value, @opts, opts)}

  @opts error: "must be %{expected} characters long, got %{actual}"
  def length(type, value, opts \\ [])
  def length(type, nil, _), do: %{type | length: nil}

  def length(%Zot.Type.String{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | length: p(value, @opts, opts)}

  @opts error: "must be at most %{expected} characters long, got %{actual}"
  def max(type, value, opts \\ [])
  def max(type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.String{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | max: p(value, @opts, opts)}

  @opts error: "must be at least %{expected} characters long, got %{actual}"
  def min(type, value, opts \\ [])
  def min(type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.String{} = type, value, opts)
      when is_integer(value) and value > -1,
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must match pattern %{pattern}"
  def regex(type, value, opts \\ [])
  def regex(type, nil, _), do: %{type | regex: nil}

  def regex(%Zot.Type.String{} = type, value, opts)
      when is_struct(value, Regex),
      do: %{type | regex: p(value, @opts, opts)}

  @opts error: "must start with %{substring}"
  def starts_with(type, value, opts \\ [])
  def starts_with(type, nil, _), do: %{type | starts_with: nil}

  def starts_with(%Zot.Type.String{} = type, value, opts)
      when is_binary(value) and byte_size(value) > 0,
      do: %{type | starts_with: p(value, @opts, opts)}

  def trim(%Zot.Type.String{} = type, value \\ true)
      when is_boolean(value),
      do: %{type | trim: value}
end

defimpl Zot.Type, for: Zot.Type.String do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.String{} = type, value, _) do
    value =
      case is_binary(value) and type.trim do
        true -> String.trim(value)
        false -> value
      end

    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_contains(value, type.contains),
         :ok <- validate_ends_with(value, type.ends_with),
         :ok <- validate_length(value, is: type.length, min: type.min, max: type.max),
         :ok <- validate_regex(value, type.regex),
         :ok <- validate_starts_with(value, type.starts_with),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.String{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "maxLength" => render(type.max) || render(type.length),
      "minLength" => render(type.min) || render(type.length),
      "nullable" => not type.required,
      "pattern" => render(type.regex),
      "type" => "string"
    }
  end

  #
  #   PRIVATE
  #

  defp validate_contains(_, nil), do: :ok
  defp validate_contains(value, contains) when is_binary(value) do
    case String.contains?(value, contains.value) do
      true -> :ok
      false -> {:error, [issue(contains.params.error, substring: contains.value)]}
    end
  end

  defp validate_ends_with(_, nil), do: :ok
  defp validate_ends_with(value, ends_with) when is_binary(value) do
    case String.ends_with?(value, ends_with.value) do
      true -> :ok
      false -> {:error, [issue(ends_with.params.error, substring: ends_with.value)]}
    end
  end

  defp validate_starts_with(_, nil), do: :ok
  defp validate_starts_with(value, starts_with) when is_binary(value) do
    case String.starts_with?(value, starts_with.value) do
      true -> :ok
      false -> {:error, [issue(starts_with.params.error, substring: starts_with.value)]}
    end
  end
end
