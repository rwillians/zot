defmodule Zot.Type.HostnameTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "format validation" do
    test "accepts a single label" do
      assert {:ok, "localhost"} = Z.hostname() |> Z.parse("localhost")
      assert {:ok, "a"} = Z.hostname() |> Z.parse("a")
    end

    test "accepts multi-label hostnames" do
      assert {:ok, "example.com"} = Z.hostname() |> Z.parse("example.com")
      assert {:ok, "api.staging.example.com"} = Z.hostname() |> Z.parse("api.staging.example.com")
    end

    test "accepts digits and internal hyphens" do
      assert {:ok, "0.pool.ntp.org"} = Z.hostname() |> Z.parse("0.pool.ntp.org")
      assert {:ok, "xn--bcher-kva.example"} = Z.hostname() |> Z.parse("xn--bcher-kva.example")
    end

    test "accepts uppercase characters" do
      assert {:ok, "Example.COM"} = Z.hostname() |> Z.parse("Example.COM")
    end

    test "accepts a 63-character label and a 253-character hostname" do
      label = String.duplicate("a", 63)
      hostname = Enum.join([label, label, label, String.duplicate("a", 61)], ".")

      assert String.length(hostname) == 253
      assert {:ok, ^label} = Z.hostname() |> Z.parse(label)
      assert {:ok, ^hostname} = Z.hostname() |> Z.parse(hostname)
    end

    test "rejects a 64-character label" do
      label = String.duplicate("a", 64)
      assert {:error, [issue]} = Z.hostname() |> Z.parse(label)
      assert Exception.message(issue) == "is not a valid hostname"
    end

    test "rejects a 254-character hostname" do
      label = String.duplicate("a", 63)
      hostname = Enum.join([label, label, label, String.duplicate("a", 62)], ".")

      assert String.length(hostname) == 254
      assert {:error, [issue]} = Z.hostname() |> Z.parse(hostname)
      assert Exception.message(issue) == "is not a valid hostname"
    end

    test "rejects labels with leading or trailing hyphens" do
      assert {:error, [issue]} = Z.hostname() |> Z.parse("-example.com")
      assert Exception.message(issue) == "is not a valid hostname"

      assert {:error, [issue]} = Z.hostname() |> Z.parse("example-.com")
      assert Exception.message(issue) == "is not a valid hostname"
    end

    test "rejects empty strings, empty labels and trailing dots" do
      for input <- ["", ".", ".com", "example..com", "example.com."] do
        assert {:error, [issue]} = Z.hostname() |> Z.parse(input)
        assert Exception.message(issue) == "is not a valid hostname"
      end
    end

    test "rejects underscores, spaces and schemes" do
      for input <- ["my_host.com", "exa mple.com", "https://example.com"] do
        assert {:error, [issue]} = Z.hostname() |> Z.parse(input)
        assert Exception.message(issue) == "is not a valid hostname"
      end
    end

    test "rejects non-string input" do
      assert {:error, [issue]} = Z.hostname() |> Z.parse(42)
      assert Exception.message(issue) == "expected type string, got integer"
    end
  end

  describe "allow_loopback" do
    test "allows loopback hostnames by default" do
      assert {:ok, "localhost"} = Z.hostname() |> Z.parse("localhost")
      assert {:ok, "app.localhost"} = Z.hostname() |> Z.parse("app.localhost")
      assert {:ok, "127.0.0.1"} = Z.hostname() |> Z.parse("127.0.0.1")
    end

    test "rejects localhost and *.localhost when disabled" do
      assert {:error, [issue]} = Z.hostname(allow_loopback: false) |> Z.parse("localhost")
      assert Exception.message(issue) == "loopback addresses are not allowed"

      assert {:error, [issue]} = Z.hostname(allow_loopback: false) |> Z.parse("app.localhost")
      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "matches loopback hostnames case-insensitively when disabled" do
      assert {:error, [issue]} = Z.hostname(allow_loopback: false) |> Z.parse("LocalHost")
      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "rejects loopback ip addresses when disabled" do
      assert {:error, [issue]} = Z.hostname(allow_loopback: false) |> Z.parse("127.0.0.1")
      assert Exception.message(issue) == "loopback addresses are not allowed"

      assert {:error, [issue]} = Z.hostname(allow_loopback: false) |> Z.parse("127.1.2.3")
      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "still accepts non-loopback hostnames when disabled" do
      assert {:ok, "example.com"} = Z.hostname(allow_loopback: false) |> Z.parse("example.com")
      assert {:ok, "10.0.0.1"} = Z.hostname(allow_loopback: false) |> Z.parse("10.0.0.1")
    end

    test "can be set through the Z.allow_loopback/2 modifier" do
      assert {:error, [issue]} = Z.hostname() |> Z.allow_loopback(false) |> Z.parse("localhost")
      assert Exception.message(issue) == "loopback addresses are not allowed"
    end
  end

  describe "json schema" do
    test "marks the type as nullable when optional" do
      schema = Z.hostname() |> Z.optional() |> Z.json_schema()
      assert schema["type"] == ["string", nil]
    end
  end
end
