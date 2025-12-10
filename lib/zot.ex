defmodule Zot do
  @moduledoc ~S"""
  A schema parser and validator library inspired by JavaScript's Zod.
  """

  import Zot.Helpers, only: [is_mfa: 1]

  @typedoc ~S"""
  The input data to be parsed.
  """
  @typedoc since: "0.1.0"
  @type input :: term

  @typedoc ~S"""
  The output data after parsing.
  """
  @typedoc since: "0.1.0"
  @type output :: term

  @typedoc ~S"""
  A refinement function or MFA tuple.
  """
  @typedoc since: "0.1.0"
  @type refinement :: mfa | (input -> true | false | :ok | {:error, String.t()})

  @typedoc ~S"""
  A transformation function or MFA tuple.
  """
  @typedoc since: "0.1.0"
  @type transformation :: mfa | (output -> {:ok, output} | {:error, String.t()} | {:error, Exception.t()} | output)

  @typedoc ~S"""
  Any struct that implements the `Zot.Type` protocol.
  """
  @typedoc since: "0.1.0"
  @type type :: Zot.Type.t()

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                          PROTOCOL API                           #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Parses the input with the given type.
  """
  @doc since: "0.1.0"
  @spec parse(type, input, opts :: keyword) ::
          {:ok, output}
          | {:error, [Zot.Issue.t()]}

  def parse(type, input, opts \\ []) do
    ctx =
      type
      |> Zot.Context.new(input)
      |> Zot.Context.parse(opts)

    case Zot.Context.valid?(ctx) do
      true -> {:ok, Zot.Context.get_parsed(ctx)}
      false -> {:error, Zot.Context.get_issues(ctx)}
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                         TYPE FACTORIES                          #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Defines a type that accepts any value.

  ## Examples

      iex> Z.any()
      iex> |> Z.parse(:foo)
      {:ok, :foo}

      iex> Z.any()
      iex> |> Z.parse(true)
      {:ok, true}

      iex> Z.any()
      iex> |> Z.parse(Decimal.from_float(3.14))
      {:ok, Decimal.from_float(3.14)}

      iex> Z.any()
      iex> |> Z.parse(3.14)
      {:ok, 3.14}

      iex> Z.any()
      iex> |> Z.parse(42)
      {:ok, 42}

      iex> Z.any()
      iex> |> Z.parse("string")
      {:ok, "string"}

  """
  @doc since: "0.1.0"
  defdelegate any, to: Zot.Type.Any, as: :new

  @doc ~S"""
  Defines a type that accepts a boolean value.

  ## Examples

      iex> Z.boolean()
      iex> |> Z.parse(true)
      {:ok, true}

      iex> Z.boolean()
      iex> |> Z.parse(false)
      {:ok, false}

      iex> assert {:error, [issue]} =
      iex>   Z.boolean()
      iex>   |> Z.parse("true")
      iex>
      iex> Exception.message(issue)
      "expected type boolean, got string"

  ## Coercion

  When coersion is enabled in the parsing options, this type can
  coerce certain values into boolean:

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

      iex> assert {:error, [issue]} =
      iex>  Z.boolean()
      iex>  |> Z.parse("foo", coerce: true)
      iex>
      iex> Exception.message(issue)
      "cannot coerce 'foo' into boolean"

  """
  @doc since: "0.1.0"
  defdelegate boolean, to: Zot.Type.Boolean, as: :new

  @doc ~S"""
  Defines a type that accepts DateTime or an ISO 8601 string (when
  coercion is enabled).

  ## Examples

      iex> Z.date_time()
      iex> |> Z.parse(~U[2025-12-06T21:49:00Z])
      {:ok, ~U[2025-12-06T21:49:00Z]}

      iex> Z.date_time()
      iex> |> Z.parse("2025-12-06T21:49:00Z", coerce: true)
      {:ok, ~U[2025-12-06T21:49:00Z]}

  """
  defdelegate date_time, to: Zot.Type.DateTime, as: :new

  @doc ~S"""
  Defines a type that accepts Decimal values.

  ## Examples

      iex> Z.decimal()
      iex> |> Z.parse(Decimal.new("3.14"))
      {:ok, Decimal.new("3.14")}

      iex> assert {:error, [issue]} =
      iex>   Z.decimal(is: 42)
      iex>   |> Z.parse(Decimal.new(43))
      iex>
      iex> Exception.message(issue)
      "must be exactly 42, got 43"

      iex> assert {:error, [issue]} =
      iex>   Z.decimal(min: 42)
      iex>   |> Z.parse(Decimal.new("3.14"))
      iex>
      iex> Exception.message(issue)
      "must be greater than or equal to 42, got 3.14"

      iex> assert {:error, [issue]} =
      iex>   Z.decimal(max: 42)
      iex>   |> Z.parse(Decimal.new("43"))
      iex>
      iex> Exception.message(issue)
      "must be less than or equal to 42, got 43"

      iex> assert {:error, [issue]} =
      iex>   Z.decimal()
      iex>   |> Z.parse(3.14)
      iex>
      iex> Exception.message(issue)
      "expected type Decimal, got float"

      iex> Z.decimal()
      iex> |> Z.parse(42, coerce: true)
      {:ok, Decimal.new(42)}

      iex> Z.decimal()
      iex> |> Z.parse("12.345", coerce: true)
      {:ok, Decimal.new("12.345")}

  """
  defdelegate decimal(opts \\ []), to: Zot.Type.Decimal, as: :new

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                             EFFECTS                             #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Adds a refinement validation step to the given type.

  ## Examples

      iex> Z.boolean()
      iex> |> Z.refine(& &1 == true, error: "must be true")
      iex> |> Z.parse(true)
      {:ok, true}

      iex> assert {:error, [issue]} =
      iex>   Z.boolean()
      iex>   |> Z.refine(& &1 == true, error: "must be true")
      iex>   |> Z.parse(false)
      iex>
      iex> Exception.message(issue)
      "must be true"

  If no error message is provided, the default is "is invalid":

      iex> assert {:error, [issue]} =
      iex>   Z.boolean()
      iex>   |> Z.refine(& &1 == true)
      iex>   |> Z.parse(false)
      iex>
      iex> Exception.message(issue)
      "is invalid"

  You can mix and match refinements with transformations:

      iex> Z.boolean()
      iex> |> Z.refine(& &1 == true)
      iex> |> Z.transform(&to_string/1)
      iex> |> Z.refine(& &1 == "true")
      iex> |> Z.transform(&String.upcase/1)
      iex> |> Z.parse(true)
      {:ok, "TRUE"}

  """
  @doc since: "0.1.0"
  @spec refine(type, refinement, [option]) :: type
        when option: {:error, String.t()}

  def refine(%_{__effects__: effects} = type, fun, opts \\ [])
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | __effects__: effects ++ [{:refine, fun, opts}]}

  @doc ~S"""
  Adds a transformation step to the given type.

  ## Examples

      iex> Z.boolean()
      iex> |> Z.transform(&to_string/1)
      iex> |> Z.parse(true)
      {:ok, "true"}

  You can mix and match refinements with transformations:

      iex> Z.boolean()
      iex> |> Z.refine(& &1 == true)
      iex> |> Z.transform(&to_string/1)
      iex> |> Z.refine(& &1 == "true")
      iex> |> Z.transform(&String.upcase/1)
      iex> |> Z.parse(true)
      {:ok, "TRUE"}

  """
  @doc since: "0.1.0"
  @spec transform(type, transformation) :: type

  def transform(%_{__effects__: effects} = type, fun)
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | __effects__: effects ++ [{:transform, fun}]}
end
