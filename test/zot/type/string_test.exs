defmodule Zot.Type.StringTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "edge cases" do
    test "accepts empty string" do
      assert {:ok, ""} = Z.string() |> Z.parse("")
    end

    test "rejects non-string types" do
      assert {:error, [issue]} = Z.string() |> Z.parse(123)
      assert Exception.message(issue) == "expected type string, got integer"

      assert {:error, [issue]} = Z.string() |> Z.parse(:atom)
      assert Exception.message(issue) == "expected type string, got atom"

      assert {:error, [issue]} = Z.string() |> Z.parse([])
      assert Exception.message(issue) == "expected type string, got list"

      assert {:error, [issue]} = Z.string() |> Z.parse(%{})
      assert Exception.message(issue) == "expected type string, got map"
    end

    test "handles unicode strings" do
      assert {:ok, "héllo wörld"} = Z.string() |> Z.parse("héllo wörld")
      assert {:ok, "你好世界"} = Z.string() |> Z.parse("你好世界")
      assert {:ok, "🎉🚀"} = Z.string() |> Z.parse("🎉🚀")
    end

    test "counts unicode characters correctly for length" do
      assert {:ok, "你好"} = Z.string(length: 2) |> Z.parse("你好")
      assert {:ok, "🎉🚀"} = Z.string(length: 2) |> Z.parse("🎉🚀")
    end
  end

  describe "length constraints" do
    test "min length at boundary" do
      assert {:ok, "abc"} = Z.string(min: 3) |> Z.parse("abc")
      assert {:error, _} = Z.string(min: 3) |> Z.parse("ab")
    end

    test "max length at boundary" do
      assert {:ok, "abc"} = Z.string(max: 3) |> Z.parse("abc")
      assert {:error, _} = Z.string(max: 3) |> Z.parse("abcd")
    end

    test "exact length" do
      assert {:ok, "abc"} = Z.string(length: 3) |> Z.parse("abc")
      assert {:error, _} = Z.string(length: 3) |> Z.parse("ab")
      assert {:error, _} = Z.string(length: 3) |> Z.parse("abcd")
    end

    test "min and max together" do
      type = Z.string(min: 2, max: 5)
      assert {:ok, "ab"} = type |> Z.parse("ab")
      assert {:ok, "abcde"} = type |> Z.parse("abcde")
      assert {:error, _} = type |> Z.parse("a")
      assert {:error, _} = type |> Z.parse("abcdef")
    end
  end

  describe "trim" do
    test "trims whitespace before validation" do
      assert {:ok, "hello"} = Z.string(trim: true) |> Z.parse("  hello  ")
    end

    test "trim affects length validation" do
      assert {:error, [issue]} = Z.string(trim: true, min: 5) |> Z.parse("  ab  ")
      assert Exception.message(issue) =~ "must be at least 5 characters long, got 2"
    end

    test "trim with empty result" do
      assert {:ok, ""} = Z.string(trim: true) |> Z.parse("   ")
    end
  end

  describe "regex validation" do
    test "accepts matching strings" do
      assert {:ok, "hello123"} = Z.string(regex: ~r/^[a-z]+\d+$/) |> Z.parse("hello123")
    end

    test "rejects non-matching strings" do
      assert {:error, [issue]} = Z.string(regex: ~r/^[a-z]+$/) |> Z.parse("hello123")
      assert Exception.message(issue) =~ "must match pattern /^[a-z]+$/"
    end

    test "regex with flags" do
      type = Z.string(regex: ~r/^hello$/i)
      assert {:ok, "HELLO"} = type |> Z.parse("HELLO")
      assert {:ok, "Hello"} = type |> Z.parse("Hello")
    end
  end

  describe "starts_with validation" do
    test "accepts strings starting with prefix" do
      assert {:ok, "hello world"} = Z.string(starts_with: "hello") |> Z.parse("hello world")
    end

    test "rejects strings not starting with prefix" do
      assert {:error, [issue]} = Z.string(starts_with: "hello") |> Z.parse("world hello")
      assert Exception.message(issue) == "must start with 'hello'"
    end
  end

  describe "ends_with validation" do
    test "accepts strings ending with suffix" do
      assert {:ok, "hello world"} = Z.string(ends_with: "world") |> Z.parse("hello world")
    end

    test "rejects strings not ending with suffix" do
      assert {:error, [issue]} = Z.string(ends_with: "world") |> Z.parse("world hello")
      assert Exception.message(issue) == "must end with 'world'"
    end
  end

  describe "contains validation" do
    test "accepts strings containing substring" do
      assert {:ok, "hello world"} = Z.string(contains: "lo wo") |> Z.parse("hello world")
    end

    test "rejects strings not containing substring" do
      assert {:error, [issue]} = Z.string(contains: "foo") |> Z.parse("hello world")
      assert Exception.message(issue) == "must contain 'foo'"
    end
  end

  describe "combined validations" do
    test "all validations together" do
      type =
        Z.string()
        |> Z.trim()
        |> Z.min(5)
        |> Z.max(20)
        |> Z.starts_with("hello")
        |> Z.ends_with("world")

      assert {:ok, "hello world"} = type |> Z.parse("  hello world  ")
    end

    test "fails on first validation error" do
      type = Z.string(min: 10, starts_with: "foo")
      assert {:error, [issue]} = type |> Z.parse("bar")
      assert Exception.message(issue) =~ "must be at least 10 characters long"
    end
  end
end
