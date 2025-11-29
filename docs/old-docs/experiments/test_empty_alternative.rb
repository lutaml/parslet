#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/parslet'
require 'benchmark'

include Parslet

# Test current behavior with empty alternatives
puts "Testing empty alternative behavior..."
puts

# Test 1: Empty string in alternative
parser1 = str('') | str('a')
puts "Test 1: str('') | str('a')"
puts "  Result on 'a': #{parser1.parse('a').inspect}"
puts "  Result on '': #{parser1.parse('').inspect}"
puts "  AST: #{parser1.inspect}"
puts

# Test 2: Multiple alternatives with empty
parser2 = str('a') | str('') | str('b')
puts "Test 2: str('a') | str('') | str('b')"
puts "  Result on 'a': #{parser2.parse('a').inspect}"
puts "  Result on 'b': #{parser2.parse('b').inspect}"
puts "  Result on '': #{parser2.parse('').inspect}"
puts "  AST: #{parser2.inspect}"
puts

# Test 3: All empty alternatives
parser3 = str('') | str('') | str('')
puts "Test 3: str('') | str('') | str('')"
puts "  Result on '': #{parser3.parse('').inspect}"
puts "  AST: #{parser3.inspect}"
puts

# Test 4: Empty string only
parser4 = str('')
puts "Test 4: str('')"
puts "  Result on '': #{parser4.parse('').inspect}"
puts "  AST: #{parser4.inspect}"
puts

# Test optimization impact
puts "=" * 60
puts "Testing optimization..."
puts

original = str('') | str('a') | str('b') | str('c')
optimized = Parslet::Optimizer.optimize_all(original)

puts "Original: #{original.inspect}"
puts "Optimized: #{optimized.inspect}"
puts

# Benchmark
n = 100_000
input = 'b'

puts "Benchmarking (#{n} iterations, input='#{input}'):"
Benchmark.bm(15) do |x|
  x.report("Original:") { n.times { original.parse(input) } }
  x.report("Optimized:") { n.times { optimized.parse(input) } }
end
