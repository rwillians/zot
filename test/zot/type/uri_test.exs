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

  describe "require_path" do
    test "default (false) allows URIs without path" do
      assert {:ok, "https://example.com"} = Z.uri() |> Z.parse("https://example.com")
    end

    test "accepts URI with non-root path when required" do
      assert {:ok, "https://example.com/foo"} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/foo")
    end

    test "rejects URI with nil path when required" do
      assert {:error, [issue]} =
               Z.uri(require_path: true) |> Z.parse("https://example.com")

      assert Exception.message(issue) == "path is required"
    end

    test "rejects URI with root-only path when required" do
      assert {:error, [issue]} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/")

      assert Exception.message(issue) == "path is required"
    end

    test "accepts nested path when required" do
      assert {:ok, "https://example.com/foo/bar"} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/foo/bar")
    end
  end
end
