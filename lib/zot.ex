defmodule Zot do
  @moduledoc ~S"""
  Schema parser and validator for Elixir.
  """

  import Zot.Utils, only: [is_mfa: 1, type: 1]

  alias Zot.Context

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
  Creates a boolean type.

  ## Examples

      iex> Z.boolean()
      iex> |> Z.parse(true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse("yes")
      iex> |> unwrap_issue_message()
      "expected type boolean, got string"

  It can be coerced from boolean-like values:

      iex> Z.boolean()
      iex> |> Z.parse(1, coerce: true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse(0, coerce: true)
      {:ok, false}

      iex> Z.boolean()
      iex> |> Z.parse("true", coerce: true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse("false", coerce: true)
      {:ok, false}

      iex> Z.boolean()
      iex> |> Z.parse("on", coerce: true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse("off", coerce: true)
      {:ok, false}

      iex> Z.boolean()
      iex> |> Z.parse("enabled", coerce: true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse("disabled", coerce: true)
      {:ok, false}

      iex> Z.boolean()
      iex> |> Z.parse("yes", coerce: true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse("no", coerce: true)
      {:ok, false}

  It can be converted into json schema:

      iex> Z.boolean()
      iex> |> Z.description("A boolean flag.")
      iex> |> Z.example(true)
      iex> |> Z.json_schema()
      %{
        "type" => "boolean",
        "description" => "A boolean flag.",
        "example" => true,
        "nullable" => false
      }

  """
  defdelegate boolean, to: Zot.Type.Boolean, as: :new

  @doc ~S"""
  Creates a date-time type.

  ## Examples

      iex> Z.date_time()
      iex> |> Z.parse(~U[2024-01-01T12:34:56Z])
      {:ok, ~U[2024-01-01T12:34:56Z]}

      iex> Z.date_time()
      iex> |> Z.parse("foo")
      iex> |> unwrap_issue_message()
      "expected type DateTime, got string"

  You can enforce that the date-time is after a given date-time:

      iex> Z.date_time(min: ~U[2024-01-01 00:00:00Z])
      iex> |> Z.parse(~U[2023-12-31 23:59:59Z])
      iex> |> unwrap_issue_message()
      "must be after 2024-01-01T00:00:00Z"

  You can enforce that the date-time is before a given date-time:

      iex> Z.date_time(max: ~U[2023-12-31 23:59:59Z])
      iex> |> Z.parse(~U[2024-01-01 00:00:00Z])
      iex> |> unwrap_issue_message()
      "must be before 2023-12-31T23:59:59Z"

  It supports coercion from ISO8601 strings:

      iex> Z.date_time()
      iex> |> Z.parse("2024-01-01T12:34:56Z", coerce: true)
      {:ok, ~U[2024-01-01T12:34:56Z]}

      iex> Z.date_time()
      iex> |> Z.parse("Mon Jan 12 2026 11:16:30 GMT-0300 (Brasilia Standard Time)", coerce: true)
      iex> |> unwrap_issue_message()
      "must be a valid ISO8601 date-time string"

  It can be converted into json schema:

      iex> Z.date_time()
      iex> |> Z.description("A timestamp.")
      iex> |> Z.example(~U[2026-01-10T10:23:45.123Z])
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "date-time",
        "description" => "A timestamp.",
        "example" => "2026-01-10T10:23:45.123Z",
        "nullable" => false
      }

  """
  defdelegate date_time(opts \\ []), to: Zot.Type.DateTime, as: :new

  @doc ~S"""
  Creates a decimal type.

  ## Examples

      iex> Z.decimal()
      iex> |> Z.parse(Decimal.new("123.45"))
      {:ok, Decimal.new("123.45")}

  You can enforce a minimum value:

      iex> Z.decimal(min: 10)
      iex> |> Z.parse(Decimal.new("9.99"))
      iex> |> unwrap_issue_message()
      "must be at least 10, got 9.99"

  You can enforce a maximum value:

      iex> Z.decimal(max: 9.99)
      iex> |> Z.parse(Decimal.new("10.00"))
      iex> |> unwrap_issue_message()
      "must be at most 9.99, got 10.0"

  It can be coerced from an int:

      iex> Z.decimal()
      iex> |> Z.parse(42, coerce: true)
      {:ok, Decimal.new("42")}

  It can be coerced from a float:

      iex> Z.decimal()
      iex> |> Z.parse(3.14, coerce: true)
      {:ok, Decimal.new("3.14")}

  It can be coerced from a string:

      iex> Z.decimal()
      iex> |> Z.parse("3.14", coerce: true)
      {:ok, Decimal.new("3.14")}

  It can be converted into json schema:

      iex> Z.decimal(min: 1.00, max: 100.00)
      iex> |> Z.description("A monetary amount.")
      iex> |> Z.example(Decimal.new("19.99"))
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A monetary amount.",
        "example" => 19.99,
        "nullable" => false,
        "minimum" => 1.0,
        "maximum" => 100.0
      }

  """
  defdelegate decimal(opts \\ []), to: Zot.Type.Decimal, as: :new

  @doc ~S"""
  Creates an email type.

  ## Examples

      iex> Z.email()
      iex> |> Z.parse("foo@zot.dev")
      {:ok, "foo@zot.dev"}

  You can optionally specify a ruleset for validation:

      iex> Z.email(ruleset: :html5)
      iex> |> Z.parse("invalid-email")
      iex> |> unwrap_issue_message()
      "is invalid"

      iex> Z.email(ruleset: :ref5322)
      iex> |> Z.parse("invalid-email")
      iex> |> unwrap_issue_message()
      "is invalid"

      iex> Z.email(ruleset: :unicode)
      iex> |> Z.parse("invalid-email")
      iex> |> unwrap_issue_message()
      "is invalid"

  It can be converted into json schema:

      iex> Z.email()
      iex> |> Z.description("A user's email address.")
      iex> |> Z.example("foo@zot.dev")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "email",
        "description" => "A user's email address.",
        "example" => "foo@zot.dev",
        "nullable" => false
      }

  """
  defdelegate email(opts \\ []), to: Zot.Type.Email, as: :new

  @doc ~S"""
  Creates an enum type.

  ## Examples

  Values can be all atoms:

      iex> Z.enum([:red, :green, :blue])
      iex> |> Z.parse(:green)
      {:ok, :green}

      iex> Z.enum([:red, :green, :blue])
      iex> |> Z.parse(:yellow)
      iex> |> unwrap_issue_message()
      "must be :red, :green or :blue, got :yellow"

  Or they can be all strings:

      iex> Z.enum(["small", "medium", "large"])
      iex> |> Z.parse("medium")
      {:ok, "medium"}

      iex> Z.enum(["small", "medium", "large"])
      iex> |> Z.parse("extra large")
      iex> |> unwrap_issue_message()
      "must be 'small', 'medium' or 'large', got 'extra large'"

  It can be converted to json schema:

      iex> Z.enum([:red, :green, :blue])
      iex> |> Z.description("A color.")
      iex> |> Z.example(:green)
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "enum" => ["red", "green", "blue"],
        "description" => "A color.",
        "example" => "green",
        "nullable" => false
      }

  """
  def enum(values) when is_list(values), do: Zot.Type.Enum.new(values: values)

  @doc ~S"""
  Creates a float type.

  ## Examples

      iex> Z.float()
      iex> |> Z.parse(3.14)
      {:ok, 3.14}

  You can enforce a minimum value:

      iex> Z.float(min: 1.0)
      iex> |> Z.parse(0.99)
      iex> |> unwrap_issue_message()
      "must be at least 1.0, got 0.99"

  You can enforce a maximum value:

      iex> Z.float(max: 10.0)
      iex> |> Z.parse(10.01)
      iex> |> unwrap_issue_message()
      "must be at most 10.0, got 10.01"

  It can be coerced from an int:

      iex> Z.float()
      iex> |> Z.parse(42, coerce: true)
      {:ok, 42.0}

  It can be coerced from Decimal:

      iex> Z.float()
      iex> |> Z.parse(Decimal.new("3.14"), coerce: true)
      {:ok, 3.14}

  It can be coerced from a string:

      iex> Z.float()
      iex> |> Z.parse("3.14", coerce: true)
      {:ok, 3.14}

  It can be converted into json schema:

      iex> Z.float(min: 0.0, max: 1.0)
      iex> |> Z.description("A percentage.")
      iex> |> Z.example(0.425)
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A percentage.",
        "example" => 0.425,
        "minimum" => 0.0,
        "maximum" => 1.0,
        "nullable" => false
      }

  """
  defdelegate float(opts \\ []), to: Zot.Type.Float, as: :new

  @doc ~S"""
  Creates a integer type.

  ## Examples

      iex> Z.int()
      iex> |> Z.parse(42)
      {:ok, 42}

  You can enforce a minimum value:

      iex> Z.int(min: 18)
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be at least 18, got 16"

  You can enforce a maximum value:

      iex> Z.int(max: 18)
      iex> |> Z.parse(33)
      iex> |> unwrap_issue_message()
      "must be at most 18, got 33"

  It can be coerced from an float (rounded):

      iex> Z.int()
      iex> |> Z.parse(3.14, coerce: true)
      {:ok, 3}

  It can be coerced from Decimal (rounded):

      iex> Z.int()
      iex> |> Z.parse(Decimal.new("3.14"), coerce: true)
      {:ok, 3}

  It can be coerced from a string:

      iex> Z.int()
      iex> |> Z.parse("42", coerce: true)
      {:ok, 42}

  It can be converted into json schema:

      iex> Z.int(min: 0, max: 100)
      iex> |> Z.description("A percentage.")
      iex> |> Z.example(42)
      iex> |> Z.json_schema()
      %{
        "type" => "integer",
        "description" => "A percentage.",
        "example" => 42,
        "minimum" => 0,
        "maximum" => 100,
        "nullable" => false
      }

  """
  defdelegate int(opts \\ []), to: Zot.Type.Integer, as: :new

  @doc ~S"""
  Creates a list type.

  ## Examples

      iex> Z.string()
      iex> |> Z.list()
      iex> |> Z.parse(["hello", "world"])
      {:ok, ["hello", "world"]}

  You can enforce a minimum length:

      iex> Z.string()
      iex> |> Z.list(min: 3)
      iex> |> Z.parse(["one", "two"])
      iex> |> unwrap_issue_message()
      "must have at least 3 items, got 2"

  You can enforce a maximum length:

      iex> Z.string()
      iex> |> Z.list(max: 2)
      iex> |> Z.parse(["one", "two", "three"])
      iex> |> unwrap_issue_message()
      "must have at most 2 items, got 3"

  It can be converted into json schema:

      iex> Z.string()
      iex> |> Z.list(min: 1, max: 5)
      iex> |> Z.description("A list of tags.")
      iex> |> Z.example(["elixir", "zot"])
      iex> |> Z.json_schema()
      %{
        "type" => "array",
        "items" => %{
          "type" => "string",
          "nullable" => false
        },
        "description" => "A list of tags.",
        "nullable" => false,
        "minItems" => 1,
        "maxItems" => 5
      }

  """
  def list(type(_) = inner_type, opts \\ []) when is_list(opts), do: Zot.Type.List.new([{:inner_type, inner_type} | opts])

  @doc ~S"""
  Creates a literal type.

  ## Examples

  It can be a boolean:

      iex> Z.literal(true)
      iex> |> Z.parse(true)
      {:ok, true}

      iex> Z.literal(true)
      iex> |> Z.parse(false)
      iex> |> unwrap_issue_message()
      "must be true, got false"

      iex> Z.literal(true)
      iex> |> Z.parse("enabled", coerce: true)
      {:ok, true}

  It can be an integer:

      iex> Z.literal(42)
      iex> |> Z.parse(42)
      {:ok, 42}

      iex> Z.literal(42)
      iex> |> Z.parse(43)
      iex> |> unwrap_issue_message()
      "must be 42, got 43"

      iex> Z.literal(42)
      iex> |> Z.parse("42", coerce: true)
      {:ok, 42}

  It can be a float:

      iex> Z.literal(3.14)
      iex> |> Z.parse(3.14)
      {:ok, 3.14}

      iex> Z.literal(3.14)
      iex> |> Z.parse(3.13)
      iex> |> unwrap_issue_message()
      "must be 3.14, got 3.13"

      iex> Z.literal(3.14)
      iex> |> Z.parse("3.14", coerce: true)
      {:ok, 3.14}

  It can be a string:

      iex> Z.literal("foo")
      iex> |> Z.parse("foo")
      {:ok, "foo"}

      iex> Z.literal("foo")
      iex> |> Z.parse("bar")
      iex> |> unwrap_issue_message()
      "must be 'foo', got 'bar'"

  It can be an atom:

      iex> Z.literal(:admin)
      iex> |> Z.parse(:admin)
      {:ok, :admin}

      iex> Z.literal(:admin)
      iex> |> Z.parse(:user)
      iex> |> unwrap_issue_message()
      "must be :admin, got :user"

      iex> Z.literal(:admin)
      iex> |> Z.parse("admin", coerce: true)
      {:ok, :admin}

      iex> Z.literal(:admin)
      iex> |> Z.parse("user", coerce: true)
      iex> |> unwrap_issue_message()
      "must be :admin, got 'user'"

  It can be converted into json schema:

      iex> Z.literal("active")
      iex> |> Z.description("Lorem ipsum.")
      iex> |> Z.json_schema()
      %{
        "const" => "active",
        "description" => "Lorem ipsum.",
      }

  """
  def literal(value), do: Zot.Type.Literal.new(value: value)

  @doc ~S"""
  Creates a map type where unknown fields are stripped out.

  ## Examples

      iex> Z.map(%{name: Z.string(), age: Z.int(min: 18)})
      iex> |> Z.parse(%{name: "Alice", age: 18, email: "alice@wonder.land"})
      {:ok, %{name: "Alice", age: 18}}

      iex> {:error, [issue]} =
      iex>   Z.map(%{name: Z.string(), age: Z.int(min: 18)})
      iex>   |> Z.parse(%{name: "Alice", age: 16, email: "alice@wonder.land"})
      iex>
      iex> assert issue.path == [:age]
      iex> assert Exception.message(issue) == "must be at least 18, got 16"

  It can be converted into json schema:

      iex> Z.map(%{name: Z.string(), age: Z.int(min: 0)})
      iex> |> Z.description("A person's profile.")
      iex> |> Z.example(%{name: "Bob", age: 30})
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A person's profile.",
        "example" => %{name: "Bob", age: 30},
        "properties" => %{
          "name" => %{
            "type" => "string",
            "nullable" => false
          },
          "age" => %{
            "type" => "integer",
            "minimum" => 0,
            "nullable" => false
          }
        },
        "required" => ["name", "age"],
        "additionalProperties" => true
      }

  """
  def map(shape), do: Zot.Type.Map.new(mode: :strip, shape: shape)

  @doc ~S"""
  Creates a number type (union of integer and float types).

  ## Examples

      iex> Z.number()
      iex> |> Z.parse(3.14)
      {:ok, 3.14}

      iex> Z.number()
      iex> |> Z.parse(42)
      {:ok, 42}

  It can be converted into json schema:

      iex> Z.number(min: 0.5, max: 100)
      iex> |> Z.description("A percentage.")
      iex> |> Z.example(42)
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A percentage.",
        "example" => 42,
        "minimum" => 0.5,
        "maximum" => 100,
        "nullable" => false
      }

  See `float/1` and `int/1` for more examples.
  """
  defdelegate number(opts \\ []), to: Zot.Type.Number, as: :new

  @doc ~S"""
  Creates a numeric string type.

  ## Examples

      iex> Z.numeric()
      iex> |> Z.parse("123456")
      {:ok, "123456"}

      iex> Z.numeric()
      iex> |> Z.parse("123abc")
      iex> |> unwrap_issue_message()
      "must contain only 0-9 digits"

  You can enforce a minimum length:

      iex> Z.numeric(min: 5)
      iex> |> Z.parse("1234")
      iex> |> unwrap_issue_message()
      "must be at least 5 characters long, got 4"

  You can enforce a maximum length:

      iex> Z.numeric(max: 10)
      iex> |> Z.parse("12345678901")
      iex> |> unwrap_issue_message()
      "must be at most 10 characters long, got 11"

  It can be converted into json schema:

      iex> Z.numeric(min: 3, max: 8)
      iex> |> Z.description("A numeric code.")
      iex> |> Z.example("123456")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "description" => "A numeric code.",
        "example" => "123456",
        "pattern" => "^[0-9]+$",
        "minLength" => 3,
        "maxLength" => 8
      }

  """
  defdelegate numeric(opts \\ []), to: Zot.Type.Numeric, as: :new

  @doc ~S"""
  Creates a record type where keys are non-empty strings.

  ## Examples

      iex> Z.record(Z.int())
      iex> |> Z.parse(%{"a" => 1, "b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}

      iex> {:error, [issue]} =
      iex>   Z.record(Z.float())
      iex>   |> Z.parse(%{"a" => 3.14, "b" => "not a float"})
      iex>
      iex> assert issue.path == ["b"]
      iex> assert Exception.message(issue) == "expected type float, got string"

  """
  def record(type(_) = values_type), do: Zot.Type.Record.new(keys_type: string(trim: true, min: 1), values_type: values_type)

  @doc ~S"""
  Creates a map type where unknown fields cause an issue.

  ## Examples

      iex> Z.strict_map(%{name: Z.string(), age: Z.int(min: 18)})
      iex> |> Z.parse(%{name: "Alice", age: 18})
      {:ok, %{name: "Alice", age: 18}}

      iex> {:error, [issue]} =
      iex>   Z.strict_map(%{name: Z.string(), age: Z.int(min: 18)})
      iex>   |> Z.parse(%{name: "Alice", age: 18, email: "alice@wonder.land"})
      iex>
      iex> assert issue.path == ["email"]
      iex> assert Exception.message(issue) == "unknown field"

  It can be converted into json schema:

      iex> Z.strict_map(%{name: Z.string(), age: Z.int(min: 0)})
      iex> |> Z.description("A person's profile.")
      iex> |> Z.example(%{name: "Bob", age: 30})
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A person's profile.",
        "example" => %{name: "Bob", age: 30},
        "properties" => %{
          "name" => %{
            "type" => "string",
            "nullable" => false
          },
          "age" => %{
            "type" => "integer",
            "minimum" => 0,
            "nullable" => false
          }
        },
        "required" => ["name", "age"],
        "additionalProperties" => false
      }

  """
  def strict_map(shape), do: Zot.Type.Map.new(mode: :strict, shape: shape)

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
      "must contain 'foo'"

      iex> Z.string()
      iex> |> Z.contains("foo")
      iex> |> Z.parse("bar baz")
      iex> |> unwrap_issue_message()
      "must contain 'foo'"

  Can enforce a string length:

      iex> Z.string(length: 5)
      iex> |> Z.parse("hey")
      iex> |> unwrap_issue_message()
      "must be 5 characters long, got 3"

      iex> Z.string()
      iex> |> Z.length(5)
      iex> |> Z.parse("hey")
      iex> |> unwrap_issue_message()
      "must be 5 characters long, got 3"

  Can enforce a minimum string length:

      iex> Z.string(min: 3)
      iex> |> Z.parse("hi")
      iex> |> unwrap_issue_message()
      "must be at least 3 characters long, got 2"

      iex> Z.string()
      iex> |> Z.min(3)
      iex> |> Z.parse("hi")
      iex> |> unwrap_issue_message()
      "must be at least 3 characters long, got 2"

  Can enforce a maximum string length:

      iex> Z.string(max: 10)
      iex> |> Z.parse("this is a very long string")
      iex> |> unwrap_issue_message()
      "must be at most 10 characters long, got 26"

      iex> Z.string()
      iex> |> Z.max(10)
      iex> |> Z.parse("this is a very long string")
      iex> |> unwrap_issue_message()
      "must be at most 10 characters long, got 26"

  Can enforce that the string starts with a given substring:

      iex> Z.string(starts_with: "Hello")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must start with 'Hello'"

      iex> Z.string()
      iex> |> Z.starts_with("Hello")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must start with 'Hello'"

  Can enforce that the string ends with a given substring:

      iex> Z.string(ends_with: "World!")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must end with 'World!'"

      iex> Z.string()
      iex> |> Z.ends_with("World!")
      iex> |> Z.parse("World, Hello!")
      iex> |> unwrap_issue_message()
      "must end with 'World!'"

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

  It can be converted into json schema:

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
  defdelegate string(opts \\ []), to: Zot.Type.String, as: :new

  @doc ~S"""
  Creates a union of two or more types.

  ## Examples

      iex> Z.union([Z.string(), Z.int()])
      iex> |> Z.parse("hello")
      {:ok, "hello"}

      iex> Z.union([Z.string(), Z.int()])
      iex> |> Z.parse(42)
      {:ok, 42}

  Beware that only one of the types will have its error reported:

      iex> Z.union([Z.string(), Z.int()])
      iex> |> Z.parse(3.14)
      iex> |> unwrap_issue_message()
      "expected type integer, got float"

  See `discriminated_union/2` which provides more precise error
  reporting at the cost of requiring a discriminator field.

  It can be converted into json schema:

      iex> Z.union([Z.string(), Z.int()])
      iex> |> Z.json_schema()
      %{
        "anyOf" => [
          %{
            "type" => "string",
            "nullable" => false
          },
          %{
            "type" => "integer",
            "nullable" => false
          }
        ]
      }

  """
  def union(types), do: Zot.Type.Union.new(inner_types: types)

  @doc ~S"""
  Creates a URI string type.

  ## Examples

      iex> Z.uri()
      iex> |> Z.parse("https://zot.dev")
      {:ok, "https://zot.dev"}

      iex> Z.uri()
      iex> |> Z.parse("not a uri")
      iex> |> unwrap_issue_message()
      "is invalid"

  You can enforce a limited set of allowed schemes:

      iex> Z.uri(allowed_schemes: ["http", "https"])
      iex> |> Z.parse("ftp://zot.dev")
      iex> |> unwrap_issue_message()
      "scheme must be 'http' or 'https', got 'ftp'"

  You can specify whether query strings are forbidden, should be
  trimmed out from the URI, or kept (default):

      iex> Z.uri(query_string: :keep)
      iex> |> Z.parse("https://zot.dev?page=1")
      {:ok, "https://zot.dev?page=1"}

      iex> Z.uri(query_string: :forbid)
      iex> |> Z.parse("https://zot.dev?page=1")
      iex> |> unwrap_issue_message()
      "query string is not allowed"

      iex> Z.uri(query_string: :trim)
      iex> |> Z.parse("https://zot.dev?page=1")
      {:ok, "https://zot.dev"}

  You can specify whether trailing slashes should always be present,
  should be kept if present (default), or should be trimmed out:

      iex> Z.uri(trailing_slash: :always)
      iex> |> Z.parse("https://zot.dev/path")
      {:ok, "https://zot.dev/path/"}

      iex> Z.uri(trailing_slash: :always)
      iex> |> Z.parse("https://zot.dev/path/")
      {:ok, "https://zot.dev/path/"}

      iex> Z.uri(trailing_slash: :trim)
      iex> |> Z.parse("https://zot.dev/path/")
      {:ok, "https://zot.dev/path"}

      iex> Z.uri(trailing_slash: :keep)
      iex> |> Z.parse("https://zot.dev/path")
      {:ok, "https://zot.dev/path"}

      iex> Z.uri(trailing_slash: :keep)
      iex> |> Z.parse("https://zot.dev/path/")
      {:ok, "https://zot.dev/path/"}

      iex> Z.uri(trailing_slash: :trim)
      iex> |> Z.parse("https://zot.dev/path")
      {:ok, "https://zot.dev/path"}

  """
  defdelegate uri(opts \\ []), to: Zot.Type.URI, as: :new

  @doc ~S"""
  Creates a UUID type.

  ## Examples

      iex> Z.uuid()
      iex> |> Z.parse("550e8400-e29b-41d4-a716-446655440000")
      {:ok, "550e8400-e29b-41d4-a716-446655440000"}

      iex> Z.uuid()
      iex> |> Z.parse("not-a-uuid")
      iex> |> unwrap_issue_message()
      "is invalid"

  You can specify the UUID version to enforce:

      iex> Z.uuid(:v1)
      iex> |> Z.parse("550e8400-e29b-21d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v1, got v2"

      iex> Z.uuid(:v2)
      iex> |> Z.parse("550e8400-e29b-31d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v2, got v3"

      iex> Z.uuid(:v3)
      iex> |> Z.parse("550e8400-e29b-41d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v3, got v4"

      iex> Z.uuid(:v4)
      iex> |> Z.parse("550e8400-e29b-51d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v4, got v5"

      iex> Z.uuid(:v5)
      iex> |> Z.parse("550e8400-e29b-61d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v5, got v6"

      iex> Z.uuid(:v6)
      iex> |> Z.parse("550e8400-e29b-71d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v6, got v7"

      iex> Z.uuid(:v7)
      iex> |> Z.parse("550e8400-e29b-81d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v7, got v8"

      iex> Z.uuid(:v8)
      iex> |> Z.parse("550e8400-e29b-11d4-a716-446655440000")
      iex> |> unwrap_issue_message()
      "expected a uuid v8, got v1"

  It can be converted into json schema:

      iex> Z.uuid(:v4)
      iex> |> Z.description("A universally unique identifier.")
      iex> |> Z.example("550e8400-e29b-41d4-a716-446655440000")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "uuid",
        "description" => "A universally unique identifier.",
        "example" => "550e8400-e29b-41d4-a716-446655440000",
        "nullable" => false
      }

  """
  def uuid(version \\ :any), do: Zot.Type.UUID.new(version: version)

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                            MODIFIERS                            #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Enforces that the URI has one of the given allowed schemes.

  See `uri/1` for more details.
  """
  defdelegate allowed_schemes(type, value, opts \\ []), to: Zot.Type.URI

  @doc ~S"""
  Enforces that the string contains the given substring.
  """
  def contains(type, value, opts \\ [])
  def contains(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.contains(type, value, opts)

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
  def ends_with(type, value, opts \\ [])
  def ends_with(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.ends_with(type, value, opts)

  @doc ~S"""
  Attaches an example value to the type, for use in JSON Schema.
  """
  def example(type(_) = type, example), do: %{type | example: example}

  @doc ~S"""
  Enforces that the string has the given length.
  """
  def length(type, value, opts \\ [])
  def length(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.length(type, value, opts)

  @doc ~S"""
  Defines the behavior regarding query strings in URIs.

  See `uri/1` for more details.
  """
  defdelegate query_string(type, value, opts \\ []), to: Zot.Type.URI

  @doc ~S"""
  Enforces a maximum value for the given type.
  """
  def max(type, value, opts \\ [])
  def max(%Zot.Type.DateTime{} = type, value, opts), do: Zot.Type.DateTime.max(type, value, opts)
  def max(%Zot.Type.Decimal{} = type, value, opts), do: Zot.Type.Decimal.max(type, value, opts)
  def max(%Zot.Type.Float{} = type, value, opts), do: Zot.Type.Float.max(type, value, opts)
  def max(%Zot.Type.Integer{} = type, value, opts), do: Zot.Type.Integer.max(type, value, opts)
  def max(%Zot.Type.List{} = type, value, opts), do: Zot.Type.List.max(type, value, opts)
  def max(%Zot.Type.Number{} = type, value, opts), do: Zot.Type.Number.max(type, value, opts)
  def max(%Zot.Type.Numeric{} = type, value, opts), do: Zot.Type.Numeric.max(type, value, opts)
  def max(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.max(type, value, opts)

  @doc ~S"""
  Enforces a minimum value for the given type.
  """
  def min(type, value, opts \\ [])
  def min(%Zot.Type.DateTime{} = type, value, opts), do: Zot.Type.DateTime.min(type, value, opts)
  def min(%Zot.Type.Decimal{} = type, value, opts), do: Zot.Type.Decimal.min(type, value, opts)
  def min(%Zot.Type.Float{} = type, value, opts), do: Zot.Type.Float.min(type, value, opts)
  def min(%Zot.Type.Integer{} = type, value, opts), do: Zot.Type.Integer.min(type, value, opts)
  def min(%Zot.Type.List{} = type, value, opts), do: Zot.Type.List.min(type, value, opts)
  def min(%Zot.Type.Number{} = type, value, opts), do: Zot.Type.Number.min(type, value, opts)
  def min(%Zot.Type.Numeric{} = type, value, opts), do: Zot.Type.Numeric.min(type, value, opts)
  def min(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.min(type, value, opts)

  @doc ~S"""
  Sets the field as not required (nullable).
  """
  def optional(type(_) = type), do: %{type | required: false}

  @doc ~S"""
  Adds a custom refinement to the given type's effects pipeline, which
  is executed after the type is successfully parsed and validated.

  ## Examples

      iex> Z.int()
      iex> |> Z.refine(& &1 >= 18)
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "is invalid"

  You can optionally provide a custom error message:

      iex> Z.int()
      iex> |> Z.refine(& &1 >= 18, error: "must be greater than or equal to 18")
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be greater than or equal to 18"

  The error message may include the actual value:

      iex> Z.int()
      iex> |> Z.refine(& &1 >= 18, error: "must be greater than or equal to 18, got %{actual}")
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be greater than or equal to 18, got 16"

  """
  @opts error: "is invalid"
  def refine(type(_) = type, fun, opts \\ [])
      when is_mfa(fun)
      when is_function(fun, 1)
      when is_function(fun, 2),
      do: %{type | effects: type.effects ++ [{:refine, Zot.Parameterized.new(fun, @opts, opts)}]}

  @doc ~S"""
  Enforces that the string matches the given regex.
  """
  def regex(type, value, opts \\ [])
  def regex(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.regex(type, value, opts)

  @doc ~S"""
  Enforces that the string starts with the given substring.
  """
  def starts_with(type, value, opts \\ [])
  def starts_with(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.starts_with(type, value, opts)

  @doc ~S"""
  Defines the behavior regarding trailing slashes in URIs.

  See `uri/1` for more details.
  """
  defdelegate trailing_slash(type, value), to: Zot.Type.URI

  @doc ~S"""
  Adds a transformation to the given type's effects pipeline, which
  is executed after the type is successfully parsed and validated.

  ## Examples

      iex> Z.int()
      iex> |> Z.transform(&Decimal.new/1)
      iex> |> Z.parse(42)
      {:ok, Decimal.new(42)}

  """
  def transform(type(_) = type, fun)
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | effects: type.effects ++ [{:transform, fun}]}

  @doc ~S"""
  Trims whitespace from the beginning and end of the string before
  validation.
  """
  def trim(%Zot.Type.String{} = type, value \\ true), do: Zot.Type.String.trim(type, value)

  @doc ~S"""
  Enforces the UUID version for the given UUID type.

  See `uuid/1` for more details.
  """
  defdelegate version(type, value), to: Zot.Type.UUID
end
