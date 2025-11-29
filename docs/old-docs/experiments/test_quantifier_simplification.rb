#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
require 'parslet'
require 'benchmark'

include Parslet

# Test parsers with redundant quantifiers
class RedundantParser < Parslet::Parser
  rule(:redundant) {
    # Lots of repeat(1,1) that should be simplified
    str('a').repeat(1, 1) >>
    str('b').repeat(1, 1) >>
    str('c').repeat(1, 1) >>
    str('d').repeat(1, 1) >>
    str('e').repeat(1, 1)
  }

  rule(:nested_maybe) {
    # repeat(0,1).repeat(0,1) should flatten to repeat(0,1)
    str('x').repeat(0, 1).repeat(0, 1) >>
    str('y').repeat(0, 1).repeat(0, 1) >>
    str('z').repeat(0, 1).repeat(0, 1)
  }

  rule(:exact_counts) {
    # repeat(2,2).repeat(3,3) should become repeat(6,6)
    str('m').repeat(2, 2).repeat(3, 3) >>
    str('n').repeat(3, 3).repeat(2, 2)
  }

  root :redundant
end

# Optimized version
class OptimizedParser < Parslet::Parser
  rule(:redundant) {
    optimized = str('a').repeat(1, 1) >>
                str('b').repeat(1, 1) >>
                str('c').repeat(1, 1) >>
                str('d').repeat(1, 1) >>
                str('e').repeat(1, 1)
    Parslet::Optimizer.simplify_quantifiers(optimized)
  }

  rule(:nested_maybe) {
    optimized = str('x').repeat(0, 1).repeat(0, 1) >>
                str('y').repeat(0, 1).repeat(0, 1) >>
                str('z').repeat(0, 1).repeat(0, 1)
    Parslet::Optimizer.simplify_quantifiers(optimized)
  }

  rule(:exact_counts) {
    optimized = str('m').repeat(2, 2).repeat(3, 3) >>
                str('n').repeat(3, 3).repeat(2, 2)
    Parslet::Optimizer.simplify_quantifiers(optimized)
  }

  root :redundant
end

puts "Phase 32: Quantifier Simplification Benchmark"
puts "=" * 60

# Test data - single match patterns
test_inputs = {
  redundant: 'abcde',
  nested_maybe: 'xyz',
  exact_counts: 'm' * 6 + 'n' * 6
}

redundant_parser = RedundantParser.new
optimized_parser = OptimizedParser.new

# Warmup
5.times do
  redundant_parser.parse(test_inputs[:redundant])
  optimized_parser.parse(test_inputs[:redundant])
end

n = 1000
puts "\nTest input: #{test_inputs[:redundant].length} chars"
puts "Iterations: #{n}"
puts

Benchmark.bm(20) do |x|
  x.report("Redundant (before):") do
    n.times { redundant_parser.parse(test_inputs[:redundant]) }
  end

  x.report("Optimized (after):") do
    n.times { optimized_parser.parse(test_inputs[:redundant]) }
  end
end

puts "\n" + "=" * 60
puts "Verifying semantic equivalence..."

test_inputs.each do |name, input|
  redundant = RedundantParser.new.send(name).parse(input)
  optimized = OptimizedParser.new.send(name).parse(input)

  if redundant == optimized
    puts "✓ #{name}: Results match"
  else
    puts "✗ #{name}: Results differ!"
    puts "  Redundant: #{redundant.inspect}"
    puts "  Optimized: #{optimized.inspect}"
  end
end

puts "\n" + "=" * 60
puts "Optimization effects:"
puts

# Count atoms before and after
def count_atoms(parslet, type)
  count = parslet.is_a?(type) ? 1 : 0

  case parslet
  when Parslet::Atoms::Sequence
    count + parslet.parslets.sum { |p| count_atoms(p, type) }
  when Parslet::Atoms::Repetition
    count + count_atoms(parslet.parslet, type)
  when Parslet::Atoms::Alternative
    count + parslet.alternatives.sum { |p| count_atoms(p, type) }
  else
    count
  end
end

original = str('a').repeat(1, 1) >> str('b').repeat(1, 1) >> str('c').repeat(1, 1)
simplified = Parslet::Optimizer.simplify_quantifiers(original)

puts "Original repetitions: #{count_atoms(original, Parslet::Atoms::Repetition)}"
puts "Simplified repetitions: #{count_atoms(simplified, Parslet::Atoms::Repetition)}"
puts "Reduction: #{((1 - count_atoms(simplified, Parslet::Atoms::Repetition).to_f / count_atoms(original, Parslet::Atoms::Repetition)) * 100).round(1)}%"
