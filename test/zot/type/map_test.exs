defmodule Zot.Type.MapTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "edge cases" do
    test "accepts empty map when no required fields" do
      type = Z.map(%{})
      assert {:ok, %{}} = type |> Z.parse(%{})
    end

    test "rejects non-map types" do
      type = Z.map(%{name: Z.string()})

      assert {:error, [issue]} = type |> Z.parse("not a map")
      assert Exception.message(issue) == "expected type map, got string"

      assert {:error, [issue]} = type |> Z.parse([])
      assert Exception.message(issue) == "expected type map, got list"

      assert {:error, [issue]} = type |> Z.parse(123)
      assert Exception.message(issue) == "expected type map, got integer"
    end

    test "accepts both atom and string keys" do
      type = Z.map(%{name: Z.string()})
      assert {:ok, %{name: "Alice"}} = type |> Z.parse(%{name: "Alice"})
      assert {:ok, %{name: "Alice"}} = type |> Z.parse(%{"name" => "Alice"})
    end
  end

  describe "strip mode (default)" do
    test "strips unknown fields" do
      type = Z.map(%{name: Z.string()})
      assert {:ok, %{name: "Alice"}} = type |> Z.parse(%{name: "Alice", extra: "field"})
    end

    test "strips multiple unknown fields" do
      type = Z.map(%{name: Z.string()})

      result =
        type
        |> Z.parse(%{name: "Alice", extra1: "a", extra2: "b", extra3: "c"})

      assert {:ok, %{name: "Alice"}} = result
    end
  end

  describe "strict mode" do
    test "rejects unknown fields" do
      type = Z.strict_map(%{name: Z.string()})

      assert {:error, [issue]} = type |> Z.parse(%{name: "Alice", extra: "field"})
      assert issue.path == ["extra"]
      assert Exception.message(issue) == "unknown field"
    end

    test "rejects multiple unknown fields" do
      type = Z.strict_map(%{name: Z.string()})

      {:error, issues} = type |> Z.parse(%{name: "Alice", extra1: "a", extra2: "b"})

      assert length(issues) == 2
      paths = Enum.map(issues, & &1.path)
      assert ["extra1"] in paths
      assert ["extra2"] in paths
    end
  end

  describe "multiple validation errors" do
    test "collects errors from multiple fields" do
      type =
        Z.map(%{
          name: Z.string(),
          age: Z.int(min: 18),
          email: Z.email()
        })

      {:error, issues} =
        type
        |> Z.parse(%{name: 123, age: 16, email: "invalid"})

      assert length(issues) == 3

      paths = Enum.map(issues, & &1.path)
      assert [:name] in paths
      assert [:age] in paths
      assert [:email] in paths
    end

    test "includes path in error messages" do
      type = Z.map(%{user: Z.map(%{email: Z.email()})})

      {:error, [issue]} = type |> Z.parse(%{user: %{email: "invalid"}})

      assert issue.path == [:user, :email]
    end
  end

  describe "nested maps" do
    test "validates deeply nested structures" do
      type =
        Z.map(%{
          level1: Z.map(%{
            level2: Z.map(%{
              level3: Z.string()
            })
          })
        })

      input = %{level1: %{level2: %{level3: "deep"}}}
      assert {:ok, ^input} = type |> Z.parse(input)
    end

    test "reports errors at correct nested path" do
      type =
        Z.map(%{
          level1: Z.map(%{
            level2: Z.map(%{
              value: Z.int()
            })
          })
        })

      {:error, [issue]} =
        type
        |> Z.parse(%{level1: %{level2: %{value: "not int"}}})

      assert issue.path == [:level1, :level2, :value]
    end

    test "multiple errors in nested structure" do
      type =
        Z.map(%{
          user: Z.map(%{
            name: Z.string(min: 1),
            age: Z.int(min: 0)
          }),
          settings: Z.map(%{
            theme: Z.enum([:light, :dark])
          })
        })

      {:error, issues} =
        type
        |> Z.parse(%{
          user: %{name: "", age: -1},
          settings: %{theme: :invalid}
        })

      assert length(issues) == 3

      paths = Enum.map(issues, & &1.path)
      assert [:user, :name] in paths
      assert [:user, :age] in paths
      assert [:settings, :theme] in paths
    end
  end

  describe "optional fields" do
    test "optional field can be nil" do
      type = Z.map(%{name: Z.string(), age: Z.int() |> Z.optional()})

      assert {:ok, %{name: "Alice", age: nil}} = type |> Z.parse(%{name: "Alice"})
    end

    test "optional field can be omitted from input" do
      type = Z.map(%{name: Z.string(), age: Z.int() |> Z.optional()})

      assert {:ok, %{name: "Alice", age: nil}} = type |> Z.parse(%{name: "Alice"})
    end

    test "optional field with default value" do
      type = Z.map(%{name: Z.string(), role: Z.string() |> Z.default("user")})

      assert {:ok, %{name: "Alice", role: "user"}} = type |> Z.parse(%{name: "Alice"})
    end
  end

  describe "coercion" do
    test "coerces nested values" do
      type =
        Z.map(%{
          name: Z.string(),
          age: Z.int(),
          active: Z.boolean()
        })

      input = %{name: "Alice", age: "30", active: "true"}

      assert {:ok, %{name: "Alice", age: 30, active: true}} = type |> Z.parse(input, coerce: true)
    end

    test "coerces deeply nested values" do
      type =
        Z.map(%{
          user: Z.map(%{
            score: Z.float()
          })
        })

      input = %{user: %{score: "3.14"}}

      assert {:ok, %{user: %{score: 3.14}}} = type |> Z.parse(input, coerce: true)
    end
  end

  describe "partial" do
    test "makes all fields optional" do
      type = Z.map(%{name: Z.string(), age: Z.int()}) |> Z.partial()

      assert {:ok, %{name: nil, age: nil}} = type |> Z.parse(%{})
      assert {:ok, %{name: "Alice", age: nil}} = type |> Z.parse(%{name: "Alice"})
    end

    test "partial with compact drops nil fields" do
      type = Z.map(%{name: Z.string(), age: Z.int()}) |> Z.partial(compact: true)

      assert {:ok, %{}} = type |> Z.parse(%{})
      assert {:ok, %{name: "Alice"}} = type |> Z.parse(%{name: "Alice"})
    end
  end

  describe "merge" do
    test "merges two map types" do
      map1 = Z.map(%{name: Z.string()})
      map2 = Z.map(%{age: Z.int()})
      merged = Z.merge(map1, map2)

      assert {:ok, %{name: "Alice", age: 30}} = merged |> Z.parse(%{name: "Alice", age: 30})
    end

    test "second map overrides conflicting fields" do
      map1 = Z.map(%{value: Z.string()})
      map2 = Z.map(%{value: Z.int()})
      merged = Z.merge(map1, map2)

      assert {:ok, %{value: 42}} = merged |> Z.parse(%{value: 42})
      assert {:error, _} = merged |> Z.parse(%{value: "string"})
    end

    test "strict mode is preserved when either is strict" do
      strict = Z.strict_map(%{a: Z.string()})
      strip = Z.map(%{b: Z.int()})
      merged = Z.merge(strict, strip)

      assert {:error, [issue]} = merged |> Z.parse(%{a: "x", b: 1, c: "extra"})
      assert issue.path == ["c"]
    end
  end

  describe "pick" do
    test "picks specified fields" do
      type =
        Z.strict_map(%{id: Z.uuid(), name: Z.string(), email: Z.email()})
        |> Z.pick([:id, :name])

      assert {:ok, %{id: id, name: "Alice"}} =
               type |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"})

      assert id == "550e8400-e29b-41d4-a716-446655440000"
    end
  end

  describe "omit" do
    test "omits specified fields" do
      type =
        Z.strict_map(%{id: Z.uuid(), name: Z.string(), password: Z.string()})
        |> Z.omit([:password])

      assert {:ok, %{id: _, name: "Alice"}} =
               type |> Z.parse(%{id: "550e8400-e29b-41d4-a716-446655440000", name: "Alice"})
    end
  end
end
