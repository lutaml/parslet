# Either positive or negative lookahead, doesn't consume its input.
#
# Example:
#
#   str('foo').present? # matches when the input contains 'foo', but leaves it
#
class Parslet::Atoms::Lookahead < Parslet::Atoms::Base
  attr_reader :positive
  attr_reader :bound_parslet

  def initialize(bound_parslet, positive=true)
    super()

    # Model positive and negative lookahead by testing this flag.
    @positive = positive
    @bound_parslet = bound_parslet
  end

  def error_msgs
    @error_msgs ||= {
      :positive => ["Input should start with ", bound_parslet],
      :negative => ["Input should not start with ", bound_parslet]
    }
  end

  def try(source, context, consume_all)
    rewind_pos = source.bytepos

    success, _ = bound_parslet.apply(source, context, consume_all)

    # Fast path: success case for positive lookahead (most common)
    if positive
      if success
        source.bytepos = rewind_pos
        return succ(nil)
      end
      # Error case - need position for error reporting
      source.bytepos = rewind_pos
      return context.err_at(self, source, error_msgs[:positive], source.pos)
    else
      if success
        source.bytepos = rewind_pos
        return context.err_at(self, source, error_msgs[:negative], source.pos)
      end
      source.bytepos = rewind_pos
      return succ(nil)
    end
  end

  precedence LOOKAHEAD
  def to_s_inner(prec)
    @char = positive ? '&' : '!'

    "#{@char}#{bound_parslet.to_s(prec)}"
  end
end
