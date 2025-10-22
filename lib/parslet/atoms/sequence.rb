# A sequence of parslets, matched from left to right. Denoted by '>>'
#
# Example:
#
#   str('a') >> str('b')  # matches 'a', then 'b'
#
class Parslet::Atoms::Sequence < Parslet::Atoms::Base
  attr_reader :parslets
  def initialize(*parslets)
    super()

    @parslets = parslets
  end

  def error_msgs
    @error_msgs ||= {
      failed: "Failed to match sequence (#{inspect})"
    }
  end

  def >>(parslet)
    # Phase 21: Sequence Flattening
    # Flatten nested sequences to reduce object creation and tree depth
    # (A >> B) >> C becomes Sequence(A, B, C) instead of Sequence(Sequence(A, B), C)
    if parslet.is_a?(Parslet::Atoms::Sequence)
      self.class.new(* @parslets + parslet.parslets)
    else
      self.class.new(* @parslets + [parslet])
    end
  end

  def try(source, context, consume_all)
    # Fast paths for common sequence sizes (avoid Array.new allocation)
    case parslets.size
    when 1
      success, value = parslets[0].apply(source, context, consume_all)
      return success ? succ([:sequence, value]) : context.err(self, source, error_msgs[:failed], [value])
    when 2
      success, v1 = parslets[0].apply(source, context, false)
      return context.err(self, source, error_msgs[:failed], [v1]) unless success
      success, v2 = parslets[1].apply(source, context, consume_all)
      return success ? succ([:sequence, v1, v2]) : context.err(self, source, error_msgs[:failed], [v2])
    when 3
      success, v1 = parslets[0].apply(source, context, false)
      return context.err(self, source, error_msgs[:failed], [v1]) unless success
      success, v2 = parslets[1].apply(source, context, false)
      return context.err(self, source, error_msgs[:failed], [v2]) unless success
      success, v3 = parslets[2].apply(source, context, consume_all)
      return success ? succ([:sequence, v1, v2, v3]) : context.err(self, source, error_msgs[:failed], [v3])
    end

    # General case for longer sequences
    # Optimize: Use simple integer loop instead of each_with_index
    # This avoids the overhead of iterator methods and block calls
    result = Array.new(parslets.size + 1)
    result[0] = :sequence

    last_idx = parslets.size - 1
    i = 0
    while i <= last_idx
      child_consume_all = consume_all && (i == last_idx)
      success, value = parslets[i].apply(source, context, child_consume_all)

      unless success
        return context.err(self, source, error_msgs[:failed], [value])
      end

      result[i+1] = value
      i += 1
    end

    return succ(result)
  end

  precedence SEQUENCE
  def to_s_inner(prec)
    parslets.map { |p| p.to_s(prec) }.join(' ')
  end
end
