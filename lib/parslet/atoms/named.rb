# frozen_string_literal: true

# Names a match to influence tree construction.
#
# Example:
#
#   str('foo')            # will return 'foo',
#   str('foo').as(:foo)   # will return :foo => 'foo'
#
class Parslet::Atoms::Named < Parslet::Atoms::Base
  attr_reader :parslet, :name
  def initialize(parslet, name)
    super()

    @parslet, @name = parslet, name
  end

  def apply(source, context, consume_all)
    # Phase 52: Cache @parslet ivar to reduce lookup overhead
    parslet = @parslet

    success, value = result = parslet.apply(source, context, consume_all)

    return result unless success
    succ(
      produce_return_value(
        value))
  end

  # Named is just a thin wrapper that delegates to the underlying parslet.
  # The underlying parslet is already cached, so caching the wrapper is redundant.
  def cached?
    false
  end

  def to_s_inner(prec)
    "#{name}:#{parslet.to_s(prec)}"
  end

  # FIRST set of named atom is same as wrapped parslet
  # Named is just a wrapper that doesn't change matching behavior
  def compute_first_set
    parslet.first_set
  end

private
  def produce_return_value(val)
    { name => flatten(val, true) }
  end
end
