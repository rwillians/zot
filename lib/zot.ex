defmodule Zot do
  @moduledoc ~S"""
  A schema parser and validator library inspired by JavaScript's Zod.
  """

  import Zot.Helpers, only: [is_mfa: 1]

  alias Zot.Context

  @typedoc ~S"""
  The input data to be parsed.
  """
  @type input :: term

  @typedoc ~S"""
  The output data after parsing.
  """
  @type output :: term

  @typedoc ~S"""
  A refinement function or MFA tuple.
  """
  @type refinement :: mfa | (input -> true | false | :ok | {:error, String.t()})

  @typedoc ~S"""
  A transformation function or MFA tuple.
  """
  @type transformation :: mfa | (output -> {:ok, output} | {:error, String.t()} | {:error, Exception.t()} | output)

  @typedoc ~S"""
  Any struct that implements the `Zot.Type` protocol.
  """
  @type type :: Zot.Type.t()

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                          PROTOCOL API                           #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Parses the input with the given type.
  """
  @spec parse(type, input, opts :: keyword) ::
          {:ok, output}
          | {:error, [Zot.Issue.t()]}

  def parse(type, input, opts \\ []) do
    ctx =
      type
      |> Context.new(input)
      |> Context.parse(opts)

    case Context.valid?(ctx) do
      true -> {:ok, Context.get_parsed(ctx)}
      false -> {:error, Context.get_issues(ctx)}
    end
  end

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                         TYPE FACTORIES                          #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

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
  defdelegate boolean, to: Zot.Type.Boolean, as: :new

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
  @spec refine(type, refinement, [option]) :: type
        when option: {:error, String.t()}

  def refine(%_{__effects__: effects} = type, fun, opts \\ [])
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | __effects__: effects ++ [{:refine, fun, opts[:error] || "is invalid"}]}

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
  @spec transform(type, transformation) :: type

  def transform(%_{__effects__: effects} = type, fun)
      when is_mfa(fun)
      when is_function(fun, 1),
      do: %{type | __effects__: effects ++ [{:transform, fun}]}
end
