# frozen_string_literal: true

require 'stringio'
require 'strscan'

require 'parslet/position'
require 'parslet/source/line_cache'

module Parslet
  # Wraps the input string for parslet.
  #
  class Source
    def initialize(str)
      raise(
        ArgumentError,
        "Must construct Source with a string like object."
      ) unless str.respond_to?(:to_str)

      @str = StringScanner.new(str)

      # maps 1 => /./m, 2 => /../m, etc...
      @re_cache = Hash.new { |h,k|
        h[k] = /(.|$){#{k}}/m }

      @line_cache = LineCache.new
      @line_cache.scan_for_line_endings(0, str)
    end

    # Checks if the given pattern matches at the current input position.
    #
    # @param pattern [Regexp] pattern to check for
    # @return [Boolean] true if the pattern matches at #pos
    #
    def matches?(pattern)
      @str.match?(pattern)
    end
    alias match matches?

    # Consumes n characters from the input, returning them as a slice of the
    # input.
    #
    def consume(n)
      bytepos = self.bytepos
      slice_str = @str.scan(@re_cache[n])
      slice = Parslet::Slice.new(
        bytepos,
        slice_str,
        @line_cache)

      return slice
    end

    # Returns how many chars remain in the input.
    #
    def chars_left
      @str.rest_size
    end

    # Returns how many chars there are between current position and the
    # string given. If the string given doesn't occur in the source, then
    # the remaining chars (#chars_left) are returned.
    #
    # @return [Fixnum] count of chars until str or #chars_left
    #
    def chars_until str
      slice_str = @str.check_until(Regexp.new(Regexp.escape(str)))
      return chars_left unless slice_str
      return slice_str.size - str.size
    end

    # Phase 31: Scan forward to find the next occurrence of a character.
    # Returns the byte position of the next occurrence, or nil if not found.
    # Does not move the scanner position.
    #
    # @param char [String] single character to search for
    # @return [Integer, nil] byte position or nil if not found
    #
    def index_of_char(char)
      # Use StringScanner's string directly for fast indexOf
      idx = @str.rest.index(char)
      return nil unless idx
      @str.pos + idx
    end

    # Position of the parse as a byte offset into the original string.
    # Returns an integer byte position instead of a Position object.
    #
    # @return [Integer] Current byte position in the input
    # @note Please be aware of encodings at this point.
    #
    def pos
      @str.pos
    end

    # Alias for pos - returns the current byte position.
    # Provided for clarity and backward compatibility.
    #
    # @return [Integer] Current byte position in the input
    #
    alias bytepos pos

    # @note Please be aware of encodings at this point.
    #
    def bytepos=(n)
      @str.pos = n
    rescue RangeError
    end

    # Returns a <line, column> tuple for the given position. If no position is
    # given, line/column information is returned for the current position
    # given by #pos.
    #
    def line_and_column(position=nil)
      @line_cache.line_and_column(position || self.bytepos)
    end
    
  end
end
