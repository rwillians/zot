defmodule Zot.Type.IntegerTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "edge cases" do
    test "accepts zero" do
      assert {:ok, 0} = Z.int() |> Z.parse(0)
    end

    test "accepts negative integers" do
      assert {:ok, -42} = Z.int() |> Z.parse(-42)
    end

    test "accepts very large integers" do
      large = 999_999_999_999_999_999_999
      assert {:ok, ^large} = Z.int() |> Z.parse(large)
    end

    test "rejects floats" do
      assert {:error, [issue]} = Z.int() |> Z.parse(3.14)
      assert Exception.message(issue) == "expected type integer, got float"
    end

    test "rejects strings" do
      assert {:error, [issue]} = Z.int() |> Z.parse("42")
      assert Exception.message(issue) == "expected type integer, got string"
    end
  end

  describe "boundary conditions for min" do
    test "accepts value equal to min" do
      assert {:ok, 10} = Z.int(min: 10) |> Z.parse(10)
    end

    test "accepts value greater than min" do
      assert {:ok, 11} = Z.int(min: 10) |> Z.parse(11)
    end

    test "rejects value less than min" do
      assert {:error, [issue]} = Z.int(min: 10) |> Z.parse(9)
      assert Exception.message(issue) == "must be at least 10, got 9"
    end

    test "min with zero" do
      assert {:ok, 0} = Z.int(min: 0) |> Z.parse(0)
      assert {:error, _} = Z.int(min: 0) |> Z.parse(-1)
    end

    test "min with negative value" do
      assert {:ok, -5} = Z.int(min: -10) |> Z.parse(-5)
      assert {:error, _} = Z.int(min: -10) |> Z.parse(-11)
    end
  end

  describe "boundary conditions for max" do
    test "accepts value equal to max" do
      assert {:ok, 100} = Z.int(max: 100) |> Z.parse(100)
    end

    test "accepts value less than max" do
      assert {:ok, 99} = Z.int(max: 100) |> Z.parse(99)
    end

    test "rejects value greater than max" do
      assert {:error, [issue]} = Z.int(max: 100) |> Z.parse(101)
      assert Exception.message(issue) == "must be at most 100, got 101"
    end

    test "max with zero" do
      assert {:ok, 0} = Z.int(max: 0) |> Z.parse(0)
      assert {:error, _} = Z.int(max: 0) |> Z.parse(1)
    end

    test "max with negative value" do
      assert {:ok, -15} = Z.int(max: -10) |> Z.parse(-15)
      assert {:error, _} = Z.int(max: -10) |> Z.parse(-9)
    end
  end

  describe "min and max together" do
    test "accepts value within range" do
      type = Z.int(min: 1, max: 10)
      assert {:ok, 1} = type |> Z.parse(1)
      assert {:ok, 5} = type |> Z.parse(5)
      assert {:ok, 10} = type |> Z.parse(10)
    end

    test "rejects value outside range" do
      type = Z.int(min: 1, max: 10)
      assert {:error, _} = type |> Z.parse(0)
      assert {:error, _} = type |> Z.parse(11)
    end
  end

  describe "coercion" do
    test "coerces from float by rounding" do
      assert {:ok, 3} = Z.int() |> Z.parse(3.14, coerce: true)
      assert {:ok, 4} = Z.int() |> Z.parse(3.5, coerce: true)
      assert {:ok, 4} = Z.int() |> Z.parse(3.6, coerce: true)
    end

    test "coerces from string" do
      assert {:ok, 42} = Z.int() |> Z.parse("42", coerce: true)
      assert {:ok, -42} = Z.int() |> Z.parse("-42", coerce: true)
      assert {:ok, 0} = Z.int() |> Z.parse("0", coerce: true)
    end

    test "coercion failure for non-numeric string" do
      assert {:error, [issue]} = Z.int() |> Z.parse("not a number", coerce: true)
      assert Exception.message(issue) =~ "coerced"
    end

    test "coerces from Decimal" do
      assert {:ok, 42} = Z.int() |> Z.parse(Decimal.new("42"), coerce: true)
      assert {:ok, 3} = Z.int() |> Z.parse(Decimal.new("3.14"), coerce: true)
    end

    test "coercion applies min/max validation after" do
      assert {:error, [issue]} = Z.int(min: 10) |> Z.parse("5", coerce: true)
      assert Exception.message(issue) == "must be at least 10, got 5"
    end
  end

  describe "optional and default" do
    test "optional integer accepts nil" do
      assert {:ok, nil} = Z.int() |> Z.optional() |> Z.parse(nil)
    end

    test "default value is used when nil" do
      assert {:ok, 42} = Z.int() |> Z.default(42) |> Z.parse(nil)
    end

    test "default value can be a function" do
      assert {:ok, 100} = Z.int() |> Z.default(fn -> 50 + 50 end) |> Z.parse(nil)
    end

    test "provided value overrides default" do
      assert {:ok, 10} = Z.int() |> Z.default(42) |> Z.parse(10)
    end
  end
end
