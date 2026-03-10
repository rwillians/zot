defmodule Zot.Type.SetTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "edge cases" do
    test "accepts empty list" do
      assert {:ok, []} = Z.string() |> Z.set() |> Z.parse([])
    end

    test "rejects non-list types" do
      type = Z.string() |> Z.set()

      assert {:error, [issue]} = type |> Z.parse("not a list")
      assert Exception.message(issue) == "expected type list, got string"

      assert {:error, [issue]} = type |> Z.parse(%{})
      assert Exception.message(issue) == "expected type list, got map"

      assert {:error, [issue]} = type |> Z.parse(123)
      assert Exception.message(issue) == "expected type list, got integer"
    end

    test "validates all items against inner type" do
      type = Z.int() |> Z.set()

      assert {:ok, [1, 2, 3]} = type |> Z.parse([1, 2, 3])
    end
  end

  describe "deduplication" do
    test "deduplicates items by default" do
      type = Z.string() |> Z.set()

      assert {:ok, ["a", "b"]} = type |> Z.parse(["a", "b", "a"])
    end

    test "deduplicates preserving first occurrence order" do
      type = Z.int() |> Z.set()

      assert {:ok, [1, 2, 3]} = type |> Z.parse([1, 2, 3, 2, 1])
    end

    test "deduplicates after parsing items" do
      type = Z.int() |> Z.set()

      assert {:ok, [1, 2, 3]} = type |> Z.parse([1, 2, 3])
    end
  end

  describe "unique modifier" do
    test "errors on duplicate items when unique is set" do
      type = Z.string() |> Z.set(unique: :enforce)

      assert {:error, [issue]} = type |> Z.parse(["a", "b", "a"])
      assert Exception.message(issue) == "expected unique values only, found duplicate at index 2"
      assert issue.path == [2]
    end

    test "errors on multiple duplicate items" do
      type = Z.int() |> Z.set(unique: :enforce)

      assert {:error, issues} = type |> Z.parse([1, 2, 1, 2, 3])
      assert length(issues) == 2

      paths = Enum.map(issues, & &1.path)
      assert [2] in paths
      assert [3] in paths
    end

    test "passes when all items are unique" do
      type = Z.string() |> Z.set(unique: :enforce)

      assert {:ok, ["a", "b", "c"]} = type |> Z.parse(["a", "b", "c"])
    end

    test "accepts custom error message" do
      type = Z.string() |> Z.set()
      type = Zot.Type.Set.unique(type, :enforce, error: "no duplicates allowed at index %{index}")

      assert {:error, [issue]} = type |> Z.parse(["x", "y", "x"])
      assert Exception.message(issue) == "no duplicates allowed at index 2"
    end
  end

  describe "length constraints" do
    test "min length at boundary" do
      type = Z.string() |> Z.set(min: 2)

      assert {:ok, ["a", "b"]} = type |> Z.parse(["a", "b"])
      assert {:error, [issue]} = type |> Z.parse(["a"])
      assert Exception.message(issue) == "must have at least 2 items, got 1"
    end

    test "max length at boundary" do
      type = Z.string() |> Z.set(max: 2)

      assert {:ok, ["a", "b"]} = type |> Z.parse(["a", "b"])
      assert {:error, [issue]} = type |> Z.parse(["a", "b", "c"])
      assert Exception.message(issue) == "must have at most 2 items, got 3"
    end

    test "exact length" do
      type = Z.string() |> Z.set(length: 3)

      assert {:ok, ["a", "b", "c"]} = type |> Z.parse(["a", "b", "c"])

      assert {:error, [issue]} = type |> Z.parse(["a", "b"])
      assert Exception.message(issue) == "must have 3 items, got 2"

      assert {:error, [issue]} = type |> Z.parse(["a", "b", "c", "d"])
      assert Exception.message(issue) == "must have 3 items, got 4"
    end

    test "min and max together" do
      type = Z.string() |> Z.set(min: 1, max: 3)

      assert {:ok, ["a"]} = type |> Z.parse(["a"])
      assert {:ok, ["a", "b", "c"]} = type |> Z.parse(["a", "b", "c"])
      assert {:error, _} = type |> Z.parse([])
      assert {:error, _} = type |> Z.parse(["a", "b", "c", "d"])
    end
  end

  describe "multiple validation errors" do
    test "reports errors for multiple invalid items" do
      type = Z.int() |> Z.set()

      {:error, issues} = type |> Z.parse(["a", "b", "c"])

      assert length(issues) == 3

      paths = Enum.map(issues, & &1.path)
      assert [0] in paths
      assert [1] in paths
      assert [2] in paths
    end

    test "reports errors with correct indices" do
      type = Z.int(min: 0) |> Z.set()

      {:error, issues} = type |> Z.parse([1, -2, 3, -4])

      assert length(issues) == 2

      paths = Enum.map(issues, & &1.path)
      assert [1] in paths
      assert [3] in paths
    end
  end

  describe "nested structures" do
    test "set of maps" do
      type =
        Z.map(%{name: Z.string(), age: Z.int()})
        |> Z.set()

      input = [
        %{name: "Alice", age: 30},
        %{name: "Bob", age: 25}
      ]

      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "errors in set of maps have correct paths" do
      type =
        Z.map(%{name: Z.string(), age: Z.int(min: 0)})
        |> Z.set()

      {:error, issues} =
        type
        |> Z.parse([
          %{name: "Alice", age: 30},
          %{name: 123, age: -1}
        ])

      assert length(issues) == 2

      paths = Enum.map(issues, & &1.path)
      assert [1, :name] in paths
      assert [1, :age] in paths
    end
  end

  describe "coercion" do
    test "coerces items" do
      type = Z.int() |> Z.set()

      assert {:ok, [1, 2, 3]} = type |> Z.parse(["1", "2", "3"], coerce: true)
    end

    test "coercion with nested maps" do
      type =
        Z.map(%{value: Z.int()})
        |> Z.set()

      input = [%{value: "1"}, %{value: "2"}]

      assert {:ok, [%{value: 1}, %{value: 2}]} = type |> Z.parse(input, coerce: true)
    end
  end

  describe "optional and default" do
    test "optional set accepts nil" do
      type = Z.string() |> Z.set() |> Z.optional()

      assert {:ok, nil} = type |> Z.parse(nil)
    end

    test "default value for set" do
      type = Z.string() |> Z.set() |> Z.default([])

      assert {:ok, []} = type |> Z.parse(nil)
    end
  end

  describe "effects on set" do
    test "transform on set result" do
      type =
        Z.int()
        |> Z.set()
        |> Z.transform(&Enum.sum/1)

      assert {:ok, 6} = type |> Z.parse([1, 2, 3])
    end

    test "refine on set result" do
      type =
        Z.int()
        |> Z.set()
        |> Z.refine(fn list -> length(list) > 0 end, error: "must not be empty")

      assert {:error, [issue]} = type |> Z.parse([])
      assert Exception.message(issue) == "must not be empty"
    end
  end

  describe "json schema" do
    test "generates json schema with uniqueItems" do
      schema =
        Z.string()
        |> Z.set(min: 1, max: 10)
        |> Z.describe("A set of tags.")
        |> Z.json_schema()

      assert schema["type"] == "string" || schema["type"] == "array"
      assert schema["uniqueItems"] == true
    end
  end
end
