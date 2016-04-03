defmodule MACAddrTest do
  use ExUnit.Case
  doctest MACAddr, except: [format_as: 2, random: 0, random: 1]
  
  @addr MACAddr.parse("15EF2E91977A")
  @oui MACAddr.parse("00-CD-FE")
  
  test "a random address with a specified upper half actually contains that upper half" do
    assert @oui
      |> MACAddr.random
      |> MACAddr.most_significant_24_bits == @oui
  end
  
  test "it correctly formats a MAC address in IEEE style" do
    assert MACAddr.format_as(@addr, :ieee) == "15-EF-2E-91-97-7A"
  end
  
  test "it correctly formats a MAC address in colon-separated style" do
    assert MACAddr.format_as(@addr, :colon_separated) == "15:EF:2E:91:97:7A"
  end
  
  test "it correctly formats a MAC address in plain style" do
    assert MACAddr.format_as(@addr, :plain) == "15EF2E91977A"
  end
  
  test "it correctly formats a MAC address in dotted decimal style" do
    assert MACAddr.format_as(@addr, :dotted_decimal) == "21.239.46.145.151.122"
  end
  
  test "it correctly formats a MAC address in Cisco style" do
    assert MACAddr.format_as(@addr, :cisco) == "15ef.2e91.977a"
  end
  
  test "it can't format an OUI in Cisco style" do
    assert_raise FunctionClauseError, fn ->
      MACAddr.format_as(@oui, :cisco)
    end
  end
end
