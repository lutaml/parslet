
# Alternative during matching. Contains a list of parslets that is tried each
# one in turn. Only fails if all alternatives fail.
#
# Example:
#
#   str('a') | str('b')   # matches either 'a' or 'b'
#
class Parslet::Atoms::Alternative < Parslet::Atoms::Base
  attr_reader :alternatives

  # Constructs an Alternative instance using all given parslets in the order
  # given. This is what happens if you call '|' on existing parslets, like
  # this:
  #
  #   str('a') | str('b')
  #
  def initialize(*alternatives)
    super()

    @alternatives = alternatives
  end

  #---
  # Don't construct a hanging tree of Alternative parslets, instead store them
  # all here. This reduces the number of objects created.
  #+++
  def |(parslet)
    # Phase 25: Alternative Flattening (similar to Phase 21 for Sequence)
    # Flatten nested alternatives: (A | B) | C becomes Alternative(A, B, C)
    # instead of Alternative(Alternative(A, B), C)
    new_alts = if parslet.is_a?(Parslet::Atoms::Alternative)
      @alternatives + parslet.alternatives
    else
      @alternatives + [parslet]
    end
    self.class.new(*new_alts)
  end

  def error_msg
    @error_msg ||= "Expected one of #{alternatives.inspect}"
  end

  def try(source, context, consume_all)
    # Fast paths for common alternative sizes (avoid iteration overhead)
    case alternatives.size
    when 2
      success, value = alternatives[0].apply(source, context, consume_all)
      return [success, value] if success
      success2, value2 = alternatives[1].apply(source, context, consume_all)
      return [success2, value2] if success2
      return context.err(self, source, error_msg, [value, value2])
    when 3
      success, value = alternatives[0].apply(source, context, consume_all)
      return [success, value] if success
      success2, value2 = alternatives[1].apply(source, context, consume_all)
      return [success2, value2] if success2
      success3, value3 = alternatives[2].apply(source, context, consume_all)
      return [success3, value3] if success3
      return context.err(self, source, error_msg, [value, value2, value3])
    end

    # General case: Optimize by not allocating error array until we know all alternatives fail
    # This saves significant allocation overhead when early alternatives succeed
    errors = nil

    alternatives.each do |a|
      success, value = result = a.apply(source, context, consume_all)
      return result if success

      # Lazily allocate errors array only if needed
      errors ||= []
      errors << value
    end

    # If we reach this point, all alternatives have failed.
    context.err(self, source, error_msg, errors)
  end

  precedence ALTERNATE
  def to_s_inner(prec)
    alternatives.map { |a| a.to_s(prec) }.join(' / ')
  end
end
