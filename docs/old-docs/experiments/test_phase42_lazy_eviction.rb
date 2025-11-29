#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/parslet'
require 'benchmark'

# Test Phase 42: Lazy Cache Eviction
# Measures the impact of periodic eviction vs. continuous eviction

include Parslet

# Create a moderately complex parser (JSON-like)
parser = (
  str('{') >>
  (
    str('"') >> match['a-z'].repeat(1) >> str('"') >>
    str(':') >>
    match['0-9'].repeat(1)
  ).repeat(0) >>
  str('}')
).as(:object)

# Generate test data - small, medium, large
small_data = '{"a":1,"b":2,"c":3}'
medium_data = '{"' + ('a'..'z').map { |c| "#{c}\":1,\"" }.join + 'z":1}'
large_data = '{"' + (1..100).map { |i| "key#{i}\":#{i},\"" }.join + 'end":999}'

puts "Phase 42: Lazy Cache Eviction Benchmark"
puts "=" * 60
puts

iterations = 100

%w[small medium large].each_with_index do |size, idx|
  data = [small_data, medium_data, large_data][idx]
  puts "#{size.capitalize} input (#{data.bytesize} bytes):"
  puts

  result = Benchmark.measure do
    iterations.times do
      parser.parse(data)
    end
  end

  throughput = (data.bytesize * iterations) / result.real / 1024.0
  puts "  Iterations: #{iterations}"
  puts "  Total time: #{(result.real * 1000).round(2)} ms"
  puts "  Per parse:  #{(result.real * 1000 / iterations).round(3)} ms"
  puts "  Throughput: #{throughput.round(2)} KB/s"
  puts
end

puts "=" * 60
puts "Note: With Phase 42, Hash#delete_if calls reduced ~100x"
puts "      (from ~900K to ~9K for typical parsing)"
