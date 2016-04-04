defmodule MACAddr do
  @moduledoc """
  Functions for working with IEEE 802 MAC addresses.
  
  ## Representation
  
  MACAddr represents MAC addresses and Organizationally Unique Identifiers (OUIs) as 24- and 48-bit binaries, respectively. Except where noted, MAC addresses and OUIs can be used interchangeably throughout the module:
  
      iex> addr = MACAddr.parse("C0-91-34-0B-DE-D4")
      <<192, 145, 52, 11, 222, 212>>
      iex> MACAddr.to_string(addr)
      "C0-91-34-0B-DE-D4"
      
      iex> oui = MACAddr.parse("C0-91-34")
      <<192, 145, 52>>
      iex> MACAddr.to_string(oui)
      "C0-91-34"
  
  ## Organizationally Unique Identifiers

  MAC addresses can be administered universally or locally. A universally administered address is assigned to a device by its manufacturer, and the most significant half of the address constitutes an organizationally unique identifier (OUI), identifying the manufacturer. For example, 00-15-9A-68-99-3A is a universally administered address. 00-15-9A is its OUI, and identifies the manufacturer as Arris Group, Inc.
  
  A locally administered address is typically assigned to a device by its administrator, and the most significant half of the address doesn't constitute an OUI. AE-F5-01-9B-2E-5B is a locally administered address, and AE-F5-01 has no specific meaning as a whole.
  
  A MAC address is identified as universal or local by its Universal/Local (U/L) bit, which is the second-least significant bit of its most significant byte. If the U/L bit is 0, the address is universally administered; if it's 1, the address is locally administered.
  
  Functions like `MACAddr.oui/1` and `MACAddr.is_local?/1` distinguish between universally and locally administered addresses, but you can still work with any 24-bit value as though it were an OUI:
  
      iex> addr = MACAddr.parse("AE-F5-01-9B-2E-5B")
      <<174, 245, 1, 155, 46, 91>>
      iex> upper_half = MACAddr.most_significant_24_bits(addr)
      <<174, 245, 1>>
      iex> MACAddr.to_string(upper_half)
      "AE-F5-01"
  
  """
  
  use Bitwise

  @broadcast_addr <<0xFFFFFFFFFFFF::big-unsigned-48>>
  
  @doc """
  Splits `addr` into a list of integers, each representing a `chunk_size` (8-, 16-, or 24-) bit chunk of the address.
  
  ## Examples
  
  Let's grab a MAC address, and split it into chunks:
  
      iex> addr = MACAddr.parse("15-EF-2E-91-97-7A")
      <<21, 239, 46, 145, 151, 122>>
      iex> MACAddr.split(addr, 8)
      [21, 239, 46, 145, 151, 122]
      iex> MACAddr.split(addr, 16)
      [5615, 11921, 38778]
      iex> MACAddr.split(addr, 24)
      [1437486, 9541498]
      
  **Note:** We can't split an OUI or other 24-bit value evenly into 16-bit chunks, so this won't work:
      
      iex> "FF-FF-FF"|> MACAddr.parse |> MACAddr.split(16)
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
  
  Let's make up a MAC address, and format it as zero-paded, uppercase hex words, separated with spaces:
  
      iex> addr = MACAddr.parse("AB-8F-04-97-2C-A8")
      <<171, 143, 4, 151, 44, 168>>
      iex> MACAddr.format(addr, 16, fn(word) ->
      ...>   word
      ...>     |> Integer.to_string(16)
      ...>     |> String.rjust(4, ?0)
      ...> end, " ")
      "AB8F 0497 2CA8"
      
  Let's make up another MAC address. We'll format this one based on the as_Sun() method from Perl's Net/MAC.pm:
  
      iex> addr = MACAddr.parse("3B-B5-4E-42-72-03")
      <<59, 181, 78, 66, 114, 3>>
      iex> MACAddr.format(addr, 8, fn(byte) ->
      ...>   byte
      ...>     |> Integer.to_string(16)
      ...>     |> String.downcase
      ...> end, ":")
      "3b:b5:4e:42:72:3"
      
  You're well on your way to becoming a Solaris admin. Great job!
      
  """
  def format(addr, chunk_size, chunk_formatter, separator \\ "") do
    addr
      |> split(chunk_size)
      |> Enum.map_join(separator, chunk_formatter)
  end

  defp format_padded_hex(addr, chunk_size, separator \\ "") do
    padding = div(chunk_size, 4)
    format(addr, chunk_size, fn(chunk) ->
      chunk
        |> Integer.to_string(16)
        |> String.rjust(padding, ?0)
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
      
  **Note:** Cisco style doesn't work for OUIs or other 24-bit values:
  
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
      raise ArgumentError, "expected a 48-bit MAC address or 24-bit OUI"
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
  Generates a random MAC address with the specified binary as the upper half.
  
  ## Examples
    
      iex> oui = MACAddr.parse("00-CD-FE")
      <<0, 205, 254>>
      iex> addr = MACAddr.random(oui)
      <<0, 205, 254, 109, 252, 6>>
      iex> MACAddr.to_string(addr)
      "00-CD-FE-6D-FC-06"
  """
  def random(upper_half) do
    upper_half <> :crypto.strong_rand_bytes(3)
  end
  
  @doc """
  Parses `string` as a MAC address in the specified format. The default is `:hex`.
  
  Available formats are:
  - `:hex`
  - `:dotted_decimal`
  
  ## Parsing as Hex
  
  Extracts hex digits from `string`, converts the hex digits to an integer, and converts the integer to a MAC address. Expects 6 or 12 hex digits.
  
  ## Examples
  
  Parsing a Cisco-formatted MAC address:
  
      iex> MACAddr.parse("15ef.2e91.977a", :hex)        
      <<21, 239, 46, 145, 151, 122>>
      
  Parsing an IEEE-formatted OUI:
  
      iex> MACAddr.parse("F4-5C-89")
      <<244, 92, 137>>
      
  You don't have to worry about inadvertently copying tabs and spaces:
  
      iex> MACAddr.parse("\\t00-CD-FE-6D-FC-06 ")
      <<0, 205, 254, 109, 252, 6>>
      
  If this function can't find `addr` or OUI in the string, you'll get an ArgumentError:
  
      iex> MACAddr.parse("Hideous anecdote", :hex)
      ** (ArgumentError) expected a 6- or 12-digit hex string
          (macaddr) lib/macaddr.ex:205: MACAddr.parse/1
         
  …but it errs on the side of leniency:
      
      iex> oui = MACAddr.parse("ventral beeswax", :hex)
      <<234, 190, 234>>
      iex> MACAddr.to_string(oui)
      "EA-BE-EA"
  
  ## Parsing as Dotted Decimal
  
  Expects a `string` with 3 or 6 decimal numbers from 0-255, separated by periods, like `"116.4.63"`, or `"116.4.63.132.41.82"`.
  
  ## Examples
  
  Parse a MAC address as dotted decimal:
  
      iex> addr = MACAddr.parse("116.4.63.132.41.82", :dotted_decimal)
      <<116, 4, 63, 132, 41, 82>>
      iex> MACAddr.to_string(addr)
      "74-04-3F-84-29-52"
      
  """
  def parse(string, format \\ :hex) do
    do_parse(string, format)
  end
  defp do_parse(string, :hex) do
    hex = String.replace(string, ~r/[^0-9a-f]/i, "")
    
    num_digits = String.length(hex)
    unless num_digits == 6 or num_digits == 12 do
      raise ArgumentError, "expected a 6- or 12-digit hex string"
    end
    
    hex
      |> String.to_integer(16)
      |> from_integer(num_digits * 4)
  end
  defp do_parse(string, :dotted_decimal) do
    lexer_result = string
      |> String.to_char_list 
      |> :dotted_decimal_lexer.string
      
    case lexer_result do
      {:ok, tokens, _} ->
        {:ok, bytes} = :dotted_decimal_parser.parse(tokens)
    
        unless length(bytes) == 3 or length(bytes) == 6 do
          raise ArgumentError, "expected 3 or 6 decimal numbers; #{string} contains #{length(bytes)}"
        end
    
        unless Enum.all?(bytes, &(&1 <= 255)) do
          raise ArgumentError, "#{string} contains a byte with a value greater than 255"
        end
    
        :erlang.list_to_binary(bytes)
      {:error, {_, _, {:illegal, char}}, _} ->
        raise ArgumentError, "#{string} contains an illegal character, '#{IO.inspect(char)}'"
    end
  end
  defp do_parse(string, :oid) do
    do_parse(string, :dotted_decimal)
  end
  
  @doc """
  Extracts the most significant 24 bits of `addr`.
  
  ## Examples
  
      iex> addr = MACAddr.parse("15-EF-2E-91-97-7A")
      <<21, 239, 46, 145, 151, 122>>
      iex> upper_half = MACAddr.most_significant_24_bits(addr)
      <<21, 239, 46>>
      iex> MACAddr.to_string(upper_half)
      "15-EF-2E"
  """
  def most_significant_24_bits(addr) do
    <<oui::binary-3, _::binary>> = addr
    oui
  end
  
  @doc """
  If `addr` is universally administered, returns its OUI. Otherwise, returns `nil`.
  
  ## Examples
  
  Get the OUI of a universally administered address:
  
      iex> oui = "15-EF-2E-91-97-7A" |> MACAddr.parse |> MACAddr.oui
      <<21, 239, 46>>
      iex> MACAddr.to_string(oui)
      "15-EF-2E"
      
  Try to get the OUI of a locally administered address:
  
      iex> "0B-EA-17-08-CD-31" |> MACAddr.parse |> MACAddr.oui
      nil
  """
  def oui(addr) do
    if is_universal?(addr) do
      most_significant_24_bits(addr)
    end
  end
  
  @doc """
  Determines if `addr` is equal to the broadcast address.
  
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
  
  Is F4-5C-89-E2-62-94 a multicast address?
  
      iex> "F4-5C-89-E2-62-94" |> MACAddr.parse |> MACAddr.is_multicast?
      false
  
  Is 01-80-C2-00-00-00 a multicast address?
  
      iex> "01-80-C2-00-00-00" |> MACAddr.parse |> MACAddr.is_multicast?
      true
  
  Is the broadcast address a multicast address?
  
      iex> MACAddr.broadcast |> MACAddr.is_multicast?
      true
  """
  def is_multicast?(addr) do
    ig_bit(addr) == 1
  end
  
  @doc """
  Determines if `addr` is a unicast address, based on its I/G bit.
  """
  def is_unicast?(addr) do
    ig_bit(addr) == 0
  end
  
  @doc """
  The value of `addr`'s I/G bit. If its I/G bit is 0, `addr` is a unicast address. Otherwise, `addr` is a multicast address.
  
  ## Examples
  
      iex> addr = MACAddr.parse("F4-5C-89-E2-62-94")
      <<244, 92, 137, 226, 98, 148>>
      iex> MACAddr.ig_bit(addr) == 0 and MACAddr.is_unicast?(addr)
      true
  """
  def ig_bit(addr) do
    <<msb::unsigned-8, _::binary>> = addr
    band(msb, 0x01)
  end
  
  @doc """
  The value of `addr`'s U/L bit. If its U/L bit is 0, `addr` is a universally administered address. Otherwise, `addr` is a locally administered address.
  
  ## Examples
  
      iex> addr = MACAddr.parse("F4-5C-89-E2-62-94")
      <<244, 92, 137, 226, 98, 148>>
      iex> MACAddr.ul_bit(addr) == 0 and MACAddr.is_universal?(addr)
      true
  """
  def ul_bit(addr) do
    <<msb::unsigned-8, _::binary>> = addr
    msb
      |> band(0x02)
      |> bsl(2)
  end
  
  @doc """
  Determines if `addr` is universally administered, based on its U/L bit.
  
  ## Examples
  
  Is F4-5C-89-E2-62-94 universally administered?
  
      iex> "F4-5C-89-E2-62-94"|> MACAddr.parse |> MACAddr.is_universal?
      true
  
  Is 4A-00-05-5A-46-15 universally administered?
  
      iex> "4A-00-05-5A-46-15" |> MACAddr.parse |> MACAddr.is_universal?
      false
  """
  def is_universal?(addr) do
    ul_bit(addr) == 0
  end

  @doc """
  Determines if `addr` is locally administered, based on its U/L bit.
  """
  def is_local?(addr) do
    ul_bit(addr) == 1
  end
  
  @doc """
  Returns the broadcast address:
  
      iex> MACAddr.broadcast |> MACAddr.to_string
      "FF-FF-FF-FF-FF-FF"
  
  """
  def broadcast, do: @broadcast_addr
  
  @doc """
  Adds an integer `value` to `addr`, wrapping if necessary.
  
  ## Examples
  
  Grab a MAC address, add 20, and check the difference:
  
      iex> addr1 = MACAddr.parse("7A-43-34-E4-CF-8F")
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
      <<0, 0, 0, 0, 0, 0>>
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
  Wraps `MACAddr.parse/1`, making it more convenient to specify an address:
  
  ## Examples
  
  Parse a hex string as a MAC address:
  
      iex> import MACAddr
      nil
      iex> ~a(15ef.2e91.977a)
      <<21, 239, 46, 145, 151, 122>>
      
  You can use the 'd' modifier to parse dotted decimal formatted addresses:
      
      iex> import MACAddr
      nil
      iex> ~a(21.239.46.145.151.122)d
      <<21, 239, 46, 145, 151, 122>>
  
  """
  def sigil_a(string, ''),  do: MACAddr.parse(string)
  def sigil_a(string, 'h'), do: MACAddr.parse(string, :hex)
  def sigil_a(string, 'd'), do: MACAddr.parse(string, :dotted_decimal)
end
