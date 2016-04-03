defmodule MACAddr.Local do
  @moduledoc """
  Convenience functions to determine a local machine's MAC addresses, using Erlang's inet module.
  """
  
  @doc """
  Returns a list of all local MAC addresses.
  
  ## Examples
  
  Get a list of local MAC addresses:
  
      iex> MACAddr.Local.all
      [<<244, 92, 137, 11, 149, 14>>, <<74, 0, 5, 15, 252, 96>>,
       <<74, 0, 5, 7, 107, 15>>, <<6, 92, 137, 100, 224, 92>>,
       <<2, 127, 112, 79, 147, 123>>, <<246, 92, 137, 189, 168, 100>>]
    
  Get a list of local MAC addresses, extract the universally administered ones, strip them to their OUIs, create random addresses from the OUIs, and convert them to Cisco-formatted strings:
  
      iex> MACAddr.Local.all |> Enum.filter_map(fn(addr) ->
             MACAddr.is_universal?(addr)
           end, fn(addr) ->
             addr
               |> MACAddr.oui
               |> MACAddr.random
               |> MACAddr.format_as(:cisco)
           end)
      ["f45c.890b.950e"]
  
  """
  def all do
    {:ok, interfaces} = :inet.getifaddrs
    Enum.filter_map(interfaces, &interface_to_hwaddr/1, &interface_to_addr/1)
  end
  
  @doc """
  Returns the MAC address of the interface with `name`, or `nil` if it can't find anything.
  
  ## Examples
  
  Get the MAC address of en0:
  
      iex> MACAddr.Local.by_interface("en0")
      <<244, 92, 137, 11, 149, 14>>
      
  Try to get the MAC address of yeast0:
  
      iex> MACAddr.Local.by_interface("yeast0")
      nil
      
  """
  def by_interface(name) do
    target = String.to_char_list(name)
    
    {:ok, interfaces} = :inet.getifaddrs    
    matching_interface = Enum.find(interfaces, fn({name, _options}) ->
      name == target
    end)
    
    if matching_interface do
      interface_to_addr(matching_interface)
    end
  end
  
  
  @doc """
  Returns the MAC address of the interface with the IP address `ip_address`, or `nil` if it can't find anything.
  
  ## Examples
  
  Get the MAC address associated with 192.168.20.1:
  
      iex> MACAddr.Local.by_ip_address("192.168.20.1")
      <<244, 92, 137, 11, 149, 14>>
  
  """
  def by_ip_address(ip_address) do
    {:ok, target} = ip_address |> String.to_char_list |> :inet.parse_address

    {:ok, interfaces} = :inet.getifaddrs
    matching_interface = Enum.find(interfaces, fn({_name, options}) ->
      options |> Keyword.get_values(:addr) |> Enum.find(&(&1 == target))
    end)
    
    if matching_interface do
      interface_to_addr(matching_interface)
    end
  end
  
  defp interface_to_hwaddr({_name, options}) do
    options[:hwaddr]
  end
  
  defp interface_to_addr(interface) do
    interface_to_hwaddr(interface) |> :erlang.list_to_binary
  end
end