# frozen_string_literal: true

# Base class for all parslets, handles orchestration of calls and implements
# a lot of the operator and chaining methods.
#
# Also see Parslet::Atoms::DSL chaining parslet atoms together.
#
class Parslet::Atoms::Base
  include Parslet::Atoms::Precedence
  include Parslet::Atoms::DSL
  include Parslet::Atoms::CanFlatten
  include Parslet::FirstSet

  # Parslet label as provided in grammar
  attr_accessor :label

  # Phase 61: Frozen error message for unknown input
  ERROR_UNKNOWN_INPUT = "Don't know what to do with ".freeze

  # Given a string or an IO object, this will attempt a parse of its contents
  # and return a result. If the parse fails, a Parslet::ParseFailed exception
  # will be thrown.
  #
  # @param io [String, Source] input for the parse process
  # @option options [Parslet::ErrorReporter] :reporter error reporter to use,
  #   defaults to Parslet::ErrorReporter::Tree
  # @option options [Boolean] :prefix Should a prefix match be accepted?
  #   (default: false)
  # @return [Hash, Array, Parslet::Slice] PORO (Plain old Ruby object) result
  #   tree
  #
  def parse(io, options={})
    source = io.respond_to?(:line_and_column) ?
      io :
      Parslet::Source.new(io)

    # Try to cheat. Assuming that we'll be able to parse the input, don't
    # run error reporting code.
    success, value = setup_and_apply(source, nil, !options[:prefix])

    # If we didn't succeed the parse, raise an exception for the user.
    # Stack trace will be off, but the error tree should explain the reason
    # it failed.
    unless success
      # Cheating has not paid off. Now pay the cost: Rerun the parse,
      # gathering error information in the process.
      reporter = options[:reporter] || Parslet::ErrorReporter::Tree.new
      source.bytepos = 0
      success, value = setup_and_apply(source, reporter, !options[:prefix])

      fail "Assertion failed: success was true when parsing with reporter" \
        if success

      # Value is a Parslet::Cause, which can be turned into an exception:
      value.raise

      fail "NEVER REACHED"
    end

    # assert: success is true

    # Extra input is now handled inline with the rest of the parsing. If
    # really we have success == true, prefix: false and still some input
    # is left dangling, that is a BUG.
    if !options[:prefix] && source.chars_left > 0
      fail "BUG: New error strategy should not reach this point."
    end

    return flatten(value)
  end

  # Creates a context for parsing and applies the current atom to the input.
  # Returns the parse result.
  #
  # @return [<Boolean, Object>] Result of the parse. If the first member is
  #   true, the parse has succeeded.
  def setup_and_apply(source, error_reporter, consume_all)
    # Session 13: Pass parser class for per-parser cache threshold selection
    # If self is a Parser instance, pass its class for threshold lookup
    parser_class = self.is_a?(Parslet::Parser) ? self.class : nil
    context = Parslet::Atoms::Context.new(error_reporter, parser_class: parser_class)
    apply(source, context, consume_all)
  end

  # Calls the #try method of this parslet. Success consumes input, error will
  # rewind the input.
  #
  # @param source [Parslet::Source] source to read input from
  # @param context [Parslet::Atoms::Context] context to use for the parsing
  # @param consume_all [Boolean] true if the current parse must consume
  #   all input by itself.
  def apply(source, context, consume_all=false)
    old_pos = source.bytepos

    success, _ = result = context.try_with_cache(self, source, consume_all)

    if success
      # Notify context
      context.succ(source)
      # If a consume_all parse was made and doesn't result in the consumption
      # of all the input, that is considered an error.
      if consume_all && source.chars_left>0
        # Read 10 characters ahead. Why ten? I don't know.
        offending_pos   = source.bytepos
        offending_input = source.consume(10)

        # Rewind input (as happens always in error case)
        source.bytepos  = old_pos

        return context.err_at(
          self,
          source,
          ERROR_UNKNOWN_INPUT + offending_input.to_s.inspect,
          offending_pos
        )
      end

      # Looks like the parse was successful after all. Don't rewind the input.
      return result
    end

    # We only reach this point if the parse has failed. Rewind the input.
    source.bytepos = old_pos
    return result
  end

  # Override this in your Atoms::Base subclasses to implement parsing
  # behaviour.
  #
  def try(source, context, consume_all)
    raise NotImplementedError, \
      "Atoms::Base doesn't have behaviour, please implement #try(source, context)."
  end

  # Returns true if this atom can be cached in the packrat cache. Most parslet
  # atoms are cached, so this always returns true, unless overridden.
  #
  def cached?
    true
  end

  # Returns true if this atom produces flat results by construction
  # (no nested arrays/hashes that need flattening). This allows flatten
  # to skip processing for atoms that are known to produce simple values.
  #
  # Session 13: Flatten optimization to reduce 5.27% overhead
  # Atoms like Str and Re always produce strings (Parslet::Slice),
  # which don't need flattening.
  #
  # @return [Boolean] true if results are flat by construction
  def flat?
    false  # Default: assume needs flattening
  end

  # Debug printing - in Treetop syntax.
  #
  def self.precedence(prec)
    define_method(:precedence) { prec }
  end
  precedence BASE
  def to_s(outer_prec=OUTER)
    str = label || to_s_inner(precedence)
    if outer_prec < precedence
      "(#{str})"
    else
      str
    end
  end
  def inspect
    to_s(OUTER)
  end
private

  # Produces an instance of Success and returns it.
  #
  # Phase 57a-57b: Frozen constants for common result patterns to reduce allocations.
  # These constants are used extensively in hot paths to avoid creating new arrays.
  #
  SUCCESS_NIL = [true, nil].freeze

  # Common patterns for repetition results with empty values
  # Format: [true, [tag]] where tag is the repetition marker
  # Pre-allocated for common tags to avoid array creation
  EMPTY_ARRAY = [].freeze

  # Phase 57b: Additional frozen constants for tagged empty arrays
  # These are common in repetitions that match 0 times (.maybe, .repeat(0,n))
  EMPTY_REPETITION_ARRAY = [:repetition].freeze
  SUCCESS_EMPTY_REPETITION = [true, EMPTY_REPETITION_ARRAY].freeze

  EMPTY_SEQUENCE_ARRAY = [:sequence].freeze
  SUCCESS_EMPTY_SEQUENCE = [true, EMPTY_SEQUENCE_ARRAY].freeze

  # Phase 57c: Additional frozen constants for common patterns
  EMPTY_HASH = {}.freeze
  SUCCESS_EMPTY_HASH = [true, EMPTY_HASH].freeze

  # Common single-element arrays for captures and tags
  EMPTY_CAPTURE_ARRAY = [:capture].freeze
  SUCCESS_EMPTY_CAPTURE = [true, EMPTY_CAPTURE_ARRAY].freeze

  def succ(result)
    return SUCCESS_NIL if result.nil?
    # Check for empty array (common in repetitions with 0 matches)
    return [true, EMPTY_ARRAY] if result.equal?(EMPTY_ARRAY)
    # Check for empty hash (common in named captures with no matches)
    return SUCCESS_EMPTY_HASH if result.equal?(EMPTY_HASH)
    # Check for common tagged empty arrays
    return SUCCESS_EMPTY_REPETITION if result.equal?(EMPTY_REPETITION_ARRAY)
    return SUCCESS_EMPTY_SEQUENCE if result.equal?(EMPTY_SEQUENCE_ARRAY)
    return SUCCESS_EMPTY_CAPTURE if result.equal?(EMPTY_CAPTURE_ARRAY)
    [true, result]
  end
end
