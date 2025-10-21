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
    self.class.new(* @parslets+[parslet])
  end

  def try(source, context, consume_all)
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
