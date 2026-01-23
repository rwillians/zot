defmodule Zot.Type.ListTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "edge cases" do
    test "accepts empty list" do
      assert {:ok, []} = Z.string() |> Z.list() |> Z.parse([])
    end

    test "rejects non-list types" do
      type = Z.string() |> Z.list()

      assert {:error, [issue]} = type |> Z.parse("not a list")
      assert Exception.message(issue) == "expected type list, got string"

      assert {:error, [issue]} = type |> Z.parse(%{})
      assert Exception.message(issue) == "expected type list, got map"

      assert {:error, [issue]} = type |> Z.parse(123)
      assert Exception.message(issue) == "expected type list, got integer"
    end

    test "validates all items against inner type" do
      type = Z.int() |> Z.list()

      assert {:ok, [1, 2, 3]} = type |> Z.parse([1, 2, 3])
    end
  end

  describe "length constraints" do
    test "min length at boundary" do
      type = Z.string() |> Z.list(min: 2)

      assert {:ok, ["a", "b"]} = type |> Z.parse(["a", "b"])
      assert {:error, [issue]} = type |> Z.parse(["a"])
      assert Exception.message(issue) == "must have at least 2 items, got 1"
    end

    test "max length at boundary" do
      type = Z.string() |> Z.list(max: 2)

      assert {:ok, ["a", "b"]} = type |> Z.parse(["a", "b"])
      assert {:error, [issue]} = type |> Z.parse(["a", "b", "c"])
      assert Exception.message(issue) == "must have at most 2 items, got 3"
    end

    test "exact length" do
      type = Z.string() |> Z.list(length: 3)

      assert {:ok, ["a", "b", "c"]} = type |> Z.parse(["a", "b", "c"])

      assert {:error, [issue]} = type |> Z.parse(["a", "b"])
      assert Exception.message(issue) == "must have 3 items, got 2"

      assert {:error, [issue]} = type |> Z.parse(["a", "b", "c", "d"])
      assert Exception.message(issue) == "must have 3 items, got 4"
    end

    test "min and max together" do
      type = Z.string() |> Z.list(min: 1, max: 3)

      assert {:ok, ["a"]} = type |> Z.parse(["a"])
      assert {:ok, ["a", "b", "c"]} = type |> Z.parse(["a", "b", "c"])
      assert {:error, _} = type |> Z.parse([])
      assert {:error, _} = type |> Z.parse(["a", "b", "c", "d"])
    end
  end

  describe "multiple validation errors" do
    test "reports errors for multiple invalid items" do
      type = Z.int() |> Z.list()

      {:error, issues} = type |> Z.parse(["a", "b", "c"])

      assert length(issues) == 3

      paths = Enum.map(issues, & &1.path)
      assert [0] in paths
      assert [1] in paths
      assert [2] in paths
    end

    test "reports errors with correct indices" do
      type = Z.int(min: 0) |> Z.list()

      {:error, issues} = type |> Z.parse([1, -2, 3, -4])

      assert length(issues) == 2

      paths = Enum.map(issues, & &1.path)
      assert [1] in paths
      assert [3] in paths
    end
  end

  describe "nested structures" do
    test "list of maps" do
      type =
        Z.map(%{name: Z.string(), age: Z.int()})
        |> Z.list()

      input = [
        %{name: "Alice", age: 30},
        %{name: "Bob", age: 25}
      ]

      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "errors in list of maps have correct paths" do
      type =
        Z.map(%{name: Z.string(), age: Z.int(min: 0)})
        |> Z.list()

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

    test "deeply nested list paths" do
      type =
        Z.map(%{
          users: Z.map(%{name: Z.string()}) |> Z.list()
        })

      {:error, [issue]} =
        type
        |> Z.parse(%{users: [%{name: "Alice"}, %{name: 123}]})

      assert issue.path == [:users, 1, :name]
    end

    test "list of lists" do
      type = Z.int() |> Z.list() |> Z.list()

      input = [[1, 2], [3, 4], [5, 6]]
      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "errors in list of lists have correct paths" do
      type = Z.int() |> Z.list() |> Z.list()

      {:error, [issue]} = type |> Z.parse([[1, 2], [3, "invalid"]])

      assert issue.path == [1, 1]
    end
  end

  describe "coercion" do
    test "coerces items" do
      type = Z.int() |> Z.list()

      assert {:ok, [1, 2, 3]} = type |> Z.parse(["1", "2", "3"], coerce: true)
    end

    test "coercion with nested maps" do
      type =
        Z.map(%{value: Z.int()})
        |> Z.list()

      input = [%{value: "1"}, %{value: "2"}]

      assert {:ok, [%{value: 1}, %{value: 2}]} = type |> Z.parse(input, coerce: true)
    end
  end

  describe "optional and default" do
    test "optional list accepts nil" do
      type = Z.string() |> Z.list() |> Z.optional()

      assert {:ok, nil} = type |> Z.parse(nil)
    end

    test "default value for list" do
      type = Z.string() |> Z.list() |> Z.default([])

      assert {:ok, []} = type |> Z.parse(nil)
    end

    test "default value can be a non-empty list" do
      type = Z.string() |> Z.list() |> Z.default(["default"])

      assert {:ok, ["default"]} = type |> Z.parse(nil)
    end
  end

  describe "effects on list" do
    test "transform on list result" do
      type =
        Z.int()
        |> Z.list()
        |> Z.transform(&Enum.sum/1)

      assert {:ok, 6} = type |> Z.parse([1, 2, 3])
    end

    test "refine on list result" do
      type =
        Z.int()
        |> Z.list()
        |> Z.refine(fn list -> length(list) > 0 end, error: "must not be empty")

      assert {:error, [issue]} = type |> Z.parse([])
      assert Exception.message(issue) == "must not be empty"
    end
  end
end
