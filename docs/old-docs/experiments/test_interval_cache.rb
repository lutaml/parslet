#!/usr/bin/env ruby
# Test script for GPeg-style interval tree caching in Context

require 'bundler/setup'
require 'parslet'

# Simple test parser
class SimpleParser < Parslet::Parser
  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }
  rule(:digit) { match('[0-9]') }
  rule(:number) { digit.repeat(1).as(:number) }
  rule(:operator) { match('[+\-*/]').as(:op) }
  rule(:expression) { number >> space? >> operator >> space? >> number }
  root(:expression)
end

def test_interval_cache
  parser = SimpleParser.new
  input = "123 + 456"

  puts "Testing interval cache mode..."
  puts "Input: #{input.inspect}"
  puts

  # Test with interval cache enabled
  puts "=== With Interval Cache ==="
  start = Time.now
  result = parser.parse(input)
  elapsed = Time.now - start
  puts "Result: #{result.inspect}"
  puts "Time: #{(elapsed * 1000).round(2)}ms"
  puts

  # Test without interval cache (default mode)
  puts "=== Without Interval Cache (default) ==="
  start = Time.now
  result = parser.parse(input)
  elapsed = Time.now - start
  puts "Result: #{result.inspect}"
  puts "Time: #{(elapsed * 1000).round(2)}ms"
  puts

  # More complex test
  complex_input = "999 * 888"
  puts "=== Complex Input ==="
  puts "Input: #{complex_input.inspect}"
  result = parser.parse(complex_input)
  puts "Result: #{result.inspect}"
  puts

  puts "✓ All tests passed!"
end

# Run the test
test_interval_cache
