#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'parslet'
require 'json'
require 'benchmark'

# Simple JSON parser
class JSONParser < Parslet::Parser
  rule(:value) { object | array | string | number | true_val | false_val | null_val | whitespace.repeat }
  rule(:object) { str('{') >> whitespace.maybe >> (pair >> (str(',') >> pair).repeat).maybe >> whitespace.maybe >> str('}') }
  rule(:pair) { string >> whitespace.maybe >> str(':') >> whitespace.maybe >> value }
  rule(:array) { str('[') >> whitespace.maybe >> (value >> (str(',') >> value).repeat).maybe >> whitespace.maybe >> str(']') }
  rule(:string) { str('"') >> (str('\\') >> any | str('"').absent? >> any).repeat.as(:string) >> str('"') }
  rule(:number) { (str('-').maybe >> match('[0-9]').repeat(1) >> (str('.') >> match('[0-9]').repeat(1)).maybe).as(:number) }
  rule(:true_val) { str('true').as(:true) }
  rule(:false_val) { str('false').as(:false) }
  rule(:null_val) { str('null').as(:null) }
  rule(:whitespace) { match('\s').repeat(1) }
  root(:value)
end

# Test data - complex nested JSON that exercises flattening heavily
json_data = {
  "users" => (1..50).map { |i|
    {
      "id" => i,
      "name" => "User #{i}",
      "email" => "user#{i}@example.com",
      "tags" => ["tag1", "tag2", "tag3"],
      "metadata" => {
        "created" => "2025-01-01",
        "updated" => "2025-01-15"
      }
    }
  }
}.to_json

parser = JSONParser.new

puts "Phase 43: CanFlatten Optimization Test"
puts "=" * 70
puts

# Warmup
3.times { parser.parse(json_data) }

# Benchmark
iterations = 100
time = Benchmark.measure do
  iterations.times do
    parser.parse(json_data)
  end
end

avg_time = (time.real * 1000 / iterations).round(2)

puts "Parsed #{iterations} times"
puts "Average time: #{avg_time}ms per parse"
puts
puts "This test exercises:"
puts "- flatten() on deeply nested structures"
puts "- flatten_repetition() on arrays of objects"
puts "- merge_fold() on object key-value pairs"
puts
puts "Expected improvements:"
puts "- Single-element fast path reduces overhead"
puts "- Cached instance_of? checks reduce method calls"
puts "- Single-pass hash/array detection in repetitions"
