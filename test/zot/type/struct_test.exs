defmodule Zot.Type.StructTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "allow_recase" do
    test "recases camelCase, PascalCase and kebab-case keys to snake_case" do
      type =
        Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})
        |> Z.allow_recase()

      assert {:ok, %ZotTest.StructProfile{first_name: "Alice", last_name: "Liddell"}} =
               type |> Z.parse(%{"firstName" => "Alice", "LastName" => "Liddell"})

      assert {:ok, %ZotTest.StructProfile{first_name: "Alice", last_name: "Liddell"}} =
               type |> Z.parse(%{"first-name" => "Alice", "last-name" => "Liddell"})
    end

    test "is disabled by default" do
      type = Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})

      assert {:error, issues} = type |> Z.parse(%{"firstName" => "Alice", "lastName" => "Liddell"})
      assert [:first_name] in Enum.map(issues, & &1.path)
    end

    test "can be explicitly disabled" do
      type =
        Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})
        |> Z.allow_recase(false)

      assert {:error, _issues} = type |> Z.parse(%{"firstName" => "Alice", "lastName" => "Liddell"})
    end

    test "recases before unknown fields are checked" do
      type =
        Z.struct(ZotTest.StructProfile, %{first_name: Z.string(), last_name: Z.string()})
        |> Z.allow_recase()

      assert {:error, [issue]} =
               type
               |> Z.parse(%{"firstName" => "Alice", "lastName" => "Liddell", "homeAddress" => "Wonderland"})

      assert issue.path == ["home_address"]
      assert Exception.message(issue) == "unknown field"
    end

    test "is preserved when converting a map type into a struct type" do
      type =
        Z.map(%{first_name: Z.string(), last_name: Z.string()})
        |> Z.allow_recase()
        |> Z.struct(ZotTest.StructProfile)

      assert {:ok, %ZotTest.StructProfile{first_name: "Alice", last_name: "Liddell"}} =
               type |> Z.parse(%{"firstName" => "Alice", "lastName" => "Liddell"})
    end
  end
end
