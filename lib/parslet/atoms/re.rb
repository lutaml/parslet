# frozen_string_literal: true

# Matches a special kind of regular expression that only ever matches one
# character at a time. Useful members of this family are: <code>character
# ranges, \\w, \\d, \\r, \\n, ...</code>
#
# Example:
#
#   match('[a-z]')  # matches a-z
#   match('\s')     # like regexps: matches space characters
#
class Parslet::Atoms::Re < Parslet::Atoms::Base
  attr_reader :match, :re
  def initialize(match)
    super()

    @match = match.to_s
    @re    = Regexp.new(self.match, Regexp::MULTILINE)

    # Phase 60: Pre-compute and freeze error messages
    @error_msgs = {
      premature: 'Premature end of input'.freeze,
      failed: "Failed to match #{match.inspect[1..-2]}".freeze
    }.freeze
  end

  def try(source, context, consume_all)
    # Phase 55: Cache @re ivar to reduce lookup overhead
    re = @re
    return succ(source.consume(1)) if source.matches?(re)

    # No string could be read
    return context.err(self, source, @error_msgs[:premature]) \
      if source.chars_left < 1

    # No match
    return context.err(self, source, @error_msgs[:failed])
  end

  def to_s_inner(prec)
    match.inspect[1..-2]
  end

  # Regex matching is already very fast (single character match).
  # Caching adds overhead without benefit for such simple operations.
  def cached?
    false
  end

  # Session 13: Re always produces flat results (Parslet::Slice)
  # No nested structures, so flatten can skip processing
  def flat?
    true
  end

  # FIRST set for Re is the regex itself
  # Conservative: could theoretically analyze regex to extract literal prefixes
  def compute_first_set
    Set.new([self])
  end
end
