defmodule ZotTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  defmodule Address do
    defstruct [:line_1, :line_2, :city, :state, :zip]
  end

  doctest Zot
  doctest Zot.Issue, import: true

  test "calling new/1 with an invalid modifier raises an ArgumentError" do
    assert_raise ArgumentError, "Unknown option :foo", fn ->
      Zot.Type.String.new(foo: true)
    end

    assert_raise ArgumentError, "Unknown option :foo", fn ->
      Zot.Type.String.new(foo: {true, []})
    end
  end
end
