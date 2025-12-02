# frozen_string_literal: true
# A slice is a small part from the parse input. A slice mainly behaves like
# any other string, except that it remembers where it came from (offset in
# original input).
#
# == Extracting line and column
#
# Using the #line_and_column method, you can extract the line and column in
# the original input where this slice starts.
#
# Example:
#   slice.line_and_column # => [1, 13]
#   slice.offset          # => 12
#
# == Likeness to strings
#
# Parslet::Slice behaves in many ways like a Ruby String. This likeness
# however is not complete - many of the myriad of operations String supports
# are not yet in Slice. You can always extract the internal string instance by
# calling #to_s.
#
# These omissions are somewhat intentional. Rather than maintaining a full
# delegation, we opt for a partial emulation that gets the job done.
#
class Parslet::Slice
  attr_reader :str, :line_cache

  # Construct a slice using an integer byte position, a string, and an optional line cache.
  # The line cache should be able to answer to the #line_and_column message.
  #
  # @param bytepos [Integer] Byte position in the original input
  # @param string [String] The slice content
  # @param line_cache [Object] Optional line cache for line/column info
  #
  def initialize(bytepos, string, line_cache = nil)
    @bytepos = bytepos
    @str = string
    @line_cache = line_cache
  end

  # Create a Slice from a Rope.
  # The rope is converted to a string and used to create the slice.
  #
  # @param rope [Parslet::Rope] The rope to convert
  # @param bytepos [Integer] Byte position in the input
  # @param line_cache [Object] Optional line cache for line/column info
  # @return [Parslet::Slice] A new slice with the rope's content
  #
  def self.from_rope(rope, bytepos, line_cache = nil)
    new(bytepos, rope.to_s, line_cache)
  end

  # Returns the byte position of this slice in the original input.
  # This is the primary position tracking mechanism.
  #
  def offset
    @bytepos
  end

  # Alias for offset - returns byte position.
  # For backward compatibility and clarity.
  #
  alias bytepos offset

  # Alias for offset - returns byte position.
  # Note: For ASCII text, bytepos == charpos.
  # For UTF-8, this is an approximation (byte position, not character position).
  #
  alias charpos offset

  # Compares slices to other slices or strings.
  # Fast path: Compare strings directly, most common case
  #
  def ==(other)
    # Fast path: direct string comparison
    return str == other if other.is_a?(String)
    # Slice to Slice comparison
    return str == other.str if other.is_a?(Parslet::Slice)
    str == other
  end

  # Type-strict equality comparison.
  # This only returns true for Slice-to-Slice comparison with equal content.
  #
  def eql?(other)
    other.is_a?(Parslet::Slice) && str.eql?(other.str)
  end

  # Hash code for using Slices as hash keys.
  # Incorporates both the string content and position to distinguish
  # Slices from plain Strings and from Slices at different positions.
  #
  def hash
    [str, offset].hash
  end

  # Match regular expressions.
  #
  def match(regexp)
    str.match(regexp)
  end

  # Returns the slices size in characters.
  #
  def size
    str.size
  end

  alias length size

  # Concatenate two slices; it is assumed that the second slice begins
  # where the first one ends. The offset of the resulting slice is the same
  # as the one of this slice.
  #
  def +(other)
    self.class.new(@bytepos, str + other.to_s, line_cache)
  end

  # Returns a <line, column> tuple referring to the original input.
  # LineCache expects an integer byte position.
  #
  def line_and_column
    raise ArgumentError, 'No line cache was given, cannot infer line and column.' \
      unless line_cache

    line_cache.line_and_column(@bytepos)
  end

  # Conversion operators -----------------------------------------------------
  def to_str
    str
  end
  alias to_s to_str

  def to_slice
    self
  end

  def to_sym
    str.to_sym
  end

  def to_i
    self.str.to_i
  end

  def to_f
    str.to_f
  end

  # Inspection & Debugging ---------------------------------------------------

  # Prints the slice as <code>"string"@offset</code>.
  def inspect
    str.inspect + "@#{offset}"
  end
end
