defmodule Zot.Type.Numeric do
  @moduledoc ~S"""
  Describes a numeric string type.
  """

  use Zot.Template

  deftype min: [t: Zot.Parameterized.t(pos_integer) | nil],
          max: [t: Zot.Parameterized.t(pos_integer) | nil]

  @opts error: "must be at least %{expected} characters long, got %{actual}"
  def min(type, value, opts \\ [])
  def min(%Zot.Type.Numeric{} = type, nil, _), do: %{type | min: nil}

  def min(%Zot.Type.Numeric{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | min: p(value, @opts, opts)}

  @opts error: "must be at most %{expected} characters long, got %{actual}"
  def max(type, value, opts \\ [])
  def max(%Zot.Type.Numeric{} = type, nil, _), do: %{type | max: nil}

  def max(%Zot.Type.Numeric{} = type, value, opts)
      when is_integer(value) and value > 0,
      do: %{type | max: p(value, @opts, opts)}
end

defimpl Zot.Type, for: Zot.Type.Numeric do
  use Zot.Commons

  @impl Zot.Type
  def parse(%Zot.Type.Numeric{} = type, value, _) do
    regex = Zot.Parameterized.new(~r/^[0-9]+$/, error: "must contain only 0-9 digits")

    with :ok <- validate_type(value, is: "string"),
         :ok <- validate_regex(value, regex),
         :ok <- validate_length(value, min: type.min, max: type.max),
         do: {:ok, value}
  end

  @impl Zot.Type
  def json_schema(%Zot.Type.Numeric{} = type) do
    %{
      "description" => type.description,
      "example" => type.example,
      "maxLength" => render(type.max),
      "minLength" => render(type.min),
      "pattern" => "^[0-9]+$",
      "type" => "string"
    }
  end
end
