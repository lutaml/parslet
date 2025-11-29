#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'parslet'
require 'benchmark/ips'

# Test Phase 46: Cut Operators and AC-FIRST algorithm
# Measures the impact of automatic cut insertion on:
# 1. Parse time
# 2. Memory usage (cache size)

# Parser with disjoint alternatives (good for cuts)
class KeywordParser < Parslet::Parser
  rule(:keyword) do
    str('if') >> space >> expression |
    str('while') >> space >> expression |
    str('for') >> space >> expression |
    str('print') >> space >> expression |
    str('return') >> space >> expression
  end

  rule(:expression) { match('[a-z]').repeat(1) }
  rule(:space) { str(' ') }

  root(:keyword)
end

# Optimized version with automatic cut insertion
class OptimizedKeywordParser < Parslet::Parser
  optimize_rules!

  rule(:keyword) do
    str('if') >> space >> expression |
    str('while') >> space >> expression |
    str('for') >> space >> expression |
    str('print') >> space >> expression |
    str('return') >> space >> expression
  end

  rule(:expression) { match('[a-z]').repeat(1) }
  rule(:space) { str(' ') }

  root(:keyword)
end

# Test inputs
inputs = [
  'if x',
  'while loop',
  'for item',
  'print value',
  'return result'
]

puts "Phase 46: Cut Operators Benchmark"
puts "=" * 60
puts

# Create parsers
baseline = KeywordParser.new
optimized = OptimizedKeywordParser.new

# Verify both parse correctly
puts "Verification:"
inputs.each do |input|
  baseline_result = baseline.parse(input)
  optimized_result = optimized.parse(input)
  if baseline_result == optimized_result
    puts "  ✓ #{input.inspect} parses identically"
  else
    puts "  ✗ #{input.inspect} MISMATCH!"
    puts "    Baseline:  #{baseline_result.inspect}"
    puts "    Optimized: #{optimized_result.inspect}"
  end
end
puts

# Performance benchmark
puts "Performance Comparison:"
puts "-" * 60

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report("baseline (no cuts)") do
    inputs.each { |input| baseline.parse(input) }
  end

  x.report("optimized (with cuts)") do
    inputs.each { |input| optimized.parse(input) }
  end

  x.compare!
end

puts
puts "=" * 60
puts

# Memory benchmark - measure cache sizes after parsing
puts "Cache Analysis:"
puts "-" * 60

# Helper to count cache entries
def count_cache_entries(parser)
  # Parse to populate cache
  parser.parse('if x')

  # Access the root rule's cache
  root_rule = parser.instance_variable_get(:@root)
  return 0 unless root_rule

  # Try to get context from a parse operation
  begin
    source = Parslet::Source.new('if x')
    context = Parslet::Context.new
    root_rule.apply(source, context, false)
    context.cache.size
  rescue
    0
  end
end

baseline_cache = count_cache_entries(baseline)
optimized_cache = count_cache_entries(optimized)

puts "  Baseline cache entries:  #{baseline_cache}"
puts "  Optimized cache entries: #{optimized_cache}"
if optimized_cache < baseline_cache
  reduction = ((1 - optimized_cache.to_f / baseline_cache) * 100).round(1)
  puts "  Cache reduction: #{reduction}%"
end

puts
puts "Note: Cut operators enable aggressive cache eviction,"
puts "reducing memory usage while maintaining O(n) parse time."
puts
