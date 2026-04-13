defmodule Zot.Type.URITest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "require_host" do
    test "default (false) allows URIs without host" do
      assert {:ok, "/relative/path"} = Z.uri() |> Z.parse("/relative/path")
    end

    test "accepts URI with host when required" do
      assert {:ok, "https://example.com"} =
               Z.uri(require_host: true) |> Z.parse("https://example.com")
    end

    test "rejects URI without host when required" do
      assert {:error, [issue]} =
               Z.uri(require_host: true) |> Z.parse("/relative/path")

      assert Exception.message(issue) == "host is required"
    end

    test "rejects URN (no host) when required" do
      assert {:error, [issue]} =
               Z.uri(require_host: true) |> Z.parse("urn:isbn:0451450523")

      assert Exception.message(issue) == "host is required"
    end

    test "accepts URI with empty path but valid host when required" do
      assert {:ok, "https://example.com"} =
               Z.uri(require_host: true) |> Z.parse("https://example.com")
    end
  end
end
