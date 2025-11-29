#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'objspace'
require_relative 'parsers/pascal_parser'

# Phase 57a: Allocation profiling to identify GC hotspots
# This measures object allocations to guide frozen constant optimizations

class SimpleParser < Parslet::Parser
  rule(:number) { match('[0-9]').repeat(1) }
  rule(:operator) { match('[+\-*/]') }
  rule(:expr) { number >> (operator >> number).repeat }
  root(:expr)
end

parser = SimpleParser.new
input = "1+2*3-4/5+6*7-8/9+10"

puts "Phase 57a: Allocation Profiling"
puts "=" * 70
puts

# Warmup
5.times { parser.parse(input) }

GC.start
GC.disable

before = ObjectSpace.count_objects
before_total = before[:TOTAL]

# Run parsing
iterations = 1000
iterations.times { parser.parse(input) }

after = ObjectSpace.count_objects
after_total = after[:TOTAL]

GC.enable

total_allocated = after_total - before_total
per_parse = total_allocated / iterations

puts "Total iterations: #{iterations}"
puts "Total new objects: #{total_allocated}"
puts "Objects per parse: #{per_parse}"
puts

puts "Breakdown by type:"
puts "-" * 70

types = {}
after.each do |type, count|
  next if type == :TOTAL || type == :FREE
  delta = count - (before[type] || 0)
  types[type] = delta if delta > 0
end

types.sort_by { |_, count| -count }.first(15).each do |type, count|
  percentage = (count.to_f / total_allocated * 100).round(1)
  per_parse_count = count / iterations
  puts "  #{type.to_s.ljust(20)} #{count.to_s.rjust(10)}  (#{percentage}%)  ~#{per_parse_count}/parse"
end

puts
puts "=" * 70
puts "Analysis:"
puts

# Calculate common allocation patterns
arrays_per_parse = types[:T_ARRAY] / iterations rescue 0
strings_per_parse = types[:T_STRING] / iterations rescue 0
hashes_per_parse = types[:T_HASH] / iterations rescue 0

puts "Arrays per parse:  #{arrays_per_parse}"
puts "Strings per parse: #{strings_per_parse}"
puts "Hashes per parse:  #{hashes_per_parse}"
puts

puts "If 50% of arrays are result arrays [success, value]:"
puts "  → #{(arrays_per_parse * 0.5).round} result arrays could use frozen constants"
puts

puts "Next steps:"
puts "1. Profile specific atoms to see which create most arrays"
puts "2. Implement frozen constants for common patterns"
puts "3. Consider object pooling if same objects created repeatedly"
