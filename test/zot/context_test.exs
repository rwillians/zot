defmodule Zot.ContextTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z
  alias Zot.Context
  alias Zot.Issue

  describe "new/3" do
    test "creates context with type, input, and default options" do
      type = Z.string()
      ctx = Context.new(type, "hello")

      assert ctx.type == type
      assert ctx.input == "hello"
      assert ctx.output == "hello"
      assert ctx.path == []
      assert ctx.issues == []
      assert ctx.score == 0
      assert ctx.opts == []
      assert ctx.valid? == true
    end

    test "creates context with custom options" do
      type = Z.int()
      ctx = Context.new(type, "42", coerce: true)

      assert ctx.opts == [coerce: true]
    end
  end

  describe "put_path/2" do
    test "sets the path on the context" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.put_path(ctx, [:user, :name])

      assert ctx.path == [:user, :name]
    end

    test "replaces existing path" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.put_path(ctx, [:old, :path])
      ctx = Context.put_path(ctx, [:new, :path])

      assert ctx.path == [:new, :path]
    end
  end

  describe "append_issues/2" do
    test "appends issues and marks context invalid" do
      ctx = Context.new(Z.string(), 123)
      issue = Issue.issue("test error")
      ctx = Context.append_issues(ctx, [issue])

      assert ctx.issues == [issue]
      assert ctx.valid? == false
    end

    test "appends multiple issues" do
      ctx = Context.new(Z.string(), 123)
      issue1 = Issue.issue("error 1")
      issue2 = Issue.issue("error 2")

      ctx = Context.append_issues(ctx, [issue1])
      ctx = Context.append_issues(ctx, [issue2])

      assert ctx.issues == [issue1, issue2]
    end

    test "does nothing when appending empty list" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.append_issues(ctx, [])

      assert ctx.issues == []
      assert ctx.valid? == true
    end
  end

  describe "inc_score/2" do
    test "increments score by 1 by default" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.inc_score(ctx)

      assert ctx.score == 1
    end

    test "increments score by specified amount" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.inc_score(ctx, 5)

      assert ctx.score == 5
    end

    test "does nothing when incrementing by 0" do
      ctx = Context.new(Z.string(), "hello")
      ctx = Context.inc_score(ctx, 0)

      assert ctx.score == 0
    end
  end

  describe "valid?/1" do
    test "returns true for valid context" do
      ctx = Context.new(Z.string(), "hello")

      assert Context.valid?(ctx) == true
    end

    test "returns false for invalid context" do
      ctx = Context.new(Z.string(), 123)
      ctx = Context.append_issues(ctx, [Issue.issue("error")])

      assert Context.valid?(ctx) == false
    end
  end

  describe "unwrap/1" do
    test "returns {:ok, output} for valid context" do
      ctx = Context.new(Z.string(), "hello")

      assert Context.unwrap(ctx) == {:ok, "hello"}
    end

    test "returns {:error, issues} for invalid context" do
      ctx = Context.new(Z.string(), 123)
      issue = Issue.issue("error")
      ctx = Context.append_issues(ctx, [issue])

      assert Context.unwrap(ctx) == {:error, [issue]}
    end
  end

  describe "parse/1" do
    test "handles nil input when type is required" do
      ctx = Context.new(Z.string(), nil)
      ctx = Context.parse(ctx)

      assert ctx.valid? == false
      assert [issue] = ctx.issues
      assert Exception.message(issue) == "is required"
    end

    test "handles nil input when type is optional" do
      ctx = Context.new(Z.string() |> Z.optional(), nil)
      ctx = Context.parse(ctx)

      assert ctx.valid? == true
      assert ctx.output == nil
    end

    test "uses default value when input is nil" do
      ctx = Context.new(Z.string() |> Z.default("default"), nil)
      ctx = Context.parse(ctx)

      assert ctx.valid? == true
      assert ctx.output == "default"
    end

    test "uses lazy default value when input is nil" do
      ctx = Context.new(Z.string() |> Z.default(fn -> "lazy" end), nil)
      ctx = Context.parse(ctx)

      assert ctx.valid? == true
      assert ctx.output == "lazy"
    end

    test "applies coercion when option is set" do
      ctx = Context.new(Z.int(), "42", coerce: true)
      ctx = Context.parse(ctx)

      assert ctx.valid? == true
      assert ctx.output == 42
    end
  end
end
