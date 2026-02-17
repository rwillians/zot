defmodule ZotTest do
  use ExUnit.Case, async: true

  import Zot, only: [zot_type: 1]

  alias Zot, as: Z

  defmodule Foo do
    defstruct [:bar]
  end

  @doc ~S"""
  Returns a random value that's guaranteed not to be a Zot type.
  """
  @spec not_a_zot_type :: any

  def not_a_zot_type do
    Enum.random([
      %Foo{},
      :rand.uniform(100),
      :crypto.strong_rand_bytes(16) |> Base.encode64(),
      %{foo: :bar, bar: :baz, baz: :qux}
    ])
  end

  @doc ~S"""
  Returns a random value that's guaranteed not to be a Zot string type.
  """
  @spec not_a_zot_string :: any

  def not_a_zot_string do
    Enum.random([
      Zot.boolean(),
      Zot.float(),
      Zot.int(),
      Zot.date()
    ])
  end

  @doc ~S"""
  Given an error result containing exactly one `Zot.Issue`, returns
  the issue's messages string.
  """
  @spec unwrap_issue_message({:error, [Zot.Issue.t()]}) :: String.t()

  def unwrap_issue_message({:error, [issue]}), do: Exception.message(issue)

  doctest Zot
end
