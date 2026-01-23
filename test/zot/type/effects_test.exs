defmodule Zot.Type.EffectsTest.RefineHelper do
  def positive?(%Zot.Context{output: n}), do: n > 0
end

defmodule Zot.Type.EffectsTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z
  alias Zot.Context

  describe "transform effects" do
    test "applies single transform" do
      type = Z.string() |> Z.transform(&String.upcase/1)

      assert {:ok, "HELLO"} = type |> Z.parse("hello")
    end

    test "chains multiple transforms" do
      type =
        Z.string()
        |> Z.transform(&String.upcase/1)
        |> Z.transform(&String.reverse/1)

      assert {:ok, "OLLEH"} = type |> Z.parse("hello")
    end

    test "transform with MFA tuple" do
      type = Z.string() |> Z.transform({String, :upcase, []})

      assert {:ok, "HELLO"} = type |> Z.parse("hello")
    end

    test "transform can change type" do
      type = Z.string() |> Z.transform(&String.length/1)

      assert {:ok, 5} = type |> Z.parse("hello")
    end

    test "transform receives parsed value" do
      type =
        Z.int()
        |> Z.transform(fn n -> n * 2 end)

      assert {:ok, 84} = type |> Z.parse(42)
    end

    test "transform runs after validation" do
      type =
        Z.int(min: 10)
        |> Z.transform(fn n -> n * 2 end)

      assert {:error, _} = type |> Z.parse(5)
      assert {:ok, 20} = type |> Z.parse(10)
    end
  end

  describe "refine effects" do
    test "refine returning true passes" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 0 end)

      assert {:ok, 42} = type |> Z.parse(42)
    end

    test "refine returning false fails with default message" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 100 end)

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "is invalid"
    end

    test "refine with custom error message" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 100 end, error: "must be greater than 100")

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "must be greater than 100"
    end

    test "refine error message with actual value interpolation" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 100 end, error: "must be greater than 100, got %{actual}")

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "must be greater than 100, got 42"
    end

    test "refine returning :ok passes" do
      type =
        Z.int()
        |> Z.refine(fn _ -> :ok end)

      assert {:ok, 42} = type |> Z.parse(42)
    end

    test "refine returning :error fails with default message" do
      type =
        Z.int()
        |> Z.refine(fn _ -> :error end)

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "is invalid"
    end

    test "refine returning {:error, message} fails with custom message" do
      type =
        Z.int()
        |> Z.refine(fn n -> {:error, "#{n} is not allowed"} end)

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "42 is not allowed"
    end

    test "refine returning {:error, exception} uses exception message" do
      type =
        Z.int()
        |> Z.refine(fn _ -> {:error, %ArgumentError{message: "custom exception"}} end)

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "custom exception"
    end

    test "refine with 2-arity function receives context" do
      type =
        Z.int()
        |> Z.refine(fn value, ctx ->
          assert %Context{} = ctx
          assert ctx.output == value
          value > 0
        end)

      assert {:ok, 42} = type |> Z.parse(42)
    end

    test "refine returning Context passes when valid" do
      type =
        Z.int()
        |> Z.refine(fn _, ctx -> ctx end)

      assert {:ok, 42} = type |> Z.parse(42)
    end

    test "refine returning invalid Context fails" do
      type =
        Z.int()
        |> Z.refine(fn _, ctx ->
          Context.append_issues(ctx, [Zot.Issue.issue("custom error")])
        end)

      assert {:error, [issue]} = type |> Z.parse(42)
      assert Exception.message(issue) == "custom error"
    end

    test "refine with MFA tuple" do
      type =
        Z.int()
        |> Z.refine({Zot.Type.EffectsTest.RefineHelper, :positive?, []})

      assert {:ok, 42} = type |> Z.parse(42)
      assert {:error, _} = type |> Z.parse(-1)
    end

    test "multiple refines chain" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 0 end, error: "must be positive")
        |> Z.refine(fn n -> rem(n, 2) == 0 end, error: "must be even")

      assert {:ok, 42} = type |> Z.parse(42)
      assert {:error, [issue]} = type |> Z.parse(-2)
      assert Exception.message(issue) == "must be positive"
      assert {:error, [issue]} = type |> Z.parse(41)
      assert Exception.message(issue) == "must be even"
    end
  end

  describe "mixed transform and refine" do
    test "transform then refine" do
      type =
        Z.string()
        |> Z.transform(&String.length/1)
        |> Z.refine(fn len -> len >= 5 end, error: "must be at least 5 characters")

      assert {:ok, 5} = type |> Z.parse("hello")
      assert {:error, [issue]} = type |> Z.parse("hi")
      assert Exception.message(issue) == "must be at least 5 characters"
    end

    test "refine then transform" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 0 end, error: "must be positive")
        |> Z.transform(fn n -> n * 2 end)

      assert {:ok, 84} = type |> Z.parse(42)
      assert {:error, [issue]} = type |> Z.parse(-1)
      assert Exception.message(issue) == "must be positive"
    end

    test "complex pipeline: transform -> refine -> transform -> refine" do
      type =
        Z.string()
        |> Z.transform(&String.trim/1)
        |> Z.refine(fn s -> String.length(s) > 0 end, error: "must not be empty")
        |> Z.transform(&String.upcase/1)
        |> Z.refine(fn s -> String.starts_with?(s, "A") end, error: "must start with A")

      assert {:ok, "ALICE"} = type |> Z.parse("  alice  ")
      assert {:error, [issue]} = type |> Z.parse("   ")
      assert Exception.message(issue) == "must not be empty"
      assert {:error, [issue]} = type |> Z.parse("bob")
      assert Exception.message(issue) == "must start with A"
    end
  end

  describe "effects on nested types" do
    test "transform on map field" do
      type =
        Z.map(%{
          name: Z.string() |> Z.transform(&String.upcase/1)
        })

      assert {:ok, %{name: "ALICE"}} = type |> Z.parse(%{name: "alice"})
    end

    test "refine on map field" do
      type =
        Z.map(%{
          age: Z.int() |> Z.refine(fn n -> n >= 18 end, error: "must be adult")
        })

      assert {:error, [issue]} = type |> Z.parse(%{age: 16})
      assert issue.path == [:age]
      assert Exception.message(issue) == "must be adult"
    end

    test "transform on list items" do
      type =
        Z.string()
        |> Z.transform(&String.upcase/1)
        |> Z.list()

      assert {:ok, ["HELLO", "WORLD"]} = type |> Z.parse(["hello", "world"])
    end

    test "refine on list items" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 0 end, error: "must be positive")
        |> Z.list()

      {:error, issues} = type |> Z.parse([1, -2, 3, -4])

      assert length(issues) == 2

      paths = Enum.map(issues, & &1.path)
      assert [1] in paths
      assert [3] in paths
    end
  end

  describe "effects with coercion" do
    test "transform runs after coercion" do
      type =
        Z.int()
        |> Z.transform(fn n -> n * 2 end)

      assert {:ok, 84} = type |> Z.parse("42", coerce: true)
    end

    test "refine runs after coercion" do
      type =
        Z.int()
        |> Z.refine(fn n -> n > 40 end, error: "must be > 40")

      assert {:ok, 42} = type |> Z.parse("42", coerce: true)
      assert {:error, [issue]} = type |> Z.parse("30", coerce: true)
      assert Exception.message(issue) == "must be > 40"
    end
  end

  describe "effects on branded types" do
    test "transform on inner type before branding" do
      type =
        Z.string()
        |> Z.transform(&String.upcase/1)
        |> Z.branded(:name)

      assert {:ok, {:name, "ALICE"}} = type |> Z.parse("alice")
    end
  end
end
