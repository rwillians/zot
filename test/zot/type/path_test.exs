defmodule Zot.Type.PathTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "format validation (any kind)" do
    test "accepts the root path" do
      assert {:ok, "/"} = Z.path() |> Z.parse("/")
    end

    test "accepts absolute and relative paths" do
      assert {:ok, "/usr/local/bin"} = Z.path() |> Z.parse("/usr/local/bin")
      assert {:ok, "usr/local/bin"} = Z.path() |> Z.parse("usr/local/bin")
    end

    test "accepts a trailing slash" do
      assert {:ok, "/var/log/"} = Z.path() |> Z.parse("/var/log/")
      assert {:ok, "var/log/"} = Z.path() |> Z.parse("var/log/")
    end

    test "accepts segments with dots, spaces and special characters" do
      assert {:ok, "/etc/init.d"} = Z.path() |> Z.parse("/etc/init.d")
      assert {:ok, "My Documents/report.pdf"} = Z.path() |> Z.parse("My Documents/report.pdf")
      assert {:ok, "foo/../bar"} = Z.path() |> Z.parse("foo/../bar")
    end

    test "rejects an empty string" do
      assert {:error, [issue]} = Z.path() |> Z.parse("")
      assert Exception.message(issue) == "is not a valid path"
    end

    test "rejects empty segments" do
      assert {:error, [issue]} = Z.path() |> Z.parse("//")
      assert Exception.message(issue) == "is not a valid path"

      assert {:error, [issue]} = Z.path() |> Z.parse("/foo//bar")
      assert Exception.message(issue) == "is not a valid path"

      assert {:error, [issue]} = Z.path() |> Z.parse("foo//bar")
      assert Exception.message(issue) == "is not a valid path"
    end

    test "rejects non-string input" do
      assert {:error, [issue]} = Z.path() |> Z.parse(42)
      assert Exception.message(issue) == "expected type string, got integer"
    end
  end

  describe "kind :absolute" do
    test "accepts absolute paths" do
      assert {:ok, "/"} = Z.path(kind: :absolute) |> Z.parse("/")
      assert {:ok, "/usr/local"} = Z.path(kind: :absolute) |> Z.parse("/usr/local")
    end

    test "rejects relative paths" do
      assert {:error, [issue]} = Z.path(kind: :absolute) |> Z.parse("usr/local")
      assert Exception.message(issue) == "is not a valid absolute path"
    end

    test "can be given as a keyword option" do
      assert {:error, [issue]} = Z.path(kind: :absolute) |> Z.parse("usr/local")
      assert Exception.message(issue) == "is not a valid absolute path"
    end
  end

  describe "kind :relative" do
    test "accepts relative paths" do
      assert {:ok, "lib"} = Z.path(kind: :relative) |> Z.parse("lib")
      assert {:ok, "lib/zot.ex"} = Z.path(kind: :relative) |> Z.parse("lib/zot.ex")
    end

    test "rejects absolute paths" do
      assert {:error, [issue]} = Z.path(kind: :relative) |> Z.parse("/lib/zot.ex")
      assert Exception.message(issue) == "is not a valid relative path"
    end

    test "rejects the root path" do
      assert {:error, [issue]} = Z.path(kind: :relative) |> Z.parse("/")
      assert Exception.message(issue) == "is not a valid relative path"
    end
  end

  describe "glob" do
    test "matches * within a single segment" do
      assert {:ok, "lib/zot.ex"} = Z.path(glob: "lib/*.ex") |> Z.parse("lib/zot.ex")

      assert {:error, [issue]} = Z.path(glob: "lib/*.ex") |> Z.parse("lib/zot/type.ex")
      assert Exception.message(issue) == "does not match pattern \"lib/*.ex\""
    end

    test "matches ** across segments" do
      assert {:ok, "lib/zot/type/path.ex"} = Z.path(glob: "lib/**/*.ex") |> Z.parse("lib/zot/type/path.ex")
      assert {:ok, "lib/zot.ex"} = Z.path(glob: "lib/**/*.ex") |> Z.parse("lib/zot.ex")
    end

    test "matches alternatives" do
      assert {:ok, "a.exs"} = Z.path(glob: "*.{ex,exs}") |> Z.parse("a.exs")

      assert {:error, [issue]} = Z.path(glob: "*.{ex,exs}") |> Z.parse("a.js")
      assert Exception.message(issue) == "does not match pattern \"*.{ex,exs}\""
    end

    test "runs after kind validation" do
      assert {:error, [issue]} = Z.path(kind: :relative, glob: "**/*.ex") |> Z.parse("/lib/zot.ex")
      assert Exception.message(issue) == "is not a valid relative path"
    end

    test "accepts a custom error message" do
      assert {:error, [issue]} = Z.path() |> Z.glob("*.ex", error: "not an elixir file") |> Z.parse("a.js")
      assert Exception.message(issue) == "not an elixir file"
    end
  end

  describe "length validation" do
    test "accepts custom error messages on constraints" do
      assert {:error, [issue]} = Z.path() |> Z.min(5, error: "too short") |> Z.parse("/tmp")
      assert Exception.message(issue) == "too short"
    end

    test "raises on invalid min, max or length" do
      assert_raise FunctionClauseError, fn -> Z.path(min: -1) end
      assert_raise FunctionClauseError, fn -> Z.path(max: 0) end
      assert_raise FunctionClauseError, fn -> Z.path(length: 0) end
    end
  end

  describe "constructor" do
    test "raises on an argument that is neither a glob nor options" do
      assert_raise FunctionClauseError, fn -> Z.path(:absolute) end
      assert_raise FunctionClauseError, fn -> Z.path(:rooted) end
    end

    test "a string argument is a shorthand for the :glob option" do
      assert {:ok, "lib/zot.ex"} = Z.path("**/*.ex") |> Z.parse("lib/zot.ex")

      assert {:error, [issue]} = Z.path("**/*.ex") |> Z.parse("assets/app.js")
      assert Exception.message(issue) == "does not match pattern \"**/*.ex\""
    end

    test "Z.absolute_path/0 is an alias to Z.path(kind: :absolute)" do
      assert Z.absolute_path() == Z.path(kind: :absolute)
    end

    test "Z.relative_path/0 is an alias to Z.path(kind: :relative)" do
      assert Z.relative_path() == Z.path(kind: :relative)
    end

    test "raises on unknown options" do
      assert_raise ArgumentError, "Unknown option :regex", fn -> Z.path(regex: ~r"foo") end
      assert_raise ArgumentError, "Unknown option :trim", fn -> Z.path(trim: true) end
    end
  end

  describe "json schema" do
    test "marks the type as nullable when optional" do
      schema = Z.path() |> Z.optional() |> Z.json_schema()
      assert schema["type"] == ["string", nil]
    end

    test "includes the kind pattern and length constraints" do
      schema = Z.path(kind: :relative, min: 1, max: 255) |> Z.json_schema()
      assert schema["pattern"] == "^[^/]{1,}(/[^/]{1,}){0,}/?$"
      assert schema["minLength"] == 1
      assert schema["maxLength"] == 255
    end
  end
end
