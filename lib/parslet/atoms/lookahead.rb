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
    # Phase 23: Lookahead position restore optimization
    # Always restore position after lookahead, simplify logic
    rewind_pos = source.bytepos

    success, _ = bound_parslet.apply(source, context, consume_all)

    # Always restore position - lookahead never consumes input
    source.bytepos = rewind_pos

    # Positive lookahead: success when parslet matches
    return succ(nil) if positive && success
    return context.err_at(self, source, error_msgs[:positive], source.pos) if positive

    # Negative lookahead: success when parslet fails
    return context.err_at(self, source, error_msgs[:negative], source.pos) if success
    return succ(nil)
  end

  precedence LOOKAHEAD
  def to_s_inner(prec)
    @char = positive ? '&' : '!'

    "#{@char}#{bound_parslet.to_s(prec)}"
  end
end
