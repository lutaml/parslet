#!/usr/bin/env ruby

require 'bundler/setup'
require_relative '../lib/parslet'

# Profile Position object creation frequency
# This will help us determine if object pooling is worthwhile

class PositionTracker
  attr_reader :creation_count, :class_counts

  def initialize
    @creation_count = 0
    @class_counts = Hash.new(0)
    @enabled = false
  end

  def enable
    @enabled = true
    @creation_count = 0
    @class_counts.clear
  end

  def disable
    @enabled = false
  end

  def track(klass)
    return unless @enabled
    @creation_count += 1
    @class_counts[klass.name] += 1
  end

  def report
    puts "\n" + "=" * 80
    puts "Position Object Creation Analysis"
    puts "=" * 80
    puts "\nTotal Position-like objects created: #{@creation_count}"
    puts "\nBreakdown by class:"
    @class_counts.sort_by { |k, v| -v }.each do |klass, count|
      percentage = (count.to_f / @creation_count * 100).round(1)
      puts "  #{klass}: #{count} (#{percentage}%)"
    end
  end
end

$position_tracker = PositionTracker.new

# Monkey-patch Position to track creation
module Parslet
  class Position
    alias_method :original_initialize, :initialize

    def initialize(*args)
      $position_tracker.track(self.class)
      original_initialize(*args)
    end
  end
end

# Test parsers
class SimpleParser < Parslet::Parser
  rule(:value) { str('"') >> (str('"').absent? >> any).repeat >> str('"') }
  rule(:pair) { value.as(:key) >> str(':') >> value.as(:val) }
  rule(:object) { str('{') >> pair >> str('}') }
  root(:object)
end

class NestedParser < Parslet::Parser
  rule(:spaces) { match('\s').repeat(1) }
  rule(:spaces?) { spaces.maybe }

  rule(:value) {
    str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"') |
    str('[') >> spaces? >> array_items >> spaces? >> str(']') |
    object
  }

  rule(:pair) {
    spaces? >>
    str('"') >> match('[^"]').repeat.as(:key) >> str('"') >>
    spaces? >> str(':') >> spaces? >>
    value.as(:val)
  }

  rule(:array_items) {
    (value >> (spaces? >> str(',') >> spaces? >> value).repeat).maybe
  }

  rule(:object) {
    str('{') >> spaces? >>
    (pair >> (spaces? >> str(',') >> spaces? >> pair).repeat).maybe >>
    spaces? >> str('}')
  }

  root(:object)
end

class ArrayHeavyParser < Parslet::Parser
  rule(:spaces?) { match('\s').repeat }

  rule(:value) {
    str('"') >> match('[^"]').repeat.as(:string) >> str('"') |
    match('[0-9]').repeat(1).as(:number)
  }

  rule(:array) {
    str('[') >> spaces? >>
    (value >> (spaces? >> str(',') >> spaces? >> value).repeat).maybe >>
    spaces? >> str(']')
  }

  root(:array)
end

# Test inputs
SIMPLE_INPUT = '{"key":"value"}'
NESTED_INPUT = '{"a":"1","b":["2","3"]}'
ARRAY_INPUT = '["a","b","c","d","e","f","g","h","i","j"]'

puts "Ruby Version: #{RUBY_VERSION}"
puts "Testing Position object creation patterns..."
puts

# Test each parser
parsers = [
  ['Simple', SimpleParser.new, SIMPLE_INPUT],
  ['Nested', NestedParser.new, NESTED_INPUT],
  ['Array Heavy', ArrayHeavyParser.new, ARRAY_INPUT]
]

parsers.each do |name, parser, input|
  puts "\n" + "-" * 80
  puts "Testing: #{name} (#{input.bytesize} bytes)"
  puts "-" * 80

  # Warm up
  3.times { parser.parse(input) }

  # Track creation during actual parsing
  $position_tracker.enable

  # Parse 100 times to get statistical data
  iterations = 100
  iterations.times { parser.parse(input) }

  $position_tracker.disable

  puts "\nPosition objects created per parse: #{$position_tracker.creation_count / iterations}"
  puts "Total for #{iterations} parses: #{$position_tracker.creation_count}"

  $position_tracker.report
end

puts "\n" + "=" * 80
puts "Analysis Summary"
puts "=" * 80
puts <<~ANALYSIS

The profiling data above shows:

1. How many Position objects are created per parse
2. The distribution of Position-like object types
3. Whether object pooling could reduce allocations

Decision Criteria:
- If >50 Position objects per parse: Strong candidate for pooling
- If >100 Position objects per parse: Very strong candidate
- If <20 Position objects per parse: Pooling may not be worth complexity

GC Impact:
- More allocations = more GC pressure
- Pooling reduces allocations but adds complexity
- Must benchmark actual performance impact

Next Steps:
1. Analyze these numbers
2. If promising, implement a simple Position pool
3. Benchmark performance with/without pooling
4. Accept only if >5% improvement
ANALYSIS
