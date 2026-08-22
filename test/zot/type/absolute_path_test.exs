defmodule Zot.Type.AbsolutePathTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "format validation" do
    test "accepts the root path" do
      assert {:ok, "/"} = Z.absolute_path() |> Z.parse("/")
    end

    test "accepts nested paths" do
      assert {:ok, "/usr/local/bin"} = Z.absolute_path() |> Z.parse("/usr/local/bin")
    end

    test "accepts a trailing slash" do
      assert {:ok, "/var/log/"} = Z.absolute_path() |> Z.parse("/var/log/")
    end

    test "accepts segments with dots, spaces and special characters" do
      assert {:ok, "/etc/init.d"} = Z.absolute_path() |> Z.parse("/etc/init.d")
      assert {:ok, "/home/user/My Documents"} = Z.absolute_path() |> Z.parse("/home/user/My Documents")
      assert {:ok, "/foo/../bar"} = Z.absolute_path() |> Z.parse("/foo/../bar")
    end

    test "rejects an empty string" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.parse("")
      assert Exception.message(issue) == "is not a valid absolute path"
    end

    test "rejects relative paths" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.parse("usr/local")
      assert Exception.message(issue) == "is not a valid absolute path"

      assert {:error, [issue]} = Z.absolute_path() |> Z.parse("./foo")
      assert Exception.message(issue) == "is not a valid absolute path"
    end

    test "rejects empty segments" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.parse("//")
      assert Exception.message(issue) == "is not a valid absolute path"

      assert {:error, [issue]} = Z.absolute_path() |> Z.parse("/foo//bar")
      assert Exception.message(issue) == "is not a valid absolute path"
    end

    test "rejects non-string input" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.parse(42)
      assert Exception.message(issue) == "expected type string, got integer"
    end
  end

  describe "length validation" do
    test "accepts custom error messages on constraints" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.min(5, error: "too short") |> Z.parse("/tmp")
      assert Exception.message(issue) == "too short"
    end

    test "raises on invalid min, max or length" do
      assert_raise FunctionClauseError, fn -> Z.absolute_path(min: -1) end
      assert_raise FunctionClauseError, fn -> Z.absolute_path(max: 0) end
      assert_raise FunctionClauseError, fn -> Z.absolute_path(length: 0) end
    end
  end

  describe "trim" do
    test "defaults to false, so padded input fails format validation" do
      assert {:error, [issue]} = Z.absolute_path() |> Z.parse(" /tmp ")
      assert Exception.message(issue) == "is not a valid absolute path"
    end

    test "trims before validation when enabled" do
      assert {:ok, "/tmp"} = Z.absolute_path(trim: true) |> Z.parse(" /tmp ")
    end
  end

  describe "json schema" do
    test "marks the type as nullable when optional" do
      schema = Z.absolute_path() |> Z.optional() |> Z.json_schema()
      assert schema["type"] == ["string", nil]
    end
  end
end
