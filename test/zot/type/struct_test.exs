defmodule Zot.Type.StructTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "recase option" do
    test "recases camelCase, PascalCase and kebab-case keys to snake_case" do
      type = Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})

      assert {:ok, %ZotTest.StructProfile{first_name: "Alice", last_name: "Liddell"}} =
               type |> Z.parse(%{"firstName" => "Alice", "LastName" => "Liddell"}, recase: true)

      assert {:ok, %ZotTest.StructProfile{first_name: "Alice", last_name: "Liddell"}} =
               type |> Z.parse(%{"first-name" => "Alice", "last-name" => "Liddell"}, recase: true)
    end

    test "is disabled by default" do
      type = Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})

      assert {:error, issues} = type |> Z.parse(%{"firstName" => "Alice", "lastName" => "Liddell"})
      assert [:first_name] in Enum.map(issues, & &1.path)
    end

    test "recases before unknown fields are checked" do
      type = Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})

      input = %{"firstName" => "Alice", "lastName" => "Liddell", "homeAddress" => "Wonderland"}

      assert {:error, [issue]} = type |> Z.parse(input, recase: true)
      assert issue.path == ["home_address"]
      assert Exception.message(issue) == "unknown field"
    end
  end
end
