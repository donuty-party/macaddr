defmodule MACAddr do
  @moduledoc """
  Functions for working with IEEE 802 MAC addresses and Organizationally Unique Identifiers (OUIs).
  
  ## Representation
  
  MACAddr represents MAC addresses and OUIs as binaries. Except where noted, MAC addresses and OUIs can be used interchangeably throughout the module.
  
  ## Speaking of OUIs
  
  The most significant 24 bits of a MAC address is only an OUI when the address's U/L bit is zero, signifying that the address is globally unique. MACAddr provides functions, `MACAddr.is_globally_unique?/1` and `MACAddr.is_locally_administered?/1`, to test the U/L bit, but otherwise ignores it. If a MAC address is locally administered, what this module considers an OUI is really just the most significant 24 bits of the address.
  
  """
  
  use Bitwise

  @broadcast_addr <<0xFFFFFFFFFFFF::big-unsigned-48>>
  
  @doc """
  Splits `addr` into a list of integers, each representing a `chunk_size` (8-, 16-, or 24-) bit chunk of the address.
  
  ## Examples
  
  Let's grab a MAC address:
  
      iex> addr = MACAddr.parse("15-EF-2E-91-97-7A")
      <<21, 239, 46, 145, 151, 122>>
      
  …then split it into 8-bit chunks:
      
      iex> MACAddr.split(addr, 8)
      [21, 239, 46, 145, 151, 122]
      
  …or into 16-bit chunks:
      
      iex> MACAddr.split(addr, 16)
      [5615, 11921, 38778]
      
  **Note:** We can't split an OUI evenly into 16-bit chunks, so this won't work:
      
      iex> oui = MACAddr.parse("FF-FF-FF")
      <<255, 255, 255>>
      
      iex> MACAddr.split(oui, 16)
      
      ** (FunctionClauseError) no function clause matching in MACAddr.split/2
          (macaddr) lib/macaddr.ex:32: MACAddr.split(<<255, 255, 255>>, 16)
  
  """
  def split(addr, chunk_size) when chunk_size == 8 do
    :binary.bin_to_list(addr)
  end
  def split(addr, chunk_size) when (chunk_size == 16 and bit_size(addr) == 48) or (chunk_size == 24) do
    do_split(addr, chunk_size, [])
  end
  
  defp do_split(<<>>, _chunk_size, chunks) do
    Enum.reverse(chunks)
  end
  defp do_split(addr, chunk_size, chunks) do
    <<chunk::big-unsigned-size(chunk_size), rest::bits>> = addr
    do_split(rest, chunk_size, [chunk | chunks])
  end

  @doc """
  Formats a MAC address as a string, by dividing `addr` into chunks of `chunk_size` bits, formatting the chunks with a `chunk_formatter` function, and joining them with a `separator` string.
  
  If `MACAddr.to_string/1` or `MACAddr.format_as/2` don't cut it, consider this as a more flexible option.
  
  ## Examples
  
  Let's make up a MAC address:
  
      iex> addr = MACAddr.parse("AB-8F-04-97-2C-A8")
      <<171, 143, 4, 151, 44, 168>>
      
  Now, let's format it as zero-padded, uppercase hex words, separated with spaces:

      iex> MACAddr.format(addr, 16, fn(word) ->
             word
               |> Integer.to_string(16)
               |> String.rjust(4, ?0)
           end, " ")
      "AB8F 0497 2CA8"
      
  Let's make up another MAC address:
  
      iex> addr = MACAddr.parse("3B-B5-4E-42-72-03")
      <<59, 181, 78, 66, 114, 3>>
      
  We'll format this one based on the as_Sun() method from Perl's Net/MAC.pm:
  
      iex> MACAddr.format(addr, 8, fn(byte) ->
             byte
               |> Integer.to_string(16)
               |> String.downcase
           end, ":")
      "3b:b5:4e:42:72:3"
      
  You're well on your way to becoming a Solaris admin. Great job!
      
  """
  def format(addr, chunk_size, chunk_formatter, separator \\ "") do
    addr |> split(chunk_size) |> Enum.map_join(separator, chunk_formatter)
  end

  defp format_padded_hex(addr, chunk_size, separator \\ "") do
    padding = div(chunk_size, 4)
    format(addr, chunk_size, fn(chunk) ->
      chunk |> Integer.to_string(16) |> String.rjust(padding, ?0)
    end, separator)
  end
    
  @doc """
  Formats `addr` as a string in a predefined `style`.
  
  Available styles are:
  - `:ieee`
  - `:colon_separated`
  - `:plain`
  - `:dotted_decimal`
  - `:cisco`
  
  ## Examples
  
  First, let's grab a MAC address:
  
      iex> addr = MACAddr.parse("15EF2E91977A")
      <<21, 239, 46, 145, 151, 122>>
      
  Now, let's see how it looks in IEEE style. Bytes are rendered as uppercase zero-padded hex, separated with hyphens:
  
      iex> MACAddr.format_as(addr, :ieee)
      "15-EF-2E-91-97-7A"
    
  Colon-separated style is the same as IEEE, except bytes are separated with colons:
  
      iex> MACAddr.format_as(addr, :colon_separated)
      "15:EF:2E:91:97:7A"
      
  Plain style is plain. Bytes are rendered as uppercase zero-padded hex with no separation:
  
      iex> MACAddr.format_as(addr, :plain)
      "15EF2E91977A"
      
  Dotted decimal style renders bytes as decimal numbers with no padding, separated with periods.
  
      iex> MACAddr.format_as(addr, :dotted_decimal) # or MACAddr.format_as(addr, :oid)
      "21.239.46.145.151.122"
      
  Cisco style renders a MAC address as three 16-bit words of zero-padded hex, separated with periods:
  
      iex> MACAddr.format_as(addr, :cisco)
      "15ef.2e91.977a"
      
  **Note:** Cisco style doesn't work for OUIs:
  
      iex> oui = MACAddr.parse("FF-FF-FF")
      <<255, 255, 255>>
      
      iex> MACAddr.format_as(oui, :cisco)
      ** (FunctionClauseError) no function clause matching in MACAddr.split/2
          (macaddr) lib/macaddr.ex:39: MACAddr.split(<<255, 255, 255>>, 16)
          (macaddr) lib/macaddr.ex:93: MACAddr.format/4
          (macaddr) lib/macaddr.ex:164: MACAddr.format_as/2
  """
  def format_as(addr, style) do
    do_format_as(addr, style)
  end
  
  defp do_format_as(addr, :ieee) do
    addr |> format_padded_hex(8, "-")
  end
  defp do_format_as(addr, :colon_separated) do
    addr |> format_padded_hex(8, ":")
  end
  defp do_format_as(addr, :plain) do
    addr |> format_padded_hex(8)
  end
  defp do_format_as(addr, :cisco) do
    addr |> format_padded_hex(16, ".") |> String.downcase
  end
  defp do_format_as(addr, :dotted_decimal) do
    addr |> format(8, &Integer.to_string/1, ".")
  end
  defp do_format_as(addr, :oid) do
    addr |> do_format_as(:dotted_decimal)
  end
  
  @doc """
  Converts `addr` to an IEEE-formatted string.
  
  ## Examples
  
      iex> MACAddr.parse("15ef.2e91.977a") |> MACAddr.to_string
      "15-EF-2E-91-97-7A"
  
  """
  def to_string(addr) do
    format_as(addr, :ieee)
  end
  
  @doc """
  Converts `addr` to an integer.
  
  ## Examples
  
      iex> MACAddr.parse("15ef.2e91.977a") |> MACAddr.to_integer
      24117022660474
  
  """
  def to_integer(addr) do
    size = byte_size(addr)
    <<int_addr::big-unsigned-size(size)-unit(8)>> = addr
    int_addr
  end
  
  @doc """
  Converts `integer` into a MAC address, with an optional `size` of either 48 or 24 bits.
  
  ## Examples
  
  Converting an integer to a 48-bit MAC address:
  
      iex> addr = MACAddr.from_integer(24117022660474)
      <<21, 239, 46, 145, 151, 122>>
  
      iex> MACAddr.format_as(addr, :cisco)
      "15ef.2e91.977a"
      
  Converting an integer to a 24-bit OUI:
  
      iex> oui = MACAddr.from_integer(0x15ef23, 24)
      <<21, 239, 35>>
      
      iex> MACAddr.to_string(oui)
      "15-EF-23"
  
  """
  def from_integer(integer, size \\ 48) do
    unless size == 48 or size == 24 do
      raise ArgumentError, "Expected a 48-bit MAC address or 24-bit OUI"
    end
    
    <<integer::big-unsigned-size(size)>>
  end
  
  @doc """
  Generates a random MAC address.
  
  ## Examples
  
      iex> addr = MACAddr.random
      <<243, 5, 217, 191, 24, 15>>
      
      iex> MACAddr.to_string(addr)
      "F3-05-D9-BF-18-0F"
  
  """
  def random do
    :crypto.strong_rand_bytes(6)
  end
  
  @doc """
  Generates a random MAC address with the specified OUI.
  
  ## Examples
  
  Let's create a random MAC address with an OUI of 00-CD-FE:
  
      iex> oui = MACAddr.parse("00-CD-FE")
      <<0, 205, 254>>
      
      iex> addr = MACAddr.random(oui)
      <<0, 205, 254, 109, 252, 6>>
      
      iex> MACAddr.to_string(addr)
      "00-CD-FE-6D-FC-06"
  """
  def random(oui) do
    oui <> :crypto.strong_rand_bytes(3)
  end
  
  @doc """
  Extracts hex digits from `string`, converts the hex digits to an integer, and converts the integer to a MAC address.
  
  Expects 6 or 12 hex digits.
  
  ## Examples
  
  Parsing a Cisco-formatted MAC address:
  
      iex> MACAddr.parse("15ef.2e91.977a")        
      <<21, 239, 46, 145, 151, 122>>
      
  Parsing an IEEE-formatted OUI:
  
      iex> MACAddr.parse("F4-5C-89")
      <<244, 92, 137>>
      
  You don't have to worry about inadvertently copying tabs and spaces:
  
      iex> MACAddr.parse("\\t00-CD-FE-6D-FC-06 ")
      <<0, 205, 254, 109, 252, 6>>
      
  If this function can't find `addr` or OUI in the string, you'll get an ArgumentError:
  
      iex> MACAddr.parse("Hideous anecdote")
      ** (ArgumentError) Expected a 6- or 12-digit hex string.
          (macaddr) lib/macaddr.ex:205: MACAddr.parse/1
         
  …but it errs on the side of leniency:
      
      iex> oui = MACAddr.parse("ventral beeswax")
      <<234, 190, 234>>
      
      iex> MACAddr.to_string(oui)
      "EA-BE-EA"
  
  """
  def parse(string) do
    hex = String.replace(string, ~r/[^0-9a-f]/i, "")
    
    num_digits = String.length(hex)
    unless num_digits == 6 or num_digits == 12 do
      raise ArgumentError, "Expected a 6- or 12-digit hex string."
    end
    
    hex |> String.to_integer(16) |> from_integer(num_digits * 4)
  end
  
  @doc """
  Extracts the OUI, or the most significant 24 bits, of `addr`.
  
  ## Examples
  
      iex> addr = MACAddr.parse("15-EF-2E-91-97-7A")
      <<21, 239, 46, 145, 151, 122>>
      
      iex> oui = MACAddr.oui(addr)
      <<21, 239, 46>>
      
      iex> MACAddr.to_string(oui)
      "15-EF-2E"
  """
  def oui(addr) do
    <<oui::binary-3, _::binary>> = addr
    oui
  end
  
  @doc """
  Determines if `addr` is equal to the broadcast address, `<<255, 255, 255, 255, 255, 255>>`.
  
  ## Examples
  
      iex> MACAddr.parse("15-EF-2E-91-97-7A") |> MACAddr.is_broadcast?
      false
      
      iex> MACAddr.parse("FF-FF-FF-FF-FF-FF") |> MACAddr.is_broadcast?
      true
  
  """
  def is_broadcast?(addr) do
    addr == @broadcast_addr
  end
  
  @doc """
  Determines if `addr` is a multicast address, based on its I/G bit.
  
  ## Examples
  
  F4-5C-89-E2-62-94 is a host (unicast) MAC address:
  
      iex> MACAddr.parse("F4-5C-89-E2-62-94") |> MACAddr.is_multicast?
      false
  
  01-80-C2-00-00-00 is the multicast MAC address for IEEE 802.1D Spanning Tree Protocol:
  
      iex> MACAddr.parse("01-80-C2-00-00-00") |> MACAddr.is_multicast?
      true
  
  FF-FF-FF-FF-FF-FF is the broadcast address, and is also a multicast address:
  
      iex> MACAddr.parse("FF-FF-FF-FF-FF-FF") |> MACAddr.is_multicast?
      true
  """
  def is_multicast?(addr) do
    <<msb::unsigned-8, _::binary>> = addr
    band(msb, 0x01) == 0x01
  end
  
  @doc """
  Determines if `addr` is a unicast address, based on its I/G bit.
  """
  def is_unicast?(addr) do
    !is_multicast?(addr)
  end
  
  @doc """
  Determines if `addr` is globally unique (OUI enforced), based on its U/L bit.
  
  ## Examples
  
  F4-5C-89-E2-62-94 is a globally unique MAC address:
  
      iex> MACAddr.parse("F4-5C-89-E2-62-94") |> MACAddr.is_globally_unique?
      true
  
  4A-00-05-5A-46-15 is a locally administered MAC address:
  
      iex> MACAddr.parse("01-80-C2-00-00-00") |> MACAddr.is_globally_unique?
      false
  """
  def is_globally_unique?(addr) do
    <<msb::unsigned-8, _::binary>> = addr
    band(msb, 0x02) == 0
  end
  
  @doc """
  Determines if `addr` is locally administered (no OUI), based on its U/L bit.
  """
  def is_locally_administered?(addr) do
    !is_globally_unique?(addr)
  end
  
  @doc """
  Returns the broadcast address, `<<255, 255, 255, 255, 255, 255>>`.
  """
  def broadcast, do: @broadcast_addr
  
  @doc """
  Adds an integer `value` to `addr`, wrapping if necessary.
  
  ## Examples
  
  Grab a random MAC address, add 20, and check the difference:
  
      iex> addr1 = MACAddr.random
      <<122, 67, 52, 228, 207, 143>>
      
      iex> addr2 = MACAddr.add(addr1, 20)
      <<122, 67, 52, 228, 207, 163>>
      
      iex> MACAddr.to_integer(addr2) - MACAddr.to_integer(addr1)
      20
      
  Adding 1 to FF-FF-FF-FF-FF-FF wraps to yield 00-00-00-00-00-00:
  
      iex> addr1 = MACAddr.broadcast
      <<255, 255, 255, 255, 255, 255>>
      
      iex> addr2 = MACAddr.add(addr1, 1)
      <<0, 0, 0, 0, 0, 0>>
      
      iex> MACAddr.to_string(addr2)
      "00-00-00-00-00-00"
  
  """
  def add(addr, value) do
    size = byte_size(addr)
    
    <<int_addr::big-unsigned-size(size)-unit(8)>> = addr
    new_int_addr = int_addr + value
    
    <<new_int_addr::big-unsigned-size(size)-unit(8)>>
  end
  
  @doc """
  Subtracts an integer `value` from `addr`, wrapping if necessary.
  
  ## Examples
  
  Subtracting 1 from 00-00-00-00-00-00 wraps to yield FF-FF-FF-FF-FF-FF:
  
      iex> addr1 = MACAddr.parse("00-00-00-00-00-00")
      <<0, 0, 0, 0, 0, 0>
      
      iex> addr2 = MACAddr.subtract(addr1, 1)
      <<255, 255, 255, 255, 255, 255>>
      
      iex> MACAddr.to_string(addr2)
      "FF-FF-FF-FF-FF-FF"
  
  """
  def subtract(addr, value) do
    add(addr, 0 - value)
  end
  
  @doc """
  Adds 1 to `addr`, wrapping if necessary.
  """
  def succ(addr) do
    add(addr, 1)
  end
  
  @doc """
  Subtracts 1 from `addr`, wrapping if necessary.
  """  
  def pred(addr) do
    subtract(addr, 1)
  end
  
  @doc """
  Defines the sigil `~a` as a wrapper for `MACAddr.parse/1`.
  
  ## Examples
  
      iex> import MACAddr.Sigil
      nil
      
      iex> ~a{15ef.2e91.977a}
      <<21, 239, 46, 145, 151, 122>>
  
  """
  def sigil_a(string, []), do: MACAddr.parse(string)
end
