defmodule Zot.IssueTest do
  use ExUnit.Case, async: true

  alias Zot.Issue

  describe "issue/1" do
    test "creates issue with template only" do
      issue = Issue.issue("something went wrong")

      assert issue.path == []
      assert issue.template == "something went wrong"
      assert issue.params == []
    end
  end

  describe "issue/2 with template and params" do
    test "creates issue with template and params" do
      issue = Issue.issue("expected %{expected}, got %{actual}", expected: "string", actual: 42)

      assert issue.path == []
      assert issue.template == "expected %{expected}, got %{actual}"
      assert issue.params == [expected: "string", actual: 42]
    end
  end

  describe "issue/2 with path and template" do
    test "creates issue with path and template" do
      issue = Issue.issue([:user, :email], "is invalid")

      assert issue.path == [:user, :email]
      assert issue.template == "is invalid"
      assert issue.params == []
    end
  end

  describe "issue/3" do
    test "creates issue with path, template, and params" do
      issue = Issue.issue([:age], "must be at least %{min}", min: 18)

      assert issue.path == [:age]
      assert issue.template == "must be at least %{min}"
      assert issue.params == [min: 18]
    end
  end

  describe "message/1" do
    test "returns template when no params" do
      issue = Issue.issue("is required")

      assert Exception.message(issue) == "is required"
    end

    test "interpolates params into template" do
      issue = Issue.issue("must be at least %{min}, got %{actual}", min: 18, actual: 16)

      assert Exception.message(issue) == "must be at least 18, got 16"
    end

    test "renders nil as 'null'" do
      issue = Issue.issue("got %{value}", value: nil)

      assert Exception.message(issue) == "got null"
    end

    test "renders true as 'true'" do
      issue = Issue.issue("got %{value}", value: true)

      assert Exception.message(issue) == "got true"
    end

    test "renders false as 'false'" do
      issue = Issue.issue("got %{value}", value: false)

      assert Exception.message(issue) == "got false"
    end

    test "renders strings with quotes" do
      issue = Issue.issue("got %{value}", value: "hello")

      assert Exception.message(issue) == "got 'hello'"
    end

    test "renders atoms with inspect" do
      issue = Issue.issue("got %{value}", value: :foo)

      assert Exception.message(issue) == "got :foo"
    end

    test "renders DateTime in ISO8601" do
      dt = ~U[2024-01-15 10:30:00Z]
      issue = Issue.issue("timestamp: %{value}", value: dt)

      assert Exception.message(issue) == "timestamp: 2024-01-15T10:30:00Z"
    end

    test "renders Regex with slashes" do
      regex = ~r/^hello/
      issue = Issue.issue("pattern: %{value}", value: regex)

      assert Exception.message(issue) == "pattern: /^hello/"
    end

    test "renders escaped values without quotes" do
      issue = Issue.issue("got %{value}", value: {:escaped, "raw text"})

      assert Exception.message(issue) == "got raw text"
    end

    test "renders conjunction with 'and'" do
      issue = Issue.issue("must be %{values}", values: {:conjunction, [:a, :b]})

      assert Exception.message(issue) == "must be :a and :b"
    end

    test "renders conjunction with more than two items" do
      issue = Issue.issue("must be %{values}", values: {:conjunction, [:a, :b, :c]})

      assert Exception.message(issue) == "must be :a, :b and :c"
    end

    test "renders disjunction with 'or'" do
      issue = Issue.issue("must be %{values}", values: {:disjunction, [:a, :b]})

      assert Exception.message(issue) == "must be :a or :b"
    end

    test "renders disjunction with more than two items" do
      issue = Issue.issue("must be %{values}", values: {:disjunction, [:a, :b, :c]})

      assert Exception.message(issue) == "must be :a, :b or :c"
    end

    test "renders single-item conjunction/disjunction without connector" do
      issue1 = Issue.issue("must be %{values}", values: {:conjunction, [:only]})
      issue2 = Issue.issue("must be %{values}", values: {:disjunction, [:only]})

      assert Exception.message(issue1) == "must be :only"
      assert Exception.message(issue2) == "must be :only"
    end
  end

  describe "prepend_path/2 for single issue" do
    test "prepends segments to empty path" do
      issue = Issue.issue("error")
      issue = Issue.prepend_path(issue, [:user])

      assert issue.path == [:user]
    end

    test "prepends segments to existing path" do
      issue = Issue.issue([:email], "is invalid")
      issue = Issue.prepend_path(issue, [:user])

      assert issue.path == [:user, :email]
    end

    test "does nothing when prepending empty list" do
      issue = Issue.issue([:field], "error")
      issue = Issue.prepend_path(issue, [])

      assert issue.path == [:field]
    end

    test "prepends multiple segments" do
      issue = Issue.issue([:email], "is invalid")
      issue = Issue.prepend_path(issue, [:data, :user])

      assert issue.path == [:data, :user, :email]
    end
  end

  describe "prepend_path/2 for list of issues" do
    test "prepends segments to all issues in list" do
      issues = [
        Issue.issue([:name], "is required"),
        Issue.issue([:age], "must be a number")
      ]

      issues = Issue.prepend_path(issues, [:user])

      assert Enum.map(issues, & &1.path) == [[:user, :name], [:user, :age]]
    end
  end

  describe "summarize/1" do
    test "groups issues by path" do
      issues = [
        Issue.issue([:user, :name], "is required"),
        Issue.issue([:user, :email], "is invalid"),
        Issue.issue([:user, :email], "must contain @")
      ]

      summary = Issue.summarize(issues)

      assert summary == %{
               [:user, :name] => ["is required"],
               [:user, :email] => ["is invalid", "must contain @"]
             }
    end
  end

  describe "pretty_print/1" do
    test "formats issues with paths and messages" do
      issues = [
        Issue.issue([:user, :name], "is required"),
        Issue.issue([:user, :email], "is invalid")
      ]

      output = Issue.pretty_print(issues)

      assert output =~ "One or more fields failed validation:"
      assert output =~ "user.name"
      assert output =~ "is required"
      assert output =~ "user.email"
      assert output =~ "is invalid"
    end

    test "joins multiple messages for same path" do
      issues = [
        Issue.issue([:email], "is invalid"),
        Issue.issue([:email], "must contain @")
      ]

      output = Issue.pretty_print(issues)

      assert output =~ "is invalid, must contain @"
    end
  end
end
