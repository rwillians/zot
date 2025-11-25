defmodule Zot do
  @moduledoc ~S"""
  A schema parser and validator library inspired by JavaScript's Zod.
  """

  require Zot.Type
  require Zot.Type.Boolean
  require Zot.Type.DateTime
  require Zot.Type.Email
  require Zot.Type.String

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                               PROTOCOL API                                #
  #                      keep them sorted alphabetically                      #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Parses a value with the given Zot type.
  """
  defdelegate parse(type, value, opts \\ []), to: Zot.Type

  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
  #                                 FACTORIES                                 #
  #                      keep them sorted alphabetically                      #
  # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

  @doc ~S"""
  Defines a type that accepts boolean values.

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

  """
  defdelegate boolean, to: Zot.Type.Boolean, as: :new

  @doc ~S"""
  Defines a zot type that accepts date-times (ISO 8601) values.

  ## Examples

      iex> Z.date_time()
      iex> |> Z.parse(~U[2025-11-22T13:45:00.000Z])
      {:ok, ~U[2025-11-22T13:45:00.000Z]}

      iex> assert {:error, [issue]} =
      iex>   Z.date_time()
      iex>   |> Z.parse("2025-11-22T13:45:00.000Z")
      iex>
      iex> Exception.message(issue)
      "expected type DateTime, got string"

      iex> Z.date_time()
      iex> |> Z.parse("2025-11-22T13:45:00.000Z", coerce: true)
      {:ok, ~U[2025-11-22T13:45:00.000Z]}

      iex> assert {:error, [issue]} =
      iex>   Z.date_time()
      iex>   |> Z.parse("2025-11-22T13:45:00.000", coerce: true)
      iex>
      iex> Exception.message(issue)
      "is missing the timezone offset"

      iex> assert {:error, [issue]} =
      iex>   Z.date_time()
      iex>   |> Z.parse("2025-14-22T13:45:00.000Z", coerce: true)
      iex>
      iex> Exception.message(issue)
      "is not a valid ISO 8601 date-time string"

      iex> assert {:error, [issue]} =
      iex>   Z.date_time()
      iex>   |> Z.parse("2025-11-22T25:45:00.000Z", coerce: true)
      iex>
      iex> Exception.message(issue)
      "is not a valid ISO 8601 date-time string"

      iex> Z.date_time()
      iex> |> Z.parse("2025-11-22T13:45:00.000-00:00", coerce: true)
      {:ok, ~U[2025-11-22 13:45:00.000Z]}

  """
  defdelegate date_time, to: Zot.Type.DateTime, as: :new

  @doc ~S"""
  Defines a type that accepts email address values.

  ## Examples

      iex> Z.email()
      iex> |> Z.parse("user@example.com")
      {:ok, "user@example.com"}

      iex> assert {:error, [issue]} =
      iex>   Z.email()
      iex>   |> Z.parse("")
      iex>
      iex> Exception.message(issue)
      "is not a valid email address"

      iex> assert {:error, [issue]} =
      iex>   Z.email()
      iex>   |> Z.parse("user")
      iex>
      iex> Exception.message(issue)
      "is not a valid email address"

      iex> assert {:error, [issue]} =
      iex>   Z.email()
      iex>   |> Z.parse("@example.com")
      iex>
      iex> Exception.message(issue)
      "is not a valid email address"

  """
  defdelegate email(opts \\ []), to: Zot.Type.Email, as: :new

  @doc ~S"""
  Defines a type that accepts float values.

  ## Examples

      iex> Z.float()
      iex> |> Z.parse(3.14)
      {:ok, 3.14}

      iex> assert {:error, [issue]} =
      iex>   Z.float()
      iex>   |> Z.parse("3.14")
      iex>
      iex> Exception.message(issue)
      "expected type float, got string"

      iex> assert {:error, [issue]} =
      iex>   Z.float()
      iex>   |> Z.parse(3)
      iex>
      iex> Exception.message(issue)
      "expected type float, got integer"

  """
  defdelegate float, to: Zot.Type.Float, as: :new

  @doc ~S"""
  Defines a type that accepts string values.

  ## Examples

      iex> Z.string(trim: true)
      iex> |> Z.parse(" hello world  ")
      {:ok, "hello world"}

      iex> assert {:error, [issue]} =
      iex>   Z.string(length: 5)
      iex>   |> Z.parse("foo")
      iex>
      iex> Exception.message(issue)
      "expected string to have exactly 5 characters, got 3 characters"

      iex> assert {:error, [issue]} =
      iex>   Z.string(min: 3)
      iex>   |> Z.parse("fu")
      iex>
      iex> Exception.message(issue)
      "expected string to have at least 3 characters, got 2 characters"

      iex> assert {:error, [issue]} =
      iex>   Z.string(max: 3)
      iex>   |> Z.parse("fudge")
      iex>
      iex> Exception.message(issue)
      "expected string to have at most 3 characters, got 5 characters"

      iex> assert {:error, [issue]} =
      iex>   Z.string(starts_with: "foo")
      iex>   |> Z.parse("bar")
      iex>
      iex> Exception.message(issue)
      "expected string to start with 'foo'"

      iex> assert {:error, [issue]} =
      iex>   Z.string(ends_with: "bar")
      iex>   |> Z.parse("foo")
      iex>
      iex> Exception.message(issue)
      "expected string to end with 'bar'"

      iex> assert {:error, [issue]} =
      iex>   Z.string(regex: ~r/^foo/)
      iex>   |> Z.parse("bar")
      iex>
      iex> Exception.message(issue)
      "expected string to match the pattern /^foo/"

  """
  defdelegate string(opts \\ []), to: Zot.Type.String, as: :new
end
