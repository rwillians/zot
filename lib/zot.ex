defmodule Zot do
  @moduledoc ~S"""
  A schema parser and validator library inspired by JavaScript's Zod.
  """

  require Zot.Type
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
  Defines a zot type that accepts strings.

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
