defmodule Zot.Type.URITest do
  use ExUnit.Case, async: true

  alias Zot, as: Z

  describe "host validation" do
    test "accepts URI with host" do
      assert {:ok, "https://example.com"} = Z.uri() |> Z.parse("https://example.com")
    end

    test "rejects relative path (no host)" do
      assert {:error, [issue]} = Z.uri() |> Z.parse("/relative/path")
      assert Exception.message(issue) == "host is required"
    end

    test "rejects URN (no host)" do
      assert {:error, [issue]} = Z.uri() |> Z.parse("urn:isbn:0451450523")
      assert Exception.message(issue) == "host is required"
    end
  end

  describe "require_path" do
    test "default (false) allows URIs without path" do
      assert {:ok, "https://example.com"} = Z.uri() |> Z.parse("https://example.com")
    end

    test "accepts URI with non-root path when required" do
      assert {:ok, "https://example.com/foo"} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/foo")
    end

    test "rejects URI with nil path when required" do
      assert {:error, [issue]} =
               Z.uri(require_path: true) |> Z.parse("https://example.com")

      assert Exception.message(issue) == "path is required"
    end

    test "rejects URI with root-only path when required" do
      assert {:error, [issue]} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/")

      assert Exception.message(issue) == "path is required"
    end

    test "accepts nested path when required" do
      assert {:ok, "https://example.com/foo/bar"} =
               Z.uri(require_path: true) |> Z.parse("https://example.com/foo/bar")
    end
  end

  describe "allowed_ports" do
    test "passes when URI has no explicit port" do
      assert {:ok, "https://example.com"} =
               Z.uri(allowed_ports: [80, 443]) |> Z.parse("https://example.com")
    end

    test "accepts port in allowed list" do
      assert {:ok, "https://example.com:8080/path"} =
               Z.uri(allowed_ports: [80, 8080]) |> Z.parse("https://example.com:8080/path")
    end

    test "rejects port not in allowed list" do
      assert {:error, [issue]} =
               Z.uri(allowed_ports: [80, 443]) |> Z.parse("https://example.com:9090/path")

      assert Exception.message(issue) == "port must be 80 or 443, got 9090"
    end
  end

  describe "forbidden_ports" do
    test "passes when port is not in forbidden list" do
      assert {:ok, "https://example.com:8080/path"} =
               Z.uri(forbidden_ports: [25]) |> Z.parse("https://example.com:8080/path")
    end

    test "rejects port in forbidden list" do
      assert {:error, [issue]} =
               Z.uri(forbidden_ports: [25]) |> Z.parse("https://example.com:25/path")

      assert Exception.message(issue) == "port 25 is not allowed"
    end

    test "passes when URI has no explicit port" do
      assert {:ok, "https://example.com"} =
               Z.uri(forbidden_ports: [25]) |> Z.parse("https://example.com")
    end
  end

  describe "allowed_ports + forbidden_ports conflict" do
    test "raises when both are set (allowed first)" do
      assert_raise ArgumentError, ~r/cannot set forbidden_ports/, fn ->
        Z.uri(allowed_ports: [80]) |> Z.forbidden_ports([25])
      end
    end

    test "raises when both are set (forbidden first)" do
      assert_raise ArgumentError, ~r/cannot set allowed_ports/, fn ->
        Z.uri(forbidden_ports: [25]) |> Z.allowed_ports([80])
      end
    end
  end

  describe "allow_loopback" do
    test "default (true) allows loopback addresses" do
      assert {:ok, _} = Z.uri() |> Z.parse("https://localhost/path")
      assert {:ok, _} = Z.uri() |> Z.parse("https://127.0.0.1/path")
    end

    test "rejects localhost when disallowed" do
      assert {:error, [issue]} =
               Z.uri(allow_loopback: false) |> Z.parse("https://localhost/path")

      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "rejects subdomain of localhost when disallowed" do
      assert {:error, [issue]} =
               Z.uri(allow_loopback: false) |> Z.parse("https://foo.localhost/path")

      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "rejects 127.x.x.x when disallowed" do
      assert {:error, [issue]} =
               Z.uri(allow_loopback: false) |> Z.parse("https://127.0.0.1/path")

      assert Exception.message(issue) == "loopback addresses are not allowed"

      assert {:error, [issue]} =
               Z.uri(allow_loopback: false) |> Z.parse("https://127.255.0.1/path")

      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "rejects ::1 when disallowed" do
      assert {:error, [issue]} =
               Z.uri(allow_loopback: false) |> Z.parse("https://[::1]/path")

      assert Exception.message(issue) == "loopback addresses are not allowed"
    end

    test "allows non-loopback addresses when disallowed" do
      assert {:ok, "https://example.com/path"} =
               Z.uri(allow_loopback: false) |> Z.parse("https://example.com/path")
    end

    test "allows non-loopback IPs when disallowed" do
      assert {:ok, "https://8.8.8.8/path"} =
               Z.uri(allow_loopback: false) |> Z.parse("https://8.8.8.8/path")
    end
  end
end
