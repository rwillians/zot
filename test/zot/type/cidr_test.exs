defmodule Zot.Type.CIDRTest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "basic parsing" do
    test "accepts valid IPv4 CIDR in canonical form" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr() |> Z.parse("192.168.0.0/24")
      assert {:ok, "10.0.0.0/8"} = Z.cidr() |> Z.parse("10.0.0.0/8")
      assert {:ok, "0.0.0.0/0"} = Z.cidr() |> Z.parse("0.0.0.0/0")
    end

    test "accepts valid IPv6 CIDR in canonical form" do
      assert {:ok, "2001:db8::/32"} = Z.cidr() |> Z.parse("2001:db8::/32")
      assert {:ok, "::/0"} = Z.cidr() |> Z.parse("::/0")
    end

    test "rejects non-string input" do
      assert {:error, [issue]} = Z.cidr() |> Z.parse(123)
      assert Exception.message(issue) == "expected type string, got integer"
    end

    test "rejects invalid format" do
      assert {:error, [issue]} = Z.cidr() |> Z.parse("not-a-cidr")
      assert Exception.message(issue) == "is invalid"

      assert {:error, [issue]} = Z.cidr() |> Z.parse("192.168.0.0")
      assert Exception.message(issue) == "is invalid"

      assert {:error, [issue]} = Z.cidr() |> Z.parse("192.168.0.0/")
      assert Exception.message(issue) == "is invalid"

      assert {:error, [issue]} = Z.cidr() |> Z.parse("/24")
      assert Exception.message(issue) == "is invalid"
    end

    test "rejects invalid IP address" do
      assert {:error, [issue]} = Z.cidr() |> Z.parse("999.999.999.999/24")
      assert Exception.message(issue) == "is invalid"
    end

    test "rejects negative prefix" do
      assert {:error, [issue]} = Z.cidr() |> Z.parse("192.168.0.0/-1")
      assert Exception.message(issue) == "is invalid"
    end
  end

  describe "version restriction" do
    test "accepts IPv4 when version is :v4" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr(version: :v4) |> Z.parse("192.168.0.0/24")
    end

    test "rejects IPv6 when version is :v4" do
      assert {:error, [issue]} = Z.cidr(version: :v4) |> Z.parse("2001:db8::/32")
      assert Exception.message(issue) == "must be a valid IPv4 CIDR"
    end

    test "accepts IPv6 when version is :v6" do
      assert {:ok, "2001:db8::/32"} = Z.cidr(version: :v6) |> Z.parse("2001:db8::/32")
    end

    test "rejects IPv4 when version is :v6" do
      assert {:error, [issue]} = Z.cidr(version: :v6) |> Z.parse("192.168.0.0/24")
      assert Exception.message(issue) == "must be a valid IPv6 CIDR"
    end

    test "accepts both versions when version is :any" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr(version: :any) |> Z.parse("192.168.0.0/24")
      assert {:ok, "2001:db8::/32"} = Z.cidr(version: :any) |> Z.parse("2001:db8::/32")
    end

    test "version modifier works" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr() |> Z.version(:v4) |> Z.parse("192.168.0.0/24")
      assert {:ok, "2001:db8::/32"} = Z.cidr() |> Z.version(:v6) |> Z.parse("2001:db8::/32")
    end
  end

  describe "prefix bounds validation" do
    test "rejects IPv4 prefix greater than 32" do
      assert {:error, [issue]} = Z.cidr(version: :v4) |> Z.parse("192.168.0.0/33")
      assert Exception.message(issue) == "prefix length must be between 0 and 32, got 33"
    end

    test "rejects IPv6 prefix greater than 128" do
      assert {:error, [issue]} = Z.cidr(version: :v6) |> Z.parse("2001:db8::/129")
      assert Exception.message(issue) == "prefix length must be between 0 and 128, got 129"
    end

    test "accepts edge case prefix 0" do
      assert {:ok, "0.0.0.0/0"} = Z.cidr() |> Z.parse("0.0.0.0/0")
      assert {:ok, "::/0"} = Z.cidr() |> Z.parse("::/0")
    end

    test "accepts edge case prefix 32 for IPv4" do
      assert {:ok, "192.168.0.1/32"} = Z.cidr() |> Z.parse("192.168.0.1/32")
    end

    test "accepts edge case prefix 128 for IPv6" do
      assert {:ok, "2001:db8::1/128"} = Z.cidr() |> Z.parse("2001:db8::1/128")
    end
  end

  describe "min_prefix constraint" do
    test "accepts prefix equal to min_prefix" do
      assert {:ok, "10.0.0.0/16"} = Z.cidr(min_prefix: 16) |> Z.parse("10.0.0.0/16")
    end

    test "accepts prefix greater than min_prefix" do
      assert {:ok, "10.0.0.0/24"} = Z.cidr(min_prefix: 16) |> Z.parse("10.0.0.0/24")
    end

    test "rejects prefix less than min_prefix" do
      assert {:error, [issue]} = Z.cidr(min_prefix: 16) |> Z.parse("10.0.0.0/8")
      assert Exception.message(issue) == "prefix length must be at least 16, got 8"
    end

    test "min_prefix modifier works" do
      assert {:error, [issue]} = Z.cidr() |> Z.min_prefix(16) |> Z.parse("10.0.0.0/8")
      assert Exception.message(issue) == "prefix length must be at least 16, got 8"
    end

    test "min_prefix with custom error message" do
      assert {:error, [issue]} =
               Z.cidr()
               |> Z.min_prefix(16, error: "network too large")
               |> Z.parse("10.0.0.0/8")

      assert Exception.message(issue) == "network too large"
    end
  end

  describe "max_prefix constraint" do
    test "accepts prefix equal to max_prefix" do
      assert {:ok, "10.0.0.0/24"} = Z.cidr(max_prefix: 24) |> Z.parse("10.0.0.0/24")
    end

    test "accepts prefix less than max_prefix" do
      assert {:ok, "10.0.0.0/16"} = Z.cidr(max_prefix: 24) |> Z.parse("10.0.0.0/16")
    end

    test "rejects prefix greater than max_prefix" do
      assert {:error, [issue]} = Z.cidr(max_prefix: 24) |> Z.parse("10.0.0.0/28")
      assert Exception.message(issue) == "prefix length must be at most 24, got 28"
    end

    test "max_prefix modifier works" do
      assert {:error, [issue]} = Z.cidr() |> Z.max_prefix(24) |> Z.parse("10.0.0.0/28")
      assert Exception.message(issue) == "prefix length must be at most 24, got 28"
    end

    test "max_prefix with custom error message" do
      assert {:error, [issue]} =
               Z.cidr()
               |> Z.max_prefix(24, error: "network too small")
               |> Z.parse("10.0.0.0/28")

      assert Exception.message(issue) == "network too small"
    end
  end

  describe "min_prefix and max_prefix together" do
    test "accepts prefix within range" do
      type = Z.cidr(min_prefix: 16, max_prefix: 24)
      assert {:ok, "10.0.0.0/16"} = type |> Z.parse("10.0.0.0/16")
      assert {:ok, "10.0.0.0/20"} = type |> Z.parse("10.0.0.0/20")
      assert {:ok, "10.0.0.0/24"} = type |> Z.parse("10.0.0.0/24")
    end

    test "rejects prefix outside range" do
      type = Z.cidr(min_prefix: 16, max_prefix: 24)
      assert {:error, _} = type |> Z.parse("10.0.0.0/8")
      assert {:error, _} = type |> Z.parse("10.0.0.0/28")
    end
  end

  describe "canonicalization" do
    test "rejects non-canonical CIDR by default" do
      assert {:error, [issue]} = Z.cidr() |> Z.parse("192.168.1.100/24")
      assert Exception.message(issue) == "must be in canonical form (network address), got '192.168.1.100/24'"
    end

    test "canonicalizes when canonicalize: true" do
      assert {:ok, "192.168.1.0/24"} = Z.cidr(canonicalize: true) |> Z.parse("192.168.1.100/24")
      assert {:ok, "10.0.0.0/8"} = Z.cidr(canonicalize: true) |> Z.parse("10.255.255.255/8")
    end

    test "canonicalize modifier works" do
      assert {:ok, "192.168.1.0/24"} = Z.cidr() |> Z.canonicalize(true) |> Z.parse("192.168.1.100/24")
    end

    test "already canonical CIDR passes without changes" do
      assert {:ok, "192.168.1.0/24"} = Z.cidr() |> Z.parse("192.168.1.0/24")
      assert {:ok, "192.168.1.0/24"} = Z.cidr(canonicalize: true) |> Z.parse("192.168.1.0/24")
    end

    test "canonicalization works for IPv6" do
      assert {:ok, "2001:db8::/32"} = Z.cidr(canonicalize: true) |> Z.parse("2001:db8::ffff/32")
    end
  end

  describe "output formats" do
    test "default output is string" do
      assert {:ok, "192.168.1.0/24"} = Z.cidr() |> Z.parse("192.168.1.0/24")
    end

    test "tuple output format" do
      assert {:ok, {{192, 168, 1, 0}, {192, 168, 1, 255}, 24}} =
               Z.cidr(output: :tuple) |> Z.parse("192.168.1.0/24")
    end

    test "map output format" do
      assert {:ok, %{start: {192, 168, 1, 0}, end: {192, 168, 1, 255}, prefix: 24}} =
               Z.cidr(output: :map) |> Z.parse("192.168.1.0/24")
    end

    test "output modifier works" do
      assert {:ok, {{192, 168, 1, 0}, {192, 168, 1, 255}, 24}} =
               Z.cidr() |> Z.output(:tuple) |> Z.parse("192.168.1.0/24")
    end

    test "tuple output for IPv6" do
      assert {:ok, {{0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0}, {0x2001, 0x0DB8, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF}, 32}} =
               Z.cidr(output: :tuple) |> Z.parse("2001:db8::/32")
    end

    test "map output for IPv6" do
      result = Z.cidr(output: :map) |> Z.parse("2001:db8::/32")

      assert {:ok, %{start: start, end: end_addr, prefix: 32}} = result
      assert start == {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0}
      assert end_addr == {0x2001, 0x0DB8, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF}
    end
  end

  describe "coercion" do
    test "coerces from {ip_tuple, prefix} for IPv4" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr() |> Z.parse({{192, 168, 0, 0}, 24}, coerce: true)
    end

    test "coerces from {ip_tuple, prefix} for IPv6" do
      assert {:ok, "2001:db8::/32"} = Z.cidr() |> Z.parse({{0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0}, 32}, coerce: true)
    end

    test "coerces from %{ip: tuple, prefix: int}" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr() |> Z.parse(%{ip: {192, 168, 0, 0}, prefix: 24}, coerce: true)
    end

    test "coerces from %{address: tuple, prefix: int}" do
      assert {:ok, "192.168.0.0/24"} = Z.cidr() |> Z.parse(%{address: {192, 168, 0, 0}, prefix: 24}, coerce: true)
    end

    test "coercion with canonicalization" do
      assert {:ok, "192.168.1.0/24"} =
               Z.cidr(canonicalize: true)
               |> Z.parse({{192, 168, 1, 100}, 24}, coerce: true)
    end

    test "coercion with output format" do
      assert {:ok, {{192, 168, 0, 0}, {192, 168, 0, 255}, 24}} =
               Z.cidr(output: :tuple)
               |> Z.parse({{192, 168, 0, 0}, 24}, coerce: true)
    end
  end

  describe "optional and default" do
    test "optional CIDR accepts nil" do
      assert {:ok, nil} = Z.cidr() |> Z.optional() |> Z.parse(nil)
    end

    test "default value is used when nil" do
      assert {:ok, "0.0.0.0/0"} = Z.cidr() |> Z.default("0.0.0.0/0") |> Z.parse(nil)
    end

    test "provided value overrides default" do
      assert {:ok, "10.0.0.0/8"} = Z.cidr() |> Z.default("0.0.0.0/0") |> Z.parse("10.0.0.0/8")
    end
  end

  describe "edge cases" do
    test "single host IPv4 (/32)" do
      assert {:ok, "192.168.1.1/32"} = Z.cidr() |> Z.parse("192.168.1.1/32")

      assert {:ok, {{192, 168, 1, 1}, {192, 168, 1, 1}, 32}} =
               Z.cidr(output: :tuple) |> Z.parse("192.168.1.1/32")
    end

    test "single host IPv6 (/128)" do
      assert {:ok, "2001:db8::1/128"} = Z.cidr() |> Z.parse("2001:db8::1/128")
    end

    test "entire IPv4 address space (/0)" do
      assert {:ok, "0.0.0.0/0"} = Z.cidr() |> Z.parse("0.0.0.0/0")

      assert {:ok, {{0, 0, 0, 0}, {255, 255, 255, 255}, 0}} =
               Z.cidr(output: :tuple) |> Z.parse("0.0.0.0/0")
    end

    test "entire IPv6 address space (/0)" do
      assert {:ok, "::/0"} = Z.cidr() |> Z.parse("::/0")
    end

    test "loopback networks" do
      assert {:ok, "127.0.0.0/8"} = Z.cidr() |> Z.parse("127.0.0.0/8")
      assert {:ok, "::1/128"} = Z.cidr() |> Z.parse("::1/128")
    end

    test "private network ranges" do
      assert {:ok, "10.0.0.0/8"} = Z.cidr() |> Z.parse("10.0.0.0/8")
      assert {:ok, "172.16.0.0/12"} = Z.cidr() |> Z.parse("172.16.0.0/12")
      assert {:ok, "192.168.0.0/16"} = Z.cidr() |> Z.parse("192.168.0.0/16")
    end
  end

  describe "json schema" do
    test "generates schema for IPv4" do
      schema = Z.cidr(version: :v4) |> Z.json_schema()

      assert schema["type"] == "string"
      assert schema["pattern"] =~ "^"
      assert is_nil(schema["anyOf"])
    end

    test "generates schema for IPv6" do
      schema = Z.cidr(version: :v6) |> Z.json_schema()

      assert schema["type"] == "string"
      assert schema["pattern"] =~ "^"
      assert is_nil(schema["anyOf"])
    end

    test "generates anyOf schema for :any version" do
      schema = Z.cidr(version: :any) |> Z.json_schema()

      assert is_list(schema["anyOf"])
      assert length(schema["anyOf"]) == 2
    end

    test "includes description and examples" do
      schema =
        Z.cidr()
        |> Z.describe("A network range")
        |> Z.example("192.168.0.0/24")
        |> Z.json_schema()

      assert schema["description"] == "A network range"
      assert schema["examples"] == ["192.168.0.0/24"]
    end
  end
end
