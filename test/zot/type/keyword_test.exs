defmodule Zot.Type.KeywordTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "input validation" do
    test "accepts an empty keyword list" do
      assert {:ok, [name: nil]} = Z.keyword(name: Z.optional(Z.string())) |> Z.parse([])
    end

    test "rejects non-list input" do
      assert {:error, [issue]} = Z.keyword(name: Z.string()) |> Z.parse(%{name: "Alice"})
      assert Exception.message(issue) == "expected type keyword, got map"

      assert {:error, [issue]} = Z.keyword(name: Z.string()) |> Z.parse("nope")
      assert Exception.message(issue) == "expected type keyword, got string"
    end

    test "rejects lists that are not keyword lists" do
      assert {:error, [issue]} = Z.keyword(name: Z.string()) |> Z.parse([1, 2, 3])
      assert Exception.message(issue) == "expected type keyword, got list"
    end

    test "rejects lists with loose elements after keyword pairs" do
      assert {:error, [issue]} = Z.keyword(name: Z.string()) |> Z.parse([{:name, "Alice"}, "junk"])
      assert Exception.message(issue) == "expected type keyword, got list"
    end
  end

  describe "modes" do
    test "strip mode drops unknown fields" do
      assert {:ok, [name: "Alice"]} =
               Z.keyword(name: Z.string()) |> Z.parse(name: "Alice", age: 30)
    end

    test "strict mode errors on unknown fields" do
      assert {:error, [issue]} =
               Z.strict_keyword(name: Z.string()) |> Z.parse(name: "Alice", age: 30)

      assert issue.path == ["age"]
      assert Exception.message(issue) == "unknown field"
    end
  end

  describe "shape" do
    test "accepts a map shape" do
      assert {:ok, [name: "Alice"]} = Z.keyword(%{name: Z.string()}) |> Z.parse(name: "Alice")
    end

    test "output follows the shape's key order regardless of input order" do
      assert {:ok, [b: 2, a: 1, c: 3]} =
               Z.keyword(b: Z.integer(), a: Z.integer(), c: Z.integer())
               |> Z.parse(c: 3, a: 1, b: 2)
    end

    test "duplicated input keys resolve to the first occurrence" do
      assert {:ok, [name: "Alice"]} =
               Z.keyword(name: Z.string()) |> Z.parse(name: "Alice", name: "Bob")
    end
  end

  describe "issues" do
    test "collects issues with field paths" do
      assert {:error, [%Zot.Issue{path: [:age]}]} =
               Z.keyword(name: Z.string(), age: Z.integer(min: 18))
               |> Z.parse(name: "Alice", age: 16)
    end

    test "partial output is a keyword list in shape order" do
      type = Z.keyword(a: Z.integer(), b: Z.string(), c: Z.integer())

      assert {:error, [_], partial} = Zot.Type.parse(type, [c: 3, b: :nope, a: 1], [])
      assert partial == [a: 1, c: 3]
    end
  end

  describe "parse options" do
    test "coerces field values when coerce is enabled" do
      assert {:ok, [age: 30]} = Z.keyword(age: Z.integer()) |> Z.parse([age: "30"], coerce: true)
    end

    test "recases input keys when recase is enabled" do
      assert {:ok, [first_name: "Alice"]} =
               Z.keyword(first_name: Z.string())
               |> Z.parse([firstName: "Alice"], recase: true)
    end
  end

  describe "partial" do
    test "makes all fields optional" do
      assert {:ok, [name: "Alice", age: nil]} =
               Z.keyword(name: Z.string(), age: Z.integer())
               |> Z.partial()
               |> Z.parse(name: "Alice")
    end

    test "compact drops nil fields" do
      assert {:ok, [age: 30]} =
               Z.keyword(name: Z.string(), age: Z.integer())
               |> Z.partial(compact: true)
               |> Z.parse(age: 30)
    end

    test "partial_compact is an alias for partial with compact" do
      assert {:ok, [name: "Alice"]} =
               Z.keyword(name: Z.string(), age: Z.integer())
               |> Z.partial_compact()
               |> Z.parse(name: "Alice")
    end
  end

  describe "json schema" do
    test "strict mode disallows additional properties" do
      schema = Z.strict_keyword(name: Z.string()) |> Z.json_schema()
      assert schema["additionalProperties"] == false
    end

    test "partial makes all properties nullable and none required" do
      schema = Z.keyword(name: Z.string()) |> Z.partial() |> Z.json_schema()
      assert schema["required"] == []
      assert schema["properties"]["name"]["type"] == ["string", nil]
    end
  end
end
