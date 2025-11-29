#!/usr/bin/env ruby
# Test the impact of enabling caching for Str and Re atoms
# Hypothesis: The original authors disabled caching assuming overhead > benefit
# But in practice, Str/Re are SO FREQUENT that even small cache hits provide huge wins

require 'bundler/setup'
require 'parslet'
require 'benchmark'
require 'ruby-prof'

# Simple JSON parser to test with
class JSONParser < Parslet::Parser
  root :value

  rule(:value) { object | array | string | number | bool | null }

  rule(:object) do
    str('{') >> (pair >> (str(',') >> pair).repeat).maybe >> str('}')
  end

  rule(:pair) do
    string >> str(':') >> value
  end

  rule(:array) do
    str('[') >> (value >> (str(',') >> value).repeat).maybe >> str(']')
  end

  rule(:string) do
    str('"') >> (
      str('\\') >> any |
      str('"').absent? >> any
    ).repeat.as(:string) >> str('"')
  end

  rule(:number) do
    (str('-').maybe >> match('[0-9]').repeat(1) >>
     (str('.') >> match('[0-9]').repeat(1)).maybe).as(:number)
  end

  rule(:bool) { str('true').as(:bool) | str('false').as(:bool) }
  rule(:null) { str('null').as(:null) }

  rule(:space) { match('\s').repeat(1) }
  rule(:space?) { space.maybe }
end

# Test input
json_input = <<~JSON
  {
    "name": "test",
    "age": 42,
    "active": true,
    "items": [1, 2, 3, 4, 5],
    "nested": {
      "key": "value",
      "number": 123
    }
  }
JSON

parser = JSONParser.new

puts "=" * 80
puts "PHASE 44: Testing Str/Re Caching Impact"
puts "=" * 80
puts

# Baseline: Current behavior (Str/Re not cached)
puts "Baseline: Str/Re caching DISABLED (current behavior)"
puts "-" * 80

result = RubyProf.profile(measure_mode: RubyProf::WALL_TIME) do
  10.times { parser.parse(json_input) }
end

printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, min_percent: 1)

baseline_time = result.threads.first.total_time
baseline_cache_calls = result.threads.first.methods.find { |m|
  m.full_name.include?('try_with_cache')
}&.total_time || 0

puts
puts "Baseline total time: #{(baseline_time * 1000).round(2)}ms"
puts "Baseline cache overhead: #{(baseline_cache_calls * 1000).round(2)}ms"
puts

# Now enable caching for Str and Re
puts "=" * 80
puts "Test: Enabling Str/Re caching"
puts "-" * 80

# Monkey-patch to enable caching
module Parslet::Atoms
  class Str
    def cached?
      true  # Enable caching
    end
  end

  class Re
    def cached?
      true  # Enable caching
    end
  end
end

result = RubyProf.profile(measure_mode: RubyProf::WALL_TIME) do
  10.times { parser.parse(json_input) }
end

printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, min_percent: 1)

optimized_time = result.threads.first.total_time
optimized_cache_calls = result.threads.first.methods.find { |m|
  m.full_name.include?('try_with_cache')
}&.total_time || 0

puts
puts "Optimized total time: #{(optimized_time * 1000).round(2)}ms"
puts "Optimized cache overhead: #{(optimized_cache_calls * 1000).round(2)}ms"
puts

# Calculate improvement
puts "=" * 80
puts "RESULTS"
puts "=" * 80
speedup = baseline_time / optimized_time
puts "Speedup: %.2fx" % speedup
puts "Time reduction: %.2f%%" % ((1 - optimized_time/baseline_time) * 100)
puts
puts "Hypothesis: If Str/Re atoms dominate parsing, enabling their cache"
puts "should reduce overall parse attempts and improve performance."
