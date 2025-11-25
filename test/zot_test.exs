defmodule ZotTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  doctest Zot

  test "calling new/1 with an invalid modifier raises an ArgumentError" do
    assert_raise ArgumentError, "Unknown option :foo for Zot.Type.String.new/1", fn ->
      Zot.Type.String.new(foo: true)
    end

    assert_raise ArgumentError, "Unknown option :foo for Zot.Type.String.new/1", fn ->
      Zot.Type.String.new(foo: {true, []})
    end
  end
end
