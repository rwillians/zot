defmodule Zot.Type.SlugRFC1123Test do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "format validation" do
    test "accepts a single alphanumeric character" do
      assert {:ok, "a"} = Z.slug_rfc1123() |> Z.parse("a")
      assert {:ok, "1"} = Z.slug_rfc1123() |> Z.parse("1")
    end

    test "accepts digits-only slugs" do
      assert {:ok, "123"} = Z.slug_rfc1123() |> Z.parse("123")
    end

    test "accepts internal consecutive hyphens" do
      assert {:ok, "xn--example"} = Z.slug_rfc1123() |> Z.parse("xn--example")
    end

    test "rejects leading hyphen" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("-abc")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "rejects trailing hyphen" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("abc-")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "rejects uppercase characters" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("Abc")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "rejects underscores" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("a_b")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "rejects spaces" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("a b")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "rejects non-string input" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse(42)
      assert Exception.message(issue) == "expected type string, got integer"
    end
  end

  describe "length validation" do
    test "rejects an empty string via the default min of 1" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse("")
      assert Exception.message(issue) == "must be at least 1 characters long, got 0"
    end

    test "accepts a 63-character slug" do
      slug = String.duplicate("a", 63)
      assert {:ok, ^slug} = Z.slug_rfc1123() |> Z.parse(slug)
    end

    test "rejects a 64-character slug via the default max of 63" do
      slug = String.duplicate("a", 64)
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse(slug)
      assert Exception.message(issue) == "must be at most 63 characters long, got 64"
    end

    test "accepts custom error messages on constraints" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.min(3, error: "too short") |> Z.parse("ab")
      assert Exception.message(issue) == "too short"
    end

    test "raises when min, max or length exceed the RFC limit of 63" do
      assert_raise FunctionClauseError, fn -> Z.slug_rfc1123(min: 64) end
      assert_raise FunctionClauseError, fn -> Z.slug_rfc1123(max: 64) end
      assert_raise FunctionClauseError, fn -> Z.slug_rfc1123(length: 64) end
    end
  end

  describe "trim" do
    test "defaults to false, so padded input fails format validation" do
      assert {:error, [issue]} = Z.slug_rfc1123() |> Z.parse(" abc ")
      assert Exception.message(issue) == "is not a valid RFC 1123 slug"
    end

    test "trims before validation when enabled" do
      assert {:ok, "abc"} = Z.slug_rfc1123(trim: true) |> Z.parse(" abc ")
    end
  end

  describe "json schema" do
    test "marks the type as nullable when optional" do
      schema = Z.slug_rfc1123() |> Z.optional() |> Z.json_schema()
      assert schema["type"] == ["string", nil]
    end
  end
end
