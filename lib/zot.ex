defmodule Zot do
  @moduledoc ~S"""
  A schema parser and validator library inspired by JavaScript's Zod.
  """

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
  @type refinement :: mfa | (input -> :ok | {:error, String.t()})

  @typedoc ~S"""
  A transformation function or MFA tuple.
  """
  @type transformation :: mfa | (input -> {:ok, input} | {:error, String.t()} | input)

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
end
