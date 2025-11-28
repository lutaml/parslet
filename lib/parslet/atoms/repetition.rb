# frozen_string_literal: true


# Matches a parslet repeatedly.
#
# Example:
#
#   str('a').repeat(1,3)  # matches 'a' at least once, but at most three times
#   str('a').maybe        # matches 'a' if it is present in the input (repeat(0,1))
#
class Parslet::Atoms::Repetition < Parslet::Atoms::Base
  attr_reader :min, :max, :parslet
  def initialize(parslet, min, max, tag=:repetition)
    super()

    raise ArgumentError,
      "Asking for zero repetitions of a parslet. (#{parslet.inspect} repeating #{min},#{max})" \
      if max == 0

    @parslet = parslet
    @min = min
    @max = max
    @tag = tag

    # Phase 58: Pre-compute and freeze error messages to avoid allocations
    @error_msgs = {
      minrep: "Expected at least #{min} of #{parslet.inspect}".freeze,
      unconsumed: 'Extra input after last repetition'.freeze
    }.freeze
  end

  def error_msgs
    @error_msgs
  end

  def try(source, context, consume_all)
    # Phase 54: Cache ivars to reduce lookup overhead in hot method
    parslet = @parslet
    min = @min
    max = @max
    tag = @tag

    # Use tree memoization if interval cache is enabled
    if context.respond_to?(:use_tree_memoization?) && context.use_tree_memoization?
      return try_with_tree_memoization(source, context, consume_all)
    end

    # Fast path for .maybe (min=0, max=1) - very common case
    if min == 0 && max == 1
      success, value = parslet.apply(source, context, false)
      return succ([tag, value]) if success
      # Phase 57b: Use frozen constant for empty repetition array
      return succ(tag == :repetition ? Parslet::Atoms::Base::EMPTY_REPETITION_ARRAY : [tag])
    end

    # Fast path for exact count (min == max)
    if min == max && max && max <= 3
      case max
      when 1
        success, value = parslet.apply(source, context, consume_all)
        return success ? succ([tag, value]) : context.err_at(self, source, error_msgs[:minrep], source.pos, [value])
      when 2
        success, v1 = parslet.apply(source, context, false)
        return context.err_at(self, source, error_msgs[:minrep], source.pos, [v1]) unless success
        success, v2 = parslet.apply(source, context, consume_all)
        return success ? succ([tag, v1, v2]) : context.err_at(self, source, error_msgs[:minrep], source.pos, [v2])
      when 3
        success, v1 = parslet.apply(source, context, false)
        return context.err_at(self, source, error_msgs[:minrep], source.pos, [v1]) unless success
        success, v2 = parslet.apply(source, context, false)
        return context.err_at(self, source, error_msgs[:minrep], source.pos, [v2]) unless success
        success, v3 = parslet.apply(source, context, consume_all)
        return success ? succ([tag, v1, v2, v3]) : context.err_at(self, source, error_msgs[:minrep], source.pos, [v3])
      end
    end

    # General case for variable or large repetitions
    try_repetition_general(source, context, consume_all)
  end

  # GPeg-style tree memoization for repetitions
  # Caches arrays of successful matches to reuse parsed prefixes
  def try_with_tree_memoization(source, context, consume_all)
    start_pos = source.bytepos
    cache_key = object_id

    # Check if we have a cached tree result at this position
    cached = context.query_tree_memo(cache_key, start_pos)
    if cached
      values, end_pos = cached
      source.bytepos = end_pos
      return succ([@tag] + values)
    end

    # Parse repetition and collect all successful matches
    occ = 0
    accum = []
    positions = [start_pos]  # Track position after each match
    break_on = nil

    loop do
      pos_before = source.bytepos
      success, value = parslet.apply(source, context, false)

      break_on = value
      break unless success

      occ += 1
      accum << value
      positions << source.bytepos

      # Check max bound
      break if max && occ >= max
    end

    # Store tree memo: cache the array of successful matches
    # This allows reusing the parsed prefix on subsequent parses
    if occ > 0
      end_pos = positions[occ]
      context.store_tree_memo(cache_key, start_pos, accum.dup, end_pos)
    end

    # Check min bound
    if occ < min
      source.bytepos = start_pos
      return context.err_at(
        self,
        source,
        error_msgs[:minrep],
        start_pos,
        [break_on])
    end

    # Check consume_all requirement
    if consume_all && source.chars_left > 0
      return context.err(
        self,
        source,
        error_msgs[:unconsumed],
        [break_on])
    end

    return succ([@tag] + accum)
  end

  # General repetition parsing (extracted for clarity)
  def try_repetition_general(source, context, consume_all)
    occ = 0
    # Optimize: Pre-allocate array when max is known to avoid repeated expansions
    accum = max ? Array.new(max + 1) : [@tag]
    accum[0] = @tag if max
    start_pos = source.pos

    break_on = nil
    loop do
      success, value = parslet.apply(source, context, false)

      break_on = value
      break unless success

      occ += 1
      if max
        accum[occ] = value
        # If we're not greedy (max is defined), check if that has been reached.
        return succ(accum) if occ >= max
      else
        accum << value
      end
    end

    # Last attempt to match parslet was a failure, failure reason in break_on.

    # Greedy matcher has produced a failure. Check if occ (which will
    # contain the number of successes) is >= min.
    return context.err_at(
      self,
      source,
      error_msgs[:minrep],
      start_pos,
      [break_on]) if occ < min

    # consume_all is true, that means that we're inside the part of the parser
    # that should consume the input completely. Repetition failing here means
    # probably that we didn't.
    #
    # We have a special clause to create an error here because otherwise
    # break_on would get thrown away. It turns out, that contains very
    # interesting information in a lot of cases.
    #
    return context.err(
      self,
      source,
      error_msgs[:unconsumed],
      [break_on]) if consume_all && source.chars_left>0

    return succ(accum)
  end

  precedence REPETITION
  def to_s_inner(prec)
    minmax = "{#{min}, #{max}}"
    minmax = '?' if min == 0 && max == 1

    parslet.to_s(prec) + minmax
  end

  # FIRST set of repetition:
  # - If min == 0 (can match empty), includes EPSILON
  # - Always includes FIRST of the repeated parslet
  def compute_first_set
    result = parslet.first_set.dup
    # If repetition can match zero times, add EPSILON
    result.add(Parslet::FirstSet::EPSILON) if min == 0
    result
  end
end
