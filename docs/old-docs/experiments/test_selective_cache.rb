#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/parslet'
require 'benchmark'

# Simple JSON parser for benchmarking
class JSONParser < Parslet::Parser
  rule(:space)      { match['\s'].repeat }
  rule(:space?)     { space.maybe }

  rule(:string) {
    str('"') >>
    (
      str('\\') >> any |
      str('"').absent? >> any
    ).repeat.as(:string) >>
    str('"')
  }

  rule(:number) {
    (
      str('-').maybe >>
      match['0-9'].repeat(1) >>
      (str('.') >> match['0-9'].repeat(1)).maybe
    ).as(:number)
  }

  rule(:value) {
    string | number | object | array |
    str('true').as(:true) | str('false').as(:false) | str('null').as(:null)
  }

  rule(:array) {
    str('[') >> space? >>
    (value >> (space? >> str(',') >> space? >> value).repeat).maybe.as(:array) >>
    space? >> str(']')
  }

  rule(:pair) {
    string.as(:key) >> space? >> str(':') >> space? >> value.as(:val)
  }

  rule(:object) {
    str('{') >> space? >>
    (pair >> (space? >> str(',') >> space? >> pair).repeat).maybe.as(:object) >>
    space? >> str('}')
  }

  root(:value)
end

# Generate test JSON
def generate_json(depth, breadth)
  if depth == 0
    return ['"value"', '123', 'true', 'false', 'null'].sample
  end

  if rand < 0.5
    # Generate array
    elements = (1..breadth).map { generate_json(depth - 1, breadth) }
    "[#{elements.join(',')}]"
  else
    # Generate object
    pairs = (1..breadth).map do |i|
      "\"key#{i}\":#{generate_json(depth - 1, breadth)}"
    end
    "{#{pairs.join(',')}}"
  end
end

puts "=" * 70
puts "SELECTIVE MEMOIZATION BENCHMARK"
puts "=" * 70
puts

# Generate test data
json = generate_json(3, 4)
puts "Test data size: #{json.bytesize} bytes"
puts

parser = JSONParser.new

# Warmup
puts "Warming up..."
3.times { parser.parse(json) }
puts "✓ Warmup complete"
puts

# Benchmark
iterations = 50
puts "Running #{iterations} iterations..."
puts

time = Benchmark.realtime do
  iterations.times do
    parser.parse(json)
  end
end

avg_time = (time / iterations * 1000).round(2)
puts "Results:"
puts "  Total time: #{time.round(3)}s"
puts "  Average time per parse: #{avg_time}ms"
puts "  Throughput: #{(iterations / time).round(1)} parses/sec"
puts

puts "=" * 70
puts "DONE"
puts "=" * 70
