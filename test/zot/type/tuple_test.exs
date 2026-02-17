defmodule Zot.Type.TupleTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "basic usage" do
    test "accepts valid tuple with list of types" do
      type = Z.tuple([Z.string(), Z.int()])

      assert {:ok, {"hello", 42}} = type |> Z.parse({"hello", 42})
    end

    test "accepts valid tuple with tuple of types" do
      type = Z.tuple({Z.string(), Z.int()})

      assert {:ok, {"hello", 42}} = type |> Z.parse({"hello", 42})
    end

    test "accepts empty tuple" do
      type = Z.tuple([])

      assert {:ok, {}} = type |> Z.parse({})
    end

    test "accepts single-element tuple" do
      type = Z.tuple([Z.string()])

      assert {:ok, {"hello"}} = type |> Z.parse({"hello"})
    end
  end

  describe "type validation" do
    test "rejects non-tuple types" do
      type = Z.tuple([Z.string(), Z.int()])

      assert {:error, [issue]} = type |> Z.parse("not a tuple")
      assert Exception.message(issue) == "expected type tuple, got string"

      assert {:error, [issue]} = type |> Z.parse(%{})
      assert Exception.message(issue) == "expected type tuple, got map"

      assert {:error, [issue]} = type |> Z.parse([1, 2])
      assert Exception.message(issue) == "expected type tuple, got list"

      assert {:error, [issue]} = type |> Z.parse(123)
      assert Exception.message(issue) == "expected type tuple, got integer"
    end
  end

  describe "size validation" do
    test "rejects tuple with too few elements" do
      type = Z.tuple([Z.string(), Z.int(), Z.boolean()])

      assert {:error, [issue]} = type |> Z.parse({"hello", 42})
      assert Exception.message(issue) == "expected a tuple with 3 elements, got 2"
    end

    test "rejects tuple with too many elements" do
      type = Z.tuple([Z.string(), Z.int()])

      assert {:error, [issue]} = type |> Z.parse({"hello", 42, true})
      assert Exception.message(issue) == "expected a tuple with 2 elements, got 3"
    end

    test "empty tuple rejects non-empty input" do
      type = Z.tuple([])

      assert {:error, [issue]} = type |> Z.parse({"hello"})
      assert Exception.message(issue) == "expected a tuple with 0 elements, got 1"
    end
  end

  describe "element validation" do
    test "validates each element against its type" do
      type = Z.tuple([Z.string(), Z.int(), Z.boolean()])

      assert {:ok, {"hello", 42, true}} = type |> Z.parse({"hello", 42, true})
    end

    test "reports error for invalid element" do
      type = Z.tuple([Z.string(), Z.int()])

      assert {:error, [issue]} = type |> Z.parse({"hello", "not an int"})
      assert Exception.message(issue) == "expected type integer, got string"
      assert issue.path == [1]
    end

    test "reports errors for multiple invalid elements" do
      type = Z.tuple([Z.string(), Z.int(), Z.boolean()])

      {:error, issues} = type |> Z.parse({123, "not an int", "not a bool"})

      assert length(issues) == 3

      paths = Enum.map(issues, & &1.path)
      assert [0] in paths
      assert [1] in paths
      assert [2] in paths
    end

    test "validates with complex types" do
      type = Z.tuple([Z.int(min: 0), Z.string(min: 1)])

      assert {:ok, {42, "hello"}} = type |> Z.parse({42, "hello"})

      assert {:error, [issue]} = type |> Z.parse({-1, "hello"})
      assert Exception.message(issue) == "must be at least 0, got -1"
      assert issue.path == [0]

      assert {:error, [issue]} = type |> Z.parse({42, ""})
      assert Exception.message(issue) == "must be at least 1 characters long, got 0"
      assert issue.path == [1]
    end
  end

  describe "nested structures" do
    test "tuple of maps" do
      type =
        Z.tuple([
          Z.map(%{name: Z.string()}),
          Z.map(%{age: Z.int()})
        ])

      input = {%{name: "Alice"}, %{age: 30}}

      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "errors in nested maps have correct paths" do
      type =
        Z.tuple([
          Z.map(%{name: Z.string()}),
          Z.map(%{age: Z.int(min: 0)})
        ])

      {:error, [issue]} = type |> Z.parse({%{name: "Alice"}, %{age: -1}})

      assert issue.path == [1, :age]
      assert Exception.message(issue) == "must be at least 0, got -1"
    end

    test "tuple of lists" do
      type = Z.tuple([Z.int() |> Z.list(), Z.string() |> Z.list()])

      input = {[1, 2, 3], ["a", "b", "c"]}

      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "errors in nested lists have correct paths" do
      type = Z.tuple([Z.int() |> Z.list(), Z.string() |> Z.list()])

      {:error, [issue]} = type |> Z.parse({[1, 2, "invalid"], ["a", "b"]})

      assert issue.path == [0, 2]
    end

    test "tuple inside a map" do
      type = Z.map(%{point: Z.tuple([Z.int(), Z.int()])})

      assert {:ok, %{point: {10, 20}}} = type |> Z.parse(%{point: {10, 20}})
    end

    test "tuple inside a list" do
      type = Z.tuple([Z.int(), Z.int()]) |> Z.list()

      assert {:ok, [{1, 2}, {3, 4}]} = type |> Z.parse([{1, 2}, {3, 4}])
    end

    test "nested tuple" do
      type = Z.tuple([Z.string(), Z.tuple([Z.int(), Z.int()])])

      assert {:ok, {"point", {10, 20}}} = type |> Z.parse({"point", {10, 20}})
    end
  end

  describe "coercion" do
    test "coerces list to tuple" do
      type = Z.tuple([Z.string(), Z.int()])

      assert {:ok, {"hello", 42}} = type |> Z.parse(["hello", 42], coerce: true)
    end

    test "coerces elements" do
      type = Z.tuple([Z.int(), Z.boolean()])

      assert {:ok, {42, true}} = type |> Z.parse({"42", "true"}, coerce: true)
    end

    test "coerces both container and elements" do
      type = Z.tuple([Z.int(), Z.boolean()])

      assert {:ok, {42, true}} = type |> Z.parse(["42", "true"], coerce: true)
    end

    test "coercion with nested types" do
      type = Z.tuple([Z.map(%{value: Z.int()}), Z.string()])

      input = [%{"value" => "42"}, "hello"]

      assert {:ok, {%{value: 42}, "hello"}} = type |> Z.parse(input, coerce: true)
    end
  end

  describe "optional and default" do
    test "optional tuple accepts nil" do
      type = Z.tuple([Z.string(), Z.int()]) |> Z.optional()

      assert {:ok, nil} = type |> Z.parse(nil)
    end

    test "default value for tuple" do
      type = Z.tuple([Z.string(), Z.int()]) |> Z.default({"default", 0})

      assert {:ok, {"default", 0}} = type |> Z.parse(nil)
    end
  end

  describe "effects on tuple" do
    test "transform on tuple result" do
      type =
        Z.tuple([Z.string(), Z.int()])
        |> Z.transform(fn {name, age} -> %{name: name, age: age} end)

      assert {:ok, %{name: "Alice", age: 30}} = type |> Z.parse({"Alice", 30})
    end

    test "refine on tuple result" do
      type =
        Z.tuple([Z.int(), Z.int()])
        |> Z.refine(fn {a, b} -> a < b end, error: "first element must be less than second")

      assert {:ok, {1, 2}} = type |> Z.parse({1, 2})

      assert {:error, [issue]} = type |> Z.parse({2, 1})
      assert Exception.message(issue) == "first element must be less than second"
    end
  end

  describe "json schema" do
    test "generates correct schema for simple tuple" do
      schema =
        Z.tuple([Z.string(), Z.int()])
        |> Z.json_schema()

      assert schema == %{
               "type" => "array",
               "prefixItems" => [
                 %{"type" => "string"},
                 %{"type" => "integer"}
               ],
               "items" => false,
               "minItems" => 2,
               "maxItems" => 2
             }
    end

    test "includes description and example" do
      schema =
        Z.tuple([Z.string(), Z.int()])
        |> Z.describe("A name and age pair.")
        |> Z.example({"Alice", 30})
        |> Z.json_schema()

      assert schema["description"] == "A name and age pair."
      assert schema["examples"] == [["Alice", 30]]
    end

    test "generates schema for optional tuple" do
      schema =
        Z.tuple([Z.string(), Z.int()])
        |> Z.optional()
        |> Z.json_schema()

      assert schema["type"] == ["array", nil]
    end

    test "generates schema for empty tuple" do
      schema = Z.tuple([]) |> Z.json_schema()

      assert schema == %{
               "type" => "array",
               "prefixItems" => [],
               "items" => false,
               "minItems" => 0,
               "maxItems" => 0
             }
    end

    test "generates schema with nested types" do
      schema =
        Z.tuple([Z.string(), Z.int() |> Z.list()])
        |> Z.json_schema()

      assert schema["prefixItems"] == [
               %{"type" => "string"},
               %{"type" => "array", "items" => %{"type" => "integer"}}
             ]
    end
  end
end
