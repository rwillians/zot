defmodule Zot.Type.URITest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "host validation" do
    test "accepts URI with host" do
      assert {:ok, "https://example.com"} = Z.uri() |> Z.parse("https://example.com")
    end

    test "rejects relative path (no host)" do
      assert {:error, [issue]} = Z.uri() |> Z.parse("/relative/path")
      assert Exception.message(issue) == "host is required"
    end

    test "rejects URN (no host)" do
      assert {:error, [issue]} = Z.uri() |> Z.parse("urn:isbn:0451450523")
      assert Exception.message(issue) == "host is required"
    end
  end
end
