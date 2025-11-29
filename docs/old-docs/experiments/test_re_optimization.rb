#!/usr/bin/env ruby
# Benchmark Re atom fast paths vs regex

require 'bundler/setup'
require 'parslet'
require 'benchmark'

# Test parsers with common Re patterns
class WhitespaceParser < Parslet::Parser
  rule(:spaces) { match('\s').repeat(1) }
  root(:spaces)
end

class DigitParser < Parslet::Parser
  rule(:number) { match('[0-9]').repeat(1) }
  root(:number)
end

class LetterParser < Parslet::Parser
  rule(:word) { match('[a-zA-Z]').repeat(1) }
  root(:word)
end

class IdentifierParser < Parslet::Parser
  rule(:ident) { match('[a-zA-Z]') >> match('[a-zA-Z0-9_]').repeat }
  root(:ident)
end

# Test inputs
whitespace_input = "    \t\n  "
digit_input = "1234567890"
letter_input = "abcdefghijklmnopqrstuvwxyz"
identifier_input = "hello_world_123"

puts "Re Atom Fast Path Benchmark"
puts "=" * 60
puts

parsers = [
  ["Whitespace (\\s)", WhitespaceParser.new, whitespace_input],
  ["Digits ([0-9])", DigitParser.new, digit_input],
  ["Letters ([a-zA-Z])", LetterParser.new, letter_input],
  ["Identifier ([a-zA-Z][a-zA-Z0-9_]*)", IdentifierParser.new, identifier_input]
]

iterations = 10_000

parsers.each do |name, parser, input|
  puts "Testing: #{name}"
  puts "Input: #{input.inspect} (#{input.length} chars)"

  # Warmup
  3.times { parser.parse(input) }

  # Benchmark
  time = Benchmark.measure do
    iterations.times { parser.parse(input) }
  end

  rate = iterations / time.real

  puts "  Time: #{time.real.round(3)}s for #{iterations} iterations"
  puts "  Rate: #{rate.round(1)} parses/sec"
  puts "  Per parse: #{(time.real * 1000 / iterations).round(3)}ms"
  puts
end

# Memory test - parse 1000 times and check object allocations
puts "Memory Test (1000 parses each):"
puts "-" * 60

parsers.each do |name, parser, input|
  before = GC.stat(:total_allocated_objects)
  1000.times { parser.parse(input) }
  after = GC.stat(:total_allocated_objects)

  allocated = after - before
  puts "#{name}: #{allocated} objects allocated (#{(allocated/1000.0).round(1)} per parse)"
end
