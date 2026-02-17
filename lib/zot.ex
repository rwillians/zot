defmodule Zot do
  @moduledoc ~S"""
  Schema parser and validator for Elixir.
  """

  import Zot.Utils, only: [is_mfa: 1, zot_type: 1]

  alias Zot.Context

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # CORE API                                                        #
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

  def json_schema(zot_type(_) = type) do
    Zot.Type.json_schema(type)
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end

  @doc ~S"""
  Summarizes a list of issues into a map of paths (dot-notated) to
  messages.

  ## Examples

      iex> {:error, issues} =
      iex>   Z.map(%{user: Z.map(%{name: Z.string(), age: Z.integer(min: 18)})})
      iex>   |> Z.parse(%{user: %{name: 123, age: 16}})
      iex>
      iex> Z.summarize(issues)
      %{
        "user.name" => ["expected type string, got integer"],
        "user.age" => ["must be at least 18, got 16"]
      }

      iex> {:error, issues} =
      iex>   Z.map(%{email: Z.email()})
      iex>   |> Z.parse(%{email: "invalid"})
      iex>
      iex> Z.summarize(issues)
      %{"email" => ["is invalid"]}

  """
  defdelegate summarize(issues), to: Zot.Issue

  @doc ~S"""
  Renders a list of issues into a pretty-printed string for display.

  By default, the output includes ANSI escape codes for highlighting.
  You can disable that by setting the option `:colors` to `false`.

  ## Examples

      iex> {:error, issues} =
      iex>   Z.map(%{age: Z.integer(min: 18)})
      iex>   |> Z.parse(%{age: 16})
      iex>
      iex> Z.pretty_print(issues, colors: false)
      "One or more fields failed validation:\n  * Field `age` must be at least 18, got 16;\n"

  """
  defdelegate pretty_print(issues, opts \\ []), to: Zot.Issue

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # TYPES                                                           #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Creates a type that accepts any value.

  ## Examples

      iex> Z.any()
      iex> |> Z.parse("hello")
      {:ok, "hello"}

      iex> Z.any()
      iex> |> Z.parse(42)
      {:ok, 42}

      iex> Z.any()
      iex> |> Z.parse(%{foo: "bar"})
      {:ok, %{foo: "bar"}}

      iex> Z.any()
      iex> |> Z.optional()
      iex> |> Z.parse(nil)
      {:ok, nil}

  Useful in maps where a field can accept any value:

      iex> Z.map(%{name: Z.string(), metadata: Z.any()})
      iex> |> Z.parse(%{name: "Alice", metadata: %{role: "admin", tags: [1, 2, 3]}})
      {:ok, %{name: "Alice", metadata: %{role: "admin", tags: [1, 2, 3]}}}

  Supports transform and refine effects:

      iex> Z.any()
      iex> |> Z.transform(&inspect/1)
      iex> |> Z.parse({:ok, 42})
      {:ok, "{:ok, 42}"}

  It can be converted into json schema:

      iex> Z.any()
      iex> |> Z.describe("Arbitrary metadata.")
      iex> |> Z.json_schema()
      %{
        "description" => "Arbitrary metadata."
      }

  """
  defdelegate any, to: Zot.Type.Any, as: :new

  @doc ~S"""
  Creates an atom type.

  ## Examples

      iex> Z.atom()
      iex> |> Z.parse(:foo)
      {:ok, :foo}

      iex> Z.atom()
      iex> |> Z.parse("bar")
      iex> |> unwrap_issue_message()
      "expected type atom, got string"

  With `coerce: true`, it converts strings to existing atoms only:

      iex> Z.atom()
      iex> |> Z.parse("foo", coerce: true)
      {:ok, :foo}

      iex> Z.atom()
      iex> |> Z.parse("this_atom_does_not_exist", coerce: true)
      iex> |> unwrap_issue_message()
      "atom 'this_atom_does_not_exist' does not exist"

  With `coerce: :unsafe`, it converts any string to an atom:

      iex> Z.atom()
      iex> |> Z.parse("some_new_atom", coerce: :unsafe)
      {:ok, :some_new_atom}

  It can be converted into json schema:

      iex> Z.atom()
      iex> |> Z.describe("A status atom.")
      iex> |> Z.example(:active)
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "description" => "A status atom.",
        "examples" => ["active"]
      }

  """
  defdelegate atom, to: Zot.Type.Atom, as: :new

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

  Coercion fails for non-boolean-like strings:

      iex> Z.boolean()
      iex> |> Z.parse("maybe", coerce: true)
      iex> |> unwrap_issue_message()
      "expected a boolean-like string ('true', 'enabled', 'on', 'yes', 'false', 'disabled', 'off' or 'no'), got 'maybe'"

  It can be converted into json schema:

      iex> Z.boolean()
      iex> |> Z.describe("A boolean flag.")
      iex> |> Z.example(true)
      iex> |> Z.json_schema()
      %{
        "type" => "boolean",
        "description" => "A boolean flag.",
        "examples" => [true]
      }

  """
  defdelegate boolean, to: Zot.Type.Boolean, as: :new

  @doc ~S"""
  Alias to `date_time/1`.
  """
  defdelegate datetime(opts \\ []), to: Zot.Type.DateTime, as: :new

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
      iex> |> Z.describe("A timestamp.")
      iex> |> Z.example(~U[2026-01-10T10:23:45.123Z])
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "date-time",
        "description" => "A timestamp.",
        "examples" => ["2026-01-10T10:23:45.123Z"]
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

  You can round to a given number of decimal places:

      iex> Z.decimal(precision: 2)
      iex> |> Z.parse(Decimal.new("3.14159"))
      {:ok, Decimal.new("3.14")}

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
      iex> |> Z.describe("A monetary amount.")
      iex> |> Z.example(Decimal.new("19.99"))
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A monetary amount.",
        "examples" => [19.99],
        "minimum" => 1.0,
        "maximum" => 100.0
      }

  """
  defdelegate decimal(opts \\ []), to: Zot.Type.Decimal, as: :new

  @doc ~S"""
  Creates a discriminated union of two or more map types.

  Unlike `union/1`, this provides more precise error reporting by
  using a discriminator field to determine which variant to parse.

  ## Examples

  Successful parsing with different variants:

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.parse(%{type: "dog", barks: true})
      {:ok, %{type: "dog", barks: true}}

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.parse(%{type: "cat", meows: true})
      {:ok, %{type: "cat", meows: true}}

  Works with string keys in the input:

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.parse(%{"type" => "dog", "barks" => true})
      {:ok, %{type: "dog", barks: true}}

  Error when discriminator value doesn't match any variant:

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.parse(%{type: "bird", flies: true})
      iex> |> unwrap_issue_message()
      "expected field type to be one of 'dog' or 'cat', got 'bird'"

  Error when input is not a map:

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.parse("not a map")
      iex> |> unwrap_issue_message()
      "expected type map, got string"

  ArgumentError when discriminator field is missing from a map type:

      iex> try do
      iex>   Z.discriminated_union(:kind, [
      iex>     Z.map(%{type: Z.literal("dog")}),
      iex>     Z.map(%{type: Z.literal("cat")})
      iex>   ])
      iex> rescue
      iex>   e in ArgumentError -> e.message
      iex> end
      "the discriminator field :kind must exist in all map types"

  ArgumentError when inner types are not map types:

      iex> try do
      iex>   Z.discriminated_union(:type, [Z.string(), Z.integer()])
      iex> rescue
      iex>   e in ArgumentError -> e.message
      iex> end
      "discriminated union only accepts map types, got Zot.Type.String"

  ArgumentError when discriminator field is not a literal type:

      iex> try do
      iex>   Z.discriminated_union(:type, [
      iex>     Z.map(%{type: Z.string(), name: Z.string()}),
      iex>     Z.map(%{type: Z.string(), age: Z.integer()})
      iex>   ])
      iex> rescue
      iex>   e in ArgumentError -> e.message
      iex> end
      "the discriminator field :type must be a literal type, got Zot.Type.String"

  It can be converted into json schema:

      iex> Z.discriminated_union(:type, [
      iex>   Z.map(%{type: Z.literal("dog"), barks: Z.boolean()}),
      iex>   Z.map(%{type: Z.literal("cat"), meows: Z.boolean()})
      iex> ])
      iex> |> Z.json_schema()
      %{
        "oneOf" => [
          %{
            "type" => "object",
            "additionalProperties" => true,
            "properties" => %{
              "type" => %{"const" => "dog"},
              "barks" => %{"type" => "boolean"}
            },
            "required" => ["type", "barks"]
          },
          %{
            "type" => "object",
            "additionalProperties" => true,
            "properties" => %{
              "type" => %{"const" => "cat"},
              "meows" => %{"type" => "boolean"}
            },
            "required" => ["type", "meows"]
          }
        ],
        "discriminator" => %{
          "propertyName" => "type"
        }
      }

  """
  def discriminated_union(discriminator, types)
      when is_atom(discriminator) and is_list(types),
      do: Zot.Type.DiscriminatedUnion.new(discriminator: discriminator, inner_types: types)

  @doc ~S"""
  Alias to `date_time/1`.
  """
  defdelegate dt(opts \\ []), to: Zot.Type.DateTime, as: :new

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
      iex> |> Z.describe("A user's email address.")
      iex> |> Z.example("foo@zot.dev")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "email",
        "description" => "A user's email address.",
        "examples" => ["foo@zot.dev"]
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
      iex> |> Z.describe("A color.")
      iex> |> Z.example(:green)
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "enum" => ["red", "green", "blue"],
        "description" => "A color.",
        "examples" => ["green"]
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

  You can round to a given number of decimal places:

      iex> Z.float(precision: 2)
      iex> |> Z.parse(3.14159)
      {:ok, 3.14}

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
      iex> |> Z.describe("A percentage.")
      iex> |> Z.example(0.425)
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A percentage.",
        "examples" => [0.425],
        "minimum" => 0.0,
        "maximum" => 1.0
      }

  """
  defdelegate float(opts \\ []), to: Zot.Type.Float, as: :new

  @doc ~S"""
  Creates a CIDR notation type for IPv4 or IPv6 network addresses.

  ## Examples

      iex> Z.cidr()
      iex> |> Z.parse("192.168.0.0/24")
      {:ok, "192.168.0.0/24"}

      iex> Z.cidr()
      iex> |> Z.parse("2001:db8::/32")
      {:ok, "2001:db8::/32"}

      iex> Z.cidr()
      iex> |> Z.parse("not-a-cidr")
      iex> |> unwrap_issue_message()
      "is invalid"

  You can restrict to a specific IP version:

      iex> Z.cidr(version: :v4)
      iex> |> Z.parse("192.168.0.0/24")
      {:ok, "192.168.0.0/24"}

      iex> Z.cidr(version: :v4)
      iex> |> Z.parse("2001:db8::/32")
      iex> |> unwrap_issue_message()
      "must be a valid IPv4 CIDR"

      iex> Z.cidr(version: :v6)
      iex> |> Z.parse("2001:db8::/32")
      {:ok, "2001:db8::/32"}

      iex> Z.cidr(version: :v6)
      iex> |> Z.parse("192.168.0.0/24")
      iex> |> unwrap_issue_message()
      "must be a valid IPv6 CIDR"

  You can change the output format:

      iex> Z.cidr(output: :tuple)
      iex> |> Z.parse("192.168.1.0/24")
      {:ok, {{192, 168, 1, 0}, {192, 168, 1, 255}, 24}}

      iex> Z.cidr(output: :map)
      iex> |> Z.parse("192.168.1.0/24")
      {:ok, %{start: {192, 168, 1, 0}, end: {192, 168, 1, 255}, prefix: 24}}

  Non-canonical CIDR notation (where the IP is not the network address)
  is rejected by default:

      iex> Z.cidr()
      iex> |> Z.parse("192.168.1.100/24")
      iex> |> unwrap_issue_message()
      "must be in canonical form (network address), got '192.168.1.100/24'"

  You can enable automatic canonicalization:

      iex> Z.cidr(canonicalize: true)
      iex> |> Z.parse("192.168.1.100/24")
      {:ok, "192.168.1.0/24"}

  You can enforce minimum and maximum prefix lengths:

      iex> Z.cidr(min_prefix: 16)
      iex> |> Z.parse("10.0.0.0/8")
      iex> |> unwrap_issue_message()
      "prefix length must be at least 16, got 8"

      iex> Z.cidr(max_prefix: 24)
      iex> |> Z.parse("10.0.0.0/28")
      iex> |> unwrap_issue_message()
      "prefix length must be at most 24, got 28"

  It supports coercion from tuples and maps:

      iex> Z.cidr()
      iex> |> Z.parse({{192, 168, 0, 0}, 24}, coerce: true)
      {:ok, "192.168.0.0/24"}

      iex> Z.cidr()
      iex> |> Z.parse(%{ip: {192, 168, 0, 0}, prefix: 24}, coerce: true)
      {:ok, "192.168.0.0/24"}

  It can be converted into json schema:

      iex> Z.cidr(version: :v4)
      iex> |> Z.describe("An IPv4 network.")
      iex> |> Z.example("192.168.0.0/24")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "pattern" => "^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)/(?:3[0-2]|[12]?[0-9])$",
        "description" => "An IPv4 network.",
        "examples" => ["192.168.0.0/24"]
      }

  """
  defdelegate cidr(opts \\ []), to: Zot.Type.CIDR, as: :new

  @doc ~S"""
  Alias to `integer/1`.
  """
  defdelegate int(opts \\ []), to: Zot.Type.Integer, as: :new

  @doc ~S"""
  Creates a integer type.

  ## Examples

      iex> Z.integer()
      iex> |> Z.parse(42)
      {:ok, 42}

  You can enforce a minimum value:

      iex> Z.integer(min: 18)
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be at least 18, got 16"

  You can enforce a maximum value:

      iex> Z.integer(max: 18)
      iex> |> Z.parse(33)
      iex> |> unwrap_issue_message()
      "must be at most 18, got 33"

  It can be coerced from an float (rounded):

      iex> Z.integer()
      iex> |> Z.parse(3.14, coerce: true)
      {:ok, 3}

  It can be coerced from Decimal (rounded):

      iex> Z.integer()
      iex> |> Z.parse(Decimal.new("3.14"), coerce: true)
      {:ok, 3}

  It can be coerced from a string:

      iex> Z.integer()
      iex> |> Z.parse("42", coerce: true)
      {:ok, 42}

  It can be converted into json schema:

      iex> Z.integer(min: 0, max: 100)
      iex> |> Z.describe("A percentage.")
      iex> |> Z.example(42)
      iex> |> Z.json_schema()
      %{
        "type" => "integer",
        "description" => "A percentage.",
        "examples" => [42],
        "minimum" => 0,
        "maximum" => 100
      }

  """
  defdelegate integer(opts \\ []), to: Zot.Type.Integer, as: :new

  @doc ~S"""
  Creates an IP address type.

  ## Examples

      iex> Z.ip()
      iex> |> Z.parse("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> Z.ip()
      iex> |> Z.parse("::1")
      {:ok, "::1"}

      iex> Z.ip()
      iex> |> Z.parse("not-an-ip")
      iex> |> unwrap_issue_message()
      "is invalid"

  You can restrict to a specific IP version:

      iex> Z.ip(version: :v4)
      iex> |> Z.parse("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> Z.ip(version: :v4)
      iex> |> Z.parse("::1")
      iex> |> unwrap_issue_message()
      "must be a valid IPv4 address"

      iex> Z.ip(version: :v6)
      iex> |> Z.parse("::1")
      {:ok, "::1"}

      iex> Z.ip(version: :v6)
      iex> |> Z.parse("192.168.1.1")
      iex> |> unwrap_issue_message()
      "must be a valid IPv6 address"

  You can change the output format to a tuple:

      iex> Z.ip(output: :tuple)
      iex> |> Z.parse("192.168.1.1")
      {:ok, {192, 168, 1, 1}}

      iex> Z.ip(output: :tuple)
      iex> |> Z.parse("::1")
      {:ok, {0, 0, 0, 0, 0, 0, 0, 1}}

  It supports coercion from tuples:

      iex> Z.ip()
      iex> |> Z.parse({192, 168, 1, 1}, coerce: true)
      {:ok, "192.168.1.1"}

      iex> Z.ip()
      iex> |> Z.parse({0, 0, 0, 0, 0, 0, 0, 1}, coerce: true)
      {:ok, "::1"}

  You can validate against CIDR ranges:

      iex> Z.ip()
      iex> |> Z.cidr("192.168.0.0/16")
      iex> |> Z.parse("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> Z.ip()
      iex> |> Z.cidr("192.168.0.0/16")
      iex> |> Z.parse("10.0.0.1")
      iex> |> unwrap_issue_message()
      "must be within CIDR range 192.168.0.0/16"

  You can use predefined CIDR sets:

      iex> Z.ip()
      iex> |> Z.cidr(:private)
      iex> |> Z.parse("192.168.1.1")
      {:ok, "192.168.1.1"}

      iex> Z.ip()
      iex> |> Z.cidr(:private)
      iex> |> Z.parse("8.8.8.8")
      iex> |> unwrap_issue_message()
      "must be a private IP address"

      iex> Z.ip()
      iex> |> Z.cidr(:loopback)
      iex> |> Z.parse("127.0.0.1")
      {:ok, "127.0.0.1"}

      iex> Z.ip()
      iex> |> Z.cidr(:link_local)
      iex> |> Z.parse("169.254.1.1")
      {:ok, "169.254.1.1"}

  It can be converted into json schema:

      iex> Z.ip(version: :v4)
      iex> |> Z.describe("An IPv4 address.")
      iex> |> Z.example("192.168.1.1")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "ipv4",
        "description" => "An IPv4 address.",
        "examples" => ["192.168.1.1"]
      }

      iex> Z.ip(version: :v6)
      iex> |> Z.describe("An IPv6 address.")
      iex> |> Z.example("::1")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "ipv6",
        "description" => "An IPv6 address.",
        "examples" => ["::1"]
      }

      iex> Z.ip()
      iex> |> Z.describe("An IP address.")
      iex> |> Z.json_schema()
      %{
        "description" => "An IP address.",
        "oneOf" => [
          %{"format" => "ipv4", "type" => "string"},
          %{"format" => "ipv6", "type" => "string"}
        ]
      }

  """
  defdelegate ip(opts \\ []), to: Zot.Type.IP, as: :new

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

  You can enforce an exact length:

      iex> Z.string()
      iex> |> Z.list(length: 2)
      iex> |> Z.parse(["one", "two", "three"])
      iex> |> unwrap_issue_message()
      "must have 2 items, got 3"

  It can be converted into json schema:

      iex> Z.string()
      iex> |> Z.list(min: 1, max: 5)
      iex> |> Z.describe("A list of tags.")
      iex> |> Z.example(["elixir", "zot"])
      iex> |> Z.json_schema()
      %{
        "type" => "array",
        "items" => %{
          "type" => "string"
        },
        "description" => "A list of tags.",
        "minItems" => 1,
        "maxItems" => 5
      }

  """
  def list(zot_type(_) = inner_type, opts \\ []) when is_list(opts), do: Zot.Type.List.new([{:inner_type, inner_type} | opts])

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
      iex> |> Z.describe("Lorem ipsum.")
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

      iex> Z.map(%{name: Z.string(), age: Z.integer(min: 18)})
      iex> |> Z.parse(%{name: "Alice", age: 18, email: "alice@wonder.land"})
      {:ok, %{name: "Alice", age: 18}}

      iex> {:error, [issue]} =
      iex>   Z.map(%{name: Z.string(), age: Z.integer(min: 18)})
      iex>   |> Z.parse(%{name: "Alice", age: 16, email: "alice@wonder.land"})
      iex>
      iex> assert issue.path == [:age]
      iex> assert Exception.message(issue) == "must be at least 18, got 16"

  It can be converted into json schema:

      iex> Z.map(%{name: Z.string(), age: Z.integer(min: 0)})
      iex> |> Z.describe("A person's profile.")
      iex> |> Z.example(%{name: "Bob", age: 30})
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A person's profile.",
        "examples" => [%{"name" => "Bob", "age" => 30}],
        "properties" => %{
          "name" => %{
            "type" => "string"
          },
          "age" => %{
            "type" => "integer",
            "minimum" => 0
          }
        },
        "required" => ["name", "age"],
        "additionalProperties" => true
      }

  """
  def map(shape)
      when is_non_struct_map(shape)
      when is_list(shape),
      do: Zot.Type.Map.new(mode: :strip, shape: Enum.into(shape, %{}))

  @doc ~S"""
  Merges two map types into a new map type.

  The second map's fields override the first on conflicts. The resulting
  map is strict if either input map is strict.

  Note that `required`, `default`, `description`, `example`, and `effects`
  are lost when merging two maps. Use the appropriate modifiers after
  merging to set these fields.

  ## Examples

      iex> map1 = Z.map(%{name: Z.string()})
      iex> map2 = Z.map(%{age: Z.integer()})
      iex> Z.merge(map1, map2)
      iex> |> Z.parse(%{name: "Alice", age: 30})
      {:ok, %{name: "Alice", age: 30}}

      iex> map1 = Z.map(%{name: Z.string()})
      iex> map2 = Z.map(%{name: Z.integer()})
      iex> Z.merge(map1, map2)
      iex> |> Z.parse(%{name: 42})
      {:ok, %{name: 42}}

      iex> map1 = Z.strict_map(%{name: Z.string()})
      iex> map2 = Z.map(%{age: Z.integer()})
      iex> Z.merge(map1, map2)
      iex> |> Z.parse(%{name: "Alice", age: 30, extra: "field"})
      iex> |> unwrap_issue_message()
      "unknown field"

  """
  def merge(%Zot.Type.Map{} = a, %Zot.Type.Map{} = b) do
    mode =
      if :strict in [a.mode, b.mode],
        do: :strict,
        else: :strip

    shape = Map.merge(a.shape, b.shape)

    Zot.Type.Map.new(mode: mode, shape: shape)
  end

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
      iex> |> Z.describe("A percentage.")
      iex> |> Z.example(42)
      iex> |> Z.json_schema()
      %{
        "type" => "number",
        "description" => "A percentage.",
        "examples" => [42],
        "minimum" => 0.5,
        "maximum" => 100
      }

  See `float/1` and `int/1` for more examples.
  """
  defdelegate number(opts \\ []), to: Zot.Type.Number, as: :new

  @doc ~S"""
  Creates a non-empty string type that trims whitespace.

  This is an alias for `string(trim: true, min: 1)`.

  ## Examples

      iex> Z.non_empty_string()
      iex> |> Z.parse("hello")
      {:ok, "hello"}

      iex> Z.non_empty_string()
      iex> |> Z.parse("   ")
      iex> |> unwrap_issue_message()
      "must be at least 1 characters long, got 0"

      iex> Z.non_empty_string()
      iex> |> Z.parse("")
      iex> |> unwrap_issue_message()
      "must be at least 1 characters long, got 0"

  Whitespace is trimmed before validation:

      iex> Z.non_empty_string()
      iex> |> Z.parse("  hello  ")
      {:ok, "hello"}

  """
  def non_empty_string, do: string(trim: true, min: 1)

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
      iex> |> Z.describe("A numeric code.")
      iex> |> Z.example("123456")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "description" => "A numeric code.",
        "examples" => ["123456"],
        "pattern" => "^[0-9]+$",
        "minLength" => 3,
        "maxLength" => 8
      }

  """
  defdelegate numeric(opts \\ []), to: Zot.Type.Numeric, as: :new

  @doc ~S"""
  Creates a phone number type.

  ## Examples

      iex> Z.phone()
      iex> |> Z.parse("+5511987654321")
      {:ok, "+5511987654321"}

      iex> Z.phone()
      iex> |> Z.parse("5511987654321")
      {:ok, "5511987654321"}

  You can define the behavior for the leading plus sign, where the
  options are:
  - `:always` - if absent, adds it to the output;
  - `:forbid` - if present, results in an issue;
  - `:keep` (default) - if present, keeps it; and
  - `:require` - if absent, results in an issue.

      iex> Z.phone(leading_plus_sign: :always)
      iex> |> Z.parse("5511987654321")
      {:ok, "+5511987654321"}

      iex> Z.phone(leading_plus_sign: :keep)
      iex> |> Z.parse("+5511987654321")
      {:ok, "+5511987654321"}

      iex> Z.phone(leading_plus_sign: :keep)
      iex> |> Z.parse("5511987654321")
      {:ok, "5511987654321"}

      iex> Z.phone(leading_plus_sign: :never)
      iex> |> Z.parse("+5511987654321")
      iex> |> unwrap_issue_message()
      "must be digits only, without the leading plus sign (+)"

      iex> Z.phone(leading_plus_sign: :require)
      iex> |> Z.parse("5511987654321")
      iex> |> unwrap_issue_message()
      "must start with a leading plus sign (+)"

  It can be converted into json schema:

      iex> Z.phone(leading_plus_sign: :always)
      iex> |> Z.describe("A phone number.")
      iex> |> Z.example("+5511987654321")
      iex> |> Z.json_schema()
      %{
        "description" => "A phone number.",
        "examples" => ["+5511987654321"],
        "format" => "phone",
        "maxLength" => 16,
        "minLength" => 9,
        "pattern" => "^\\+?[0-9]{8,15}$",
        "type" => "string"
      }

  """
  defdelegate phone(opts \\ []), to: Zot.Type.Phone, as: :new

  @doc ~S"""
  Creates a record type where keys are non-empty strings.

  ## Examples

      iex> Z.record(Z.integer())
      iex> |> Z.parse(%{"a" => 1, "b" => 2})
      {:ok, %{"a" => 1, "b" => 2}}

      iex> {:error, [issue]} =
      iex>   Z.record(Z.float())
      iex>   |> Z.parse(%{"a" => 3.14, "b" => "not a float"})
      iex>
      iex> assert issue.path == ["b"]
      iex> assert Exception.message(issue) == "expected type float, got string"

  """
  def record(zot_type(_) = values_type), do: Zot.Type.Record.new(keys_type: string(trim: true, min: 1), values_type: values_type)

  @doc ~S"""
  Creates a map type where unknown fields cause an issue.

  ## Examples

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer(min: 18)})
      iex> |> Z.parse(%{name: "Alice", age: 18})
      {:ok, %{name: "Alice", age: 18}}

      iex> {:error, [issue]} =
      iex>   Z.strict_map(%{name: Z.string(), age: Z.integer(min: 18)})
      iex>   |> Z.parse(%{name: "Alice", age: 18, email: "alice@wonder.land"})
      iex>
      iex> assert issue.path == ["email"]
      iex> assert Exception.message(issue) == "unknown field"

  It can be converted into json schema:

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer(min: 0)})
      iex> |> Z.describe("A person's profile.")
      iex> |> Z.example(%{name: "Bob", age: 30})
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A person's profile.",
        "examples" => [%{"name" => "Bob", "age" => 30}],
        "properties" => %{
          "name" => %{
            "type" => "string"
          },
          "age" => %{
            "type" => "integer",
            "minimum" => 0
          }
        },
        "required" => ["name", "age"],
        "additionalProperties" => false
      }

  """
  def strict_map(shape)
      when is_non_struct_map(shape)
      when is_list(shape),
      do: Zot.Type.Map.new(mode: :strict, shape: Enum.into(shape, %{}))

  @doc ~S"""
  Creates a struct type.

  It works like `strict_map/1` but converts the result to an Elixir
  struct.

  ## Examples

      iex> Z.struct(ZotTest.StructUser, %{name: Z.string(), age: Z.integer()})
      iex> |> Z.parse(%{name: "Alice", age: 30})
      {:ok, %ZotTest.StructUser{name: "Alice", age: 30}}

  Also accepts keyword list for shape (like `map/1`):

      iex> Z.struct(ZotTest.StructUser, name: Z.string(), age: Z.integer())
      iex> |> Z.parse(%{"name" => "Bob", "age" => 25})
      {:ok, %ZotTest.StructUser{name: "Bob", age: 25}}

  Rejects unknown fields (strict mode behavior):

      iex> Z.struct(ZotTest.StructUser, %{name: Z.string(), age: Z.integer()})
      iex> |> Z.parse(%{name: "Alice", age: 30, email: "alice@example.com"})
      iex> |> unwrap_issue_message()
      "unknown field"

  Returns validation errors for invalid field values:

      iex> Z.struct(ZotTest.StructUser, %{name: Z.string(), age: Z.integer(min: 18)})
      iex> |> Z.parse(%{name: "Alice", age: 16})
      iex> |> unwrap_issue_message()
      "must be at least 18, got 16"

  Works with coercion:

      iex> Z.struct(ZotTest.StructUser, %{name: Z.string(), age: Z.integer()})
      iex> |> Z.parse(%{name: "Alice", age: "30"}, coerce: true)
      {:ok, %ZotTest.StructUser{name: "Alice", age: 30}}

  Alternatively, you can convert a map type into a struct type:DSS

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer()})
      iex> |> Z.struct(ZotTest.StructUser)
      iex> |> Z.parse(%{name: "Bob", age: 25})
      {:ok, %ZotTest.StructUser{name: "Bob", age: 25}}

  It can be converted into json schema (same as strict_map):

      iex> Z.struct(ZotTest.StructUser, %{name: Z.string(), age: Z.integer(min: 0)})
      iex> |> Z.describe("A user profile.")
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A user profile.",
        "properties" => %{
          "name" => %{
            "type" => "string"
          },
          "age" => %{
            "type" => "integer",
            "minimum" => 0
          }
        },
        "required" => ["name", "age"],
        "additionalProperties" => false
      }

  """
  def struct(module, shape)
      when is_atom(module) and is_non_struct_map(shape),
      do: Zot.Type.Struct.new(module: module, shape: shape)

  def struct(module, shape)
      when is_atom(module) and is_list(shape),
      do: Zot.Type.Struct.new(module: module, shape: Enum.into(shape, %{}))

  def struct(%Zot.Type.Map{} = map, module) when is_atom(module) do
    Zot.Type.Struct.new(module: module, shape: map.shape)
    |> Map.put(:required, map.required)
    |> default(map.default)
    |> describe(map.description)
    |> example(map.example)
  end

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
      iex> |> Z.describe("A user id.")
      iex> |> Z.example("u_12345678901234567890123456")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "description" => "A user id.",
        "examples" => ["u_12345678901234567890123456"],
        "minLength" => 28,
        "maxLength" => 28
      }

  """
  defdelegate string(opts \\ []), to: Zot.Type.String, as: :new

  @doc ~S"""
  Alias to `date_time/1`.
  """
  defdelegate timestamp(opts \\ []), to: Zot.Type.DateTime, as: :new

  @doc ~S"""
  Creates a tuple type with a fixed number of heterogeneous elements.

  ## Examples

  The argument can be a list of types:

      iex> Z.tuple([Z.string(), Z.integer()])
      iex> |> Z.parse({"hello", 42})
      {:ok, {"hello", 42}}

  Or a tuple of types:

      iex> Z.tuple({Z.string(), Z.integer()})
      iex> |> Z.parse({"hello", 42})
      {:ok, {"hello", 42}}

  Rejects tuples with wrong number of elements:

      iex> Z.tuple([Z.string(), Z.integer()])
      iex> |> Z.parse({"hello", 42, "extra"})
      iex> |> unwrap_issue_message()
      "expected a tuple with 2 elements, got 3"

  Validates each element against its corresponding type:

      iex> Z.tuple([Z.string(), Z.integer()])
      iex> |> Z.parse({"hello", "not an int"})
      iex> |> unwrap_issue_message()
      "expected type integer, got string"

  It can be coerced from a list:

      iex> Z.tuple([Z.string(), Z.integer()])
      iex> |> Z.parse(["hello", 42], coerce: true)
      {:ok, {"hello", 42}}

  It can be converted into json schema:

      iex> Z.tuple([Z.string(), Z.integer()])
      iex> |> Z.describe("A name and age pair.")
      iex> |> Z.example({"Alice", 30})
      iex> |> Z.json_schema()
      %{
        "type" => "array",
        "description" => "A name and age pair.",
        "examples" => [["Alice", 30]],
        "prefixItems" => [
          %{"type" => "string"},
          %{"type" => "integer"}
        ],
        "items" => false,
        "minItems" => 2,
        "maxItems" => 2
      }

  """
  def tuple(types) when is_list(types), do: Zot.Type.Tuple.new(shape: types)
  def tuple(types) when is_tuple(types), do: Zot.Type.Tuple.new(shape: Tuple.to_list(types))

  @doc ~S"""
  Creates a union of two or more types.

  ## Examples

      iex> Z.union([Z.string(), Z.integer()])
      iex> |> Z.parse("hello")
      {:ok, "hello"}

      iex> Z.union([Z.string(), Z.integer()])
      iex> |> Z.parse(42)
      {:ok, 42}

  Beware that only one of the types will have its error reported:

      iex> Z.union([Z.string(), Z.integer()])
      iex> |> Z.parse(3.14)
      iex> |> unwrap_issue_message()
      "expected type integer, got float"

  See `discriminated_union/2` which provides more precise error
  reporting at the cost of requiring a discriminator field.

  It can be converted into json schema:

      iex> Z.union([Z.string(), Z.integer()])
      iex> |> Z.json_schema()
      %{
        "anyOf" => [
          %{
            "type" => "string"
          },
          %{
            "type" => "integer"
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
      iex> |> Z.describe("A universally unique identifier.")
      iex> |> Z.example("550e8400-e29b-41d4-a716-446655440000")
      iex> |> Z.json_schema()
      %{
        "type" => "string",
        "format" => "uuid",
        "description" => "A universally unique identifier.",
        "examples" => ["550e8400-e29b-41d4-a716-446655440000"]
      }

  """
  def uuid(version \\ :any), do: Zot.Type.UUID.new(version: version)

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # MODIFIERS                                                       #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Constraint phone numbers to a limited set of country codes.

  See `phone/1` for more details.
  """
  defdelegate allowed_country_codes(type, value, opts \\ []), to: Zot.Type.Phone

  @doc ~S"""
  Enforces that the URI has one of the given allowed schemes.

  See `uri/1` for more details.
  """
  defdelegate allowed_schemes(type, value, opts \\ []), to: Zot.Type.URI

  @doc ~S"""
  Wraps the parsed value in a branded tuple.

  ## Examples

      iex> Z.string()
      iex> |> Z.branded(:name)
      iex> |> Z.parse("Rafael")
      {:ok, {:name, "Rafael"}}

  """
  def branded(zot_type(_) = type, brand) when is_atom(brand),
    do: Zot.Type.Branded.new(brand: brand, inner_type: type)

  @doc ~S"""
  Enables automatic canonicalization for CIDR notation.

  When enabled, non-canonical CIDR notation (where the IP is not the
  network address) is automatically converted to canonical form.

  See `cidr/1` for more details.
  """
  defdelegate canonicalize(type, value), to: Zot.Type.CIDR

  @doc ~S"""
  Validates that the IP address falls within the given CIDR range(s).

  See `ip/1` for more details.
  """
  defdelegate cidr(type, range, opts \\ []), to: Zot.Type.IP

  @doc ~S"""
  Enforces that the string contains the given substring.
  """
  def contains(type, value, opts \\ [])
  def contains(%Zot.Type.String{} = type, value, opts), do: Zot.Type.String.contains(type, value, opts)

  @doc ~S"""
  Sets the field as not-required and provides a default value.
  """
  def default(zot_type(_) = type, value), do: %{type | required: false, default: value}

  @doc ~S"""
  Attaches a description to the type, for use in JSON Schema.
  """
  def describe(zot_type(_) = type, desc)
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
  def example(zot_type(_) = type, example), do: %{type | example: example}

  @doc ~S"""
  Defines the behavior for leading plus signs in phone numbers.

  See `phone/1` for more details.
  """
  defdelegate leading_plus_sign(type, value), to: Zot.Type.Phone

  @doc ~S"""
  Enforces that the string or list has the given length.
  """
  def length(type, value, opts \\ [])
  def length(%Zot.Type.List{} = type, value, opts), do: Zot.Type.List.length(type, value, opts)
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
  Enforces a minimum prefix length for CIDR notation.

  See `cidr/1` for more details.
  """
  defdelegate min_prefix(type, value, opts \\ []), to: Zot.Type.CIDR

  @doc ~S"""
  Enforces a maximum prefix length for CIDR notation.

  See `cidr/1` for more details.
  """
  defdelegate max_prefix(type, value, opts \\ []), to: Zot.Type.CIDR

  @doc ~S"""
  Sets the field as not required (nullable).
  """
  def optional(zot_type(_) = type), do: %{type | required: false}

  @doc ~S"""
  Sets the output format for the given type.

  For IP types, accepts `:string` (default) or `:tuple`.
  For CIDR types, accepts `:string` (default), `:tuple`, or `:map`.

  See `ip/1` and `cidr/1` for more details.
  """
  def output(type, value)
  def output(%Zot.Type.CIDR{} = type, value), do: Zot.Type.CIDR.output(type, value)
  def output(%Zot.Type.IP{} = type, value), do: Zot.Type.IP.output(type, value)

  @doc ~S"""
  Makes all fields optional. Optionally drops all nil fields from the
  resulting map, after successfully parsed and validate.

  ## Examples

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer()})
      iex> |> Z.partial()
      iex> |> Z.parse(%{name: "Alice"})
      {:ok, %{name: "Alice", age: nil}}

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer()})
      iex> |> Z.partial()
      iex> |> Z.parse(%{})
      {:ok, %{name: nil, age: nil}}

  You can optionally compact the resulting map (drop nil fields):

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer()})
      iex> |> Z.partial(compact: true)
      iex> |> Z.parse(%{name: "Alice"})
      {:ok, %{name: "Alice"}}

  It can be converted into json schema:

      iex> Z.strict_map(%{name: Z.string(), age: Z.integer()})
      iex> |> Z.partial()
      iex> |> Z.describe("A person's profile.")
      iex> |> Z.example(%{"name" => "Bob", "age" => 18})
      iex> |> Z.json_schema()
      %{
        "type" => "object",
        "description" => "A person's profile.",
        "examples" => [%{"name" => "Bob", "age" => 18}],
        "properties" => %{
          "name" => %{"type" => ["string", nil]},
          "age" => %{"type" => ["integer", nil]}
        },
        "required" => [],
        "additionalProperties" => false
      }

  """
  def partial(%Zot.Type.Map{} = type, opts \\ []) do
    shape =
      type.shape
      |> Enum.map(fn {key, t} -> {key, optional(t)} end)
      |> Enum.into(%{})

    case Keyword.get(opts, :compact, false) do
      true -> transform(%{type | shape: shape}, {__MODULE__, :__drop_nil_fields__, []})
      false -> %{type | shape: shape}
    end
  end

  @doc ~S"""
  Alias for `partial/2` with option `compact: true`.
  """
  def partial_compact(type), do: partial(type, compact: true)

  @doc ~S"""
  Creates a new map type with only the specified keys from the original shape.

  ## Examples

      iex> Z.strict_map(%{id: Z.uuid(), name: Z.string(), email: Z.email()})
      iex> |> Z.pick([:id, :name])
      iex> |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"})
      {:ok, %{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"}}

      iex> {:error, [issue]} =
      iex>   Z.strict_map(%{id: Z.uuid(), name: Z.string(), email: Z.email()})
      iex>   |> Z.pick([:id, :name])
      iex>   |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice", email: "alice@example.com"})
      iex>
      iex> assert issue.path == ["email"]
      iex> assert Exception.message(issue) == "unknown field"

  """
  def pick(%Zot.Type.Map{} = type, keys) when is_list(keys) do
    shape = Map.take(type.shape, keys)

    %{type | shape: shape}
  end

  @doc ~S"""
  Creates a new map type excluding the specified keys from the original shape.

  ## Examples

      iex> Z.strict_map(%{id: Z.uuid(), name: Z.string(), email: Z.email()})
      iex> |> Z.omit([:email])
      iex> |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"})
      {:ok, %{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"}}

      iex> {:error, [issue]} =
      iex>   Z.strict_map(%{id: Z.uuid(), name: Z.string(), password: Z.string()})
      iex>   |> Z.omit([:password])
      iex>   |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice", password: "secret"})
      iex>
      iex> assert issue.path == ["password"]
      iex> assert Exception.message(issue) == "unknown field"

  """
  def omit(%Zot.Type.Map{} = type, keys) when is_list(keys) do
    shape = Map.drop(type.shape, keys)

    %{type | shape: shape}
  end

  @doc ~S"""
  Rounds the float to the given number of decimal places.

  ## Examples

      iex> Z.float()
      iex> |> Z.precision(2)
      iex> |> Z.parse(3.14159)
      {:ok, 3.14}

      iex> Z.decimal()
      iex> |> Z.precision(2)
      iex> |> Z.parse(Decimal.new("3.14159"))
      {:ok, Decimal.new("3.14")}

  """
  def precision(%Zot.Type.Decimal{} = type, value), do: Zot.Type.Decimal.precision(type, value)
  def precision(%Zot.Type.Float{} = type, value), do: Zot.Type.Float.precision(type, value)

  @doc ~S"""
  Adds a custom refinement to the given type's effects pipeline, which
  is executed after the type is successfully parsed and validated.

  ## Examples

      iex> Z.integer()
      iex> |> Z.refine(& &1 >= 18)
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "is invalid"

  You can optionally provide a custom error message:

      iex> Z.integer()
      iex> |> Z.refine(& &1 >= 18, error: "must be greater than or equal to 18")
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be greater than or equal to 18"

  The error message may include the actual value:

      iex> Z.integer()
      iex> |> Z.refine(& &1 >= 18, error: "must be greater than or equal to 18, got %{actual}")
      iex> |> Z.parse(16)
      iex> |> unwrap_issue_message()
      "must be greater than or equal to 18, got 16"

  """
  @opts error: "is invalid"
  def refine(zot_type(_) = type, fun, opts \\ [])
      when is_mfa(fun)
      when is_function(fun, 1)
      when is_function(fun, 2),
      do: %{type | effects: type.effects ++ [{:refine, Zot.Parameterized.new(fun, @opts, opts)}]}

  @doc ~S"""
  Sets both min and max from an Elixir Range.
  """
  def range(type, value)
  def range(%Zot.Type.Decimal{} = type, value), do: Zot.Type.Decimal.range(type, value)
  def range(%Zot.Type.Float{} = type, value), do: Zot.Type.Float.range(type, value)
  def range(%Zot.Type.Integer{} = type, value), do: Zot.Type.Integer.range(type, value)

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

      iex> Z.integer()
      iex> |> Z.transform(&Decimal.new/1)
      iex> |> Z.parse(42)
      {:ok, Decimal.new(42)}

  """
  def transform(zot_type(_) = type, fun)
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | effects: type.effects ++ [{:transform, fun}]}

  @doc ~S"""
  Trims whitespace from the beginning and end of the string before
  validation.
  """
  def trim(%Zot.Type.String{} = type, value \\ true), do: Zot.Type.String.trim(type, value)

  @doc ~S"""
  Unwraps a branded type, returning its inner type.

  ## Examples

      iex> Z.string()
      iex> |> Z.branded(:name)
      iex> |> Z.unbranded()
      iex> |> Z.parse("Rafael")
      {:ok, "Rafael"}

  """
  def unbranded(%Zot.Type.Branded{} = type), do: type.inner_type

  @doc ~S"""
  Enforces the version for the given type.

  For CIDR types, accepts `:any`, `:v4`, or `:v6`.
  For IP types, accepts `:any`, `:v4`, or `:v6`.
  For UUID types, accepts `:any`, `:v1` through `:v8`.

  See `cidr/1`, `ip/1` and `uuid/1` for more details.
  """
  def version(type, value)
  def version(%Zot.Type.CIDR{} = type, value), do: Zot.Type.CIDR.version(type, value)
  def version(%Zot.Type.IP{} = type, value), do: Zot.Type.IP.version(type, value)
  def version(%Zot.Type.UUID{} = type, value), do: Zot.Type.UUID.version(type, value)

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  # CALLBACKS                                                       #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc false
  def __drop_nil_fields__(map) when is_non_struct_map(map) do
    map
    |> Enum.reject(fn {_, value} -> is_nil(value) end)
    |> Enum.into(%{})
  end
end
