# Matches a string of characters.
#
# Example:
#
#   str('foo') # matches 'foo'
#
class Parslet::Atoms::Str < Parslet::Atoms::Base
  attr_reader :str
  def initialize(str)
    super()

    @str = str.to_s
    @len = str.size

    # Optimize: For single-character strings, store the character directly
    # to avoid regex matching overhead
    if @len == 1
      @char = @str
      @pat = nil
    else
      @pat = Regexp.new(Regexp.escape(str))
      @char = nil
    end
  end

  def error_msgs
    @error_msgs ||= {
      premature: 'Premature end of input',
      failed: "Expected #{str.inspect}, but got "
    }
  end

  def try(source, context, consume_all)
    # Fast path for single-character strings (very common in parsers)
    # Avoids regex matching overhead
    if @char
      return context.err(self, source, error_msgs[:premature]) if source.chars_left < 1

      error_pos = source.pos  # Save position before consuming
      slice = source.consume(1)
      return succ(slice) if slice.str == @char

      # Failed to match - restore position and report error
      source.bytepos = error_pos.bytepos
      return context.err_at(self, source, [error_msgs[:failed], slice], error_pos)
    end

    # Multi-character string: use direct string comparison instead of regex
    # This is faster than regex matching for literal strings
    return context.err(self, source, error_msgs[:premature]) if source.chars_left < @len

    error_pos = source.pos
    slice = source.consume(@len)

    # Direct string comparison (much faster than regex)
    return succ(slice) if slice.str == @str

    # Failed to match - restore position and report error
    source.bytepos = error_pos.bytepos
    return context.err_at(self, source, [error_msgs[:failed], slice], error_pos)
  end

  def to_s_inner(prec)
    "'#{str}'"
  end

  # String matching is already very fast (regex match).
  # Caching adds overhead without benefit for such simple operations.
  def cached?
    false
  end
end
