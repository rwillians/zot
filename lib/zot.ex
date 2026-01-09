defmodule Zot do
  @moduledoc ~S"""
  Schema parser and validator for Elixir.
  """

  alias Zot.Context

  defmacrop type(var) do
    quote do
      %unquote(var){__zot_type__: true}
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                            CORE API                             #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Parses the given input according to the given type.
  """
  @spec parse(type, input, [option]) ::
          {:ok, output}
          | {:error, [Zot.Issue.t(), ...]}
        when type: Zot.Type.t(),
             input: term,
             option: {:coerce, boolean | :unsafe},
             output: term

  def parse(%_{} = type, input, opts \\ []) do
    Context.new(type, input, opts)
    |> Context.parse()
    |> Context.unwrap()
  end

  @doc ~S"""
  Converts the given type into a JSON Schema.

  ## Examples

      iex> Z.string(starts_with: "u_", length: 28)
      iex> |> Z.description("A user id.")
      iex> |> Z.example("u_12345678901234567890123456")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "description" => "A user id.",
        "example" => "u_12345678901234567890123456",
        "nullable" => false,
        "minLength" => 28,
        "maxLength" => 28
      }

  """
  @spec json_schema(type) :: map
        when type: Zot.Type.t()

  def json_schema(type(_) = type) do
    Zot.Type.json_schema(type)
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                              TYPES                              #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Creates a string type.

  ## Examples

      iex> Z.string()
      iex> |> Z.parse("hello world")
      {:ok, "hello world"}

  Can enforce that the string contains a given substring:

      iex> Z.string(contains: "foo")
      iex> |> Z.parse("bar baz")
      iex> |> unwrap_issue_message()
      "must contain \"foo\""

      iex> Z.string()
      iex> |> Z.contains("foo")
      iex> |> Z.parse("bar baz")
      iex> |> unwrap_issue_message()
      "must contain \"foo\""

  Can enforce a string length:

      iex> Z.string(length: 5)
      iex> |> Z.parse("hey")
      iex> |> unwrap_issue_message()
      "must be 5 characters long"

      iex> Z.string()
      iex> |> Z.length(5)
      iex> |> Z.parse("hey")
      iex> |> unwrap_issue_message()
      "must be 5 characters long"

  Can enforce a minimum string length:

      iex> Z.string(min: 3)
      iex> |> Z.parse("hi")
      iex> |> unwrap_issue_message()
      "must be at least 3 characters long"

      iex> Z.string()
      iex> |> Z.min(3)
      iex> |> Z.parse("hi")
      iex> |> unwrap_issue_message()
      "must be at least 3 characters long"

  Can enforce a maximum string length:

      iex> Z.string(max: 10)
      iex> |> Z.parse("this is a very long string")
      iex> |> unwrap_issue_message()
      "must be at most 10 characters long"

      iex> Z.string()
      iex> |> Z.max(10)
      iex> |> Z.parse("this is a very long string")
      iex> |> unwrap_issue_message()
      "must be at most 10 characters long"

  Can enforce that the string starts with a given substring:

      iex> Z.string(starts_with: "Hello")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must start with \"Hello\""

      iex> Z.string()
      iex> |> Z.starts_with("Hello")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must start with \"Hello\""

  Can enforce that the string ends with a given substring:

      iex> Z.string(ends_with: "World!")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must end with \"World!\""

      iex> Z.string()
      iex> |> Z.ends_with("World!")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must end with \"World!\""

  Can enforce that the string matches a given regex:

      iex> Z.string(regex: ~r/^hello/)
      iex> |> Z.parse("world hello")
      iex> |> unwrap_issue_message()
      "must match pattern /^hello/"

      iex> Z.string()
      iex> |> Z.regex(~r/^hello/)
      iex> |> Z.parse("world hello")
      iex> |> unwrap_issue_message()
      "must match pattern /^hello/"

  You can specify for the string to be trimmed before validation:DSS

      iex> Z.string(trim: true, starts_with: "Hello")
      iex> |> Z.parse("   Hello, World!")
      {:ok, "Hello, World!"}

      iex> Z.string()
      iex> |> Z.trim()
      iex> |> Z.starts_with("Hello")
      iex> |> Z.parse("   Hello, World!")
      {:ok, "Hello, World!"}

  """
  defdelegate string(opts \\ []), to: Zot.Type.String, as: :new

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                            MODIFIERS                            #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Enforces that the string contains the given substring.
  """
  def contains(%Zot.Type.String{} = type, substring), do: Zot.Type.String.contains(type, substring)

  @doc ~S"""
  Sets the field as not-required and provides a default value.
  """
  def default(type(_) = type, value), do: %{type | required: false, default: value}

  @doc ~S"""
  Attaches a description to the type, for use in JSON Schema.
  """
  def description(type(_) = type, desc)
      when is_nil(desc)
      when is_binary(desc) and byte_size(desc) > 0,
      do: %{type | description: desc}

  @doc ~S"""
  Enforces that the string ends with the given substring.
  """
  def ends_with(%Zot.Type.String{} = type, substring), do: Zot.Type.String.ends_with(type, substring)

  @doc ~S"""
  Attaches an example value to the type, for use in JSON Schema.
  """
  def example(type(_) = type, example), do: %{type | example: example}

  @doc ~S"""
  Enforces that the string has the given length.
  """
  def length(%Zot.Type.String{} = type, length), do: Zot.Type.String.length(type, length)

  @doc ~S"""
  Enforces that the string has a maximum length.
  """
  def max(%Zot.Type.String{} = type, max), do: Zot.Type.String.max(type, max)

  @doc ~S"""
  Enforces that the string has a minimum length.
  """
  def min(%Zot.Type.String{} = type, min), do: Zot.Type.String.min(type, min)

  @doc ~S"""
  Sets the field as not required (nullable).
  """
  def optional(type(_) = type), do: %{type | required: false}

  @doc ~S"""
  Enforces that the string matches the given regex.
  """
  def regex(%Zot.Type.String{} = type, regex), do: Zot.Type.String.regex(type, regex)

  @doc ~S"""
  Enforces that the string starts with the given substring.
  """
  def starts_with(%Zot.Type.String{} = type, substring), do: Zot.Type.String.starts_with(type, substring)

  @doc ~S"""
  Trims whitespace from the beginning and end of the string before
  validation.
  """
  def trim(%Zot.Type.String{} = type, value \\ true), do: Zot.Type.String.trim(type, value)
end
