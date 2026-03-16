defmodule Zot.IpTest do
  use ExUnit.Case, async: true

  alias Zot.Ip

  # -- parse_ip/1 -------------------------------------------------------------

  describe "parse_ip/1" do
    test "parses valid IPv4 addresses" do
      assert {:ok, {192, 168, 1, 1}} = Ip.parse_ip("192.168.1.1")
      assert {:ok, {0, 0, 0, 0}} = Ip.parse_ip("0.0.0.0")
      assert {:ok, {255, 255, 255, 255}} = Ip.parse_ip("255.255.255.255")
    end

    test "parses valid IPv6 addresses" do
      assert {:ok, {0, 0, 0, 0, 0, 0, 0, 1}} = Ip.parse_ip("::1")
      assert {:ok, {0xFE80, 0, 0, 0, 0, 0, 0, 1}} = Ip.parse_ip("fe80::1")
      assert {:ok, {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1}} = Ip.parse_ip("2001:db8::1")
    end

    test "returns :error for invalid input" do
      assert :error = Ip.parse_ip("not-an-ip")
      assert :error = Ip.parse_ip("256.0.0.0")
      assert :error = Ip.parse_ip("")
    end
  end

  # -- parse_ip!/1 ------------------------------------------------------------

  describe "parse_ip!/1" do
    test "returns tuple for valid IP" do
      assert {192, 168, 1, 1} = Ip.parse_ip!("192.168.1.1")
      assert {0, 0, 0, 0, 0, 0, 0, 1} = Ip.parse_ip!("::1")
    end

    test "raises ArgumentError for invalid IP" do
      assert_raise ArgumentError, ~r/invalid IP address/, fn ->
        Ip.parse_ip!("not-an-ip")
      end
    end
  end

  # -- parse_cidr/1 -----------------------------------------------------------

  describe "parse_cidr/1" do
    test "parses valid IPv4 CIDRs" do
      assert {:ok, {{192, 168, 0, 0}, 24}} = Ip.parse_cidr("192.168.0.0/24")
      assert {:ok, {{10, 0, 0, 0}, 8}} = Ip.parse_cidr("10.0.0.0/8")
    end

    test "parses valid IPv6 CIDRs" do
      assert {:ok, {{0, 0, 0, 0, 0, 0, 0, 1}, 128}} = Ip.parse_cidr("::1/128")
      assert {:ok, {{0xFE80, 0, 0, 0, 0, 0, 0, 0}, 10}} = Ip.parse_cidr("fe80::/10")
    end

    test "returns :error for invalid input" do
      assert :error = Ip.parse_cidr("not-a-cidr")
      assert :error = Ip.parse_cidr("192.168.0.0")
      assert :error = Ip.parse_cidr("192.168.0.0/abc")
      assert :error = Ip.parse_cidr("192.168.0.0/-1")
    end
  end

  # -- parse_cidr!/1 ----------------------------------------------------------

  describe "parse_cidr!/1" do
    test "returns tuple for valid CIDR" do
      assert {{10, 0, 0, 0}, 8} = Ip.parse_cidr!("10.0.0.0/8")
      assert {{0, 0, 0, 0, 0, 0, 0, 1}, 128} = Ip.parse_cidr!("::1/128")
    end

    test "raises ArgumentError for invalid CIDR" do
      assert_raise ArgumentError, ~r/invalid CIDR/, fn ->
        Ip.parse_cidr!("not-a-cidr")
      end
    end
  end

  # -- in_cidr?/2 (single CIDR) -----------------------------------------------

  describe "in_cidr?/2 with a single CIDR" do
    test "IP within range returns true" do
      assert Ip.in_cidr?("192.168.1.1", "192.168.0.0/16")
    end

    test "IP outside range returns false" do
      refute Ip.in_cidr?("10.0.0.1", "192.168.0.0/16")
    end

    test "exact match with /32 returns true" do
      assert Ip.in_cidr?("10.0.0.0", "10.0.0.0/32")
    end

    test "version mismatch returns false" do
      refute Ip.in_cidr?("192.168.1.1", "fe80::/10")
    end

    test "accepts tuple input for IP" do
      assert Ip.in_cidr?({192, 168, 1, 1}, "192.168.0.0/16")
    end

    test "accepts string inputs for both IP and CIDR" do
      assert Ip.in_cidr?("10.0.0.1", "10.0.0.0/8")
    end
  end

  # -- in_cidr?/2 (list of CIDRs) ---------------------------------------------

  describe "in_cidr?/2 with a list of CIDRs" do
    test "IP matches one of several CIDRs" do
      assert Ip.in_cidr?("10.0.0.1", ["10.0.0.0/8", "172.16.0.0/12"])
    end

    test "IP matches none of the CIDRs" do
      refute Ip.in_cidr?("8.8.8.8", ["10.0.0.0/8", "172.16.0.0/12"])
    end

    test "empty list returns false" do
      refute Ip.in_cidr?("10.0.0.1", [])
    end
  end

  # -- in_cidr?/2 (atom sets) -------------------------------------------------

  describe "in_cidr?/2 with :private" do
    test "10.x.x.x is private" do
      assert Ip.in_cidr?("10.1.2.3", :private)
    end

    test "8.8.8.8 is not private" do
      refute Ip.in_cidr?("8.8.8.8", :private)
    end

    test "fc00::1 is private" do
      assert Ip.in_cidr?("fc00::1", :private)
    end
  end

  describe "in_cidr?/2 with :loopback" do
    test "127.0.0.1 is loopback" do
      assert Ip.in_cidr?("127.0.0.1", :loopback)
    end

    test "::1 is loopback" do
      assert Ip.in_cidr?("::1", :loopback)
    end

    test "10.0.0.1 is not loopback" do
      refute Ip.in_cidr?("10.0.0.1", :loopback)
    end
  end

  describe "in_cidr?/2 with :link_local" do
    test "169.254.1.1 is link-local" do
      assert Ip.in_cidr?("169.254.1.1", :link_local)
    end

    test "fe80::1 is link-local" do
      assert Ip.in_cidr?("fe80::1", :link_local)
    end

    test "10.0.0.1 is not link-local" do
      refute Ip.in_cidr?("10.0.0.1", :link_local)
    end
  end

  # -- Convenience wrappers ---------------------------------------------------

  describe "private?/1" do
    test "returns true for private IPs" do
      assert Ip.private?("192.168.1.1")
      assert Ip.private?("10.0.0.1")
    end

    test "returns false for public IPs" do
      refute Ip.private?("8.8.8.8")
    end
  end

  describe "loopback?/1" do
    test "returns true for loopback IPs" do
      assert Ip.loopback?("127.0.0.1")
      assert Ip.loopback?({0, 0, 0, 0, 0, 0, 0, 1})
    end

    test "returns false for non-loopback IPs" do
      refute Ip.loopback?("10.0.0.1")
    end
  end

  describe "link_local?/1" do
    test "returns true for link-local IPs" do
      assert Ip.link_local?("169.254.1.1")
      assert Ip.link_local?("fe80::1")
    end

    test "returns false for non-link-local IPs" do
      refute Ip.link_local?("10.0.0.1")
    end
  end

  # -- network_address/2 ------------------------------------------------------

  describe "network_address/2" do
    test "computes network address for IPv4 /24" do
      assert {192, 168, 1, 0} = Ip.network_address({192, 168, 1, 100}, 24)
    end

    test "computes network address for IPv4 /8" do
      assert {10, 0, 0, 0} = Ip.network_address({10, 1, 2, 3}, 8)
    end

    test "computes network address for IPv6" do
      assert {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0} =
               Ip.network_address({0x2001, 0x0DB8, 0x0001, 0x0002, 0x0003, 0x0004, 0x0005, 0x0006}, 32)
    end
  end

  # -- broadcast_address/2 ----------------------------------------------------

  describe "broadcast_address/2" do
    test "computes broadcast address for IPv4 /24" do
      assert {192, 168, 1, 255} = Ip.broadcast_address({192, 168, 1, 0}, 24)
    end

    test "computes broadcast address for IPv4 /8" do
      assert {10, 255, 255, 255} = Ip.broadcast_address({10, 0, 0, 0}, 8)
    end

    test "computes broadcast address for IPv6" do
      assert {0x2001, 0x0DB8, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF, 0xFFFF} =
               Ip.broadcast_address({0x2001, 0x0DB8, 0, 0, 0, 0, 0, 0}, 32)
    end
  end

  # -- cidrs/1 ----------------------------------------------------------------

  describe "cidrs/1" do
    test ":private returns expected list" do
      assert Ip.cidrs(:private) == ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16", "fc00::/7"]
    end

    test ":loopback returns expected list" do
      assert Ip.cidrs(:loopback) == ["127.0.0.0/8", "::1/128"]
    end

    test ":link_local returns expected list" do
      assert Ip.cidrs(:link_local) == ["169.254.0.0/16", "fe80::/10"]
    end
  end
end
