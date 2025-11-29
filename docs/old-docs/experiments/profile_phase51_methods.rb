#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 51a: Profile method call overhead to identify inlining candidates
#
# This script uses ruby-prof to identify methods with:
# 1. High call counts (called frequently)
# 2. Short execution time per call (simple methods)
# 3. Located in hot paths
#
# These are prime candidates for inlining to reduce method call overhead.

require 'bundler/setup'
require 'parslet'
require 'ruby-prof'
require 'json'

# Test parser: JSON parser (representative workload)
class JSONParser < Parslet::Parser
  root(:value)

  rule(:value) {
    object | array | string | number | true_val | false_val | null_val
  }

  rule(:object) {
    str('{') >> spaces? >>
    (pair >> (str(',') >> spaces? >> pair).repeat).maybe.as(:object) >>
    spaces? >> str('}')
  }

  rule(:pair) {
    string.as(:key) >> spaces? >> str(':') >> spaces? >> value.as(:val)
  }

  rule(:array) {
    str('[') >> spaces? >>
    (value >> (str(',') >> spaces? >> value).repeat).maybe.as(:array) >>
    spaces? >> str(']')
  }

  rule(:string) {
    str('"') >> (
      str('\\') >> any |
      str('"').absent? >> any
    ).repeat.as(:string) >> str('"')
  }

  rule(:number) {
    (str('-').maybe >> match('[1-9]') >> match('[0-9]').repeat |
     str('0')).as(:integer) >>
    (str('.') >> match('[0-9]').repeat(1)).maybe >>
    (match('[eE]') >> match('[+-]').maybe >> match('[0-9]').repeat(1)).maybe
  }

  rule(:true_val)  { str('true').as(:true) }
  rule(:false_val) { str('false').as(:false) }
  rule(:null_val)  { str('null').as(:null) }

  rule(:spaces)    { match('\s').repeat(1) }
  rule(:spaces?)   { spaces.maybe }
end

# Use simple inline JSON for testing
input = '{"name":"test","value":123,"items":[1,2,3],"nested":{"a":"b","c":true}}'
parser = JSONParser.new

puts "=" * 80
puts "Phase 51a: Method Call Overhead Profiling"
puts "=" * 80
puts
puts "Input size: #{input.bytesize} bytes"
puts "Parser: JSONParser"
puts

# Warmup
puts "Warming up..."
3.times { parser.parse(input) }

# Profile with call graph
puts "Profiling method calls..."
result = RubyProf.profile do
  10.times { parser.parse(input) }
end

# Generate analysis
puts
puts "=" * 80
puts "Method Call Analysis"
puts "=" * 80
puts

# Focus on Parslet code only
printer = RubyProf::FlatPrinter.new(result)
output = StringIO.new
printer.print(output, min_percent: 0.1)

# Parse output to find high-call-count methods
lines = output.string.split("\n")
parslet_methods = []

lines.each do |line|
  next unless line.include?('Parslet::')

  # Extract: %self  total  self  wait  child  calls  name
  parts = line.split
  next if parts.length < 6

  calls = parts[-2].to_i
  self_time = parts[2].to_f
  name = parts[-1]

  # Focus on simple methods (low self time but high calls)
  if calls > 10_000 && self_time < 1.0
    avg_time = (self_time / calls * 1_000_000).round(3)
    parslet_methods << {
      name: name,
      calls: calls,
      self_time: self_time,
      avg_microseconds: avg_time
    }
  end
end

# Sort by call count
parslet_methods.sort_by! { |m| -m[:calls] }

puts "High-frequency simple methods (>10k calls, <1s total):"
puts
puts "%-60s %12s %12s %12s" % ["Method", "Calls", "Total (s)", "Avg (μs)"]
puts "-" * 100

parslet_methods.first(20).each do |m|
  puts "%-60s %12d %12.3f %12.3f" % [
    m[:name],
    m[:calls],
    m[:self_time],
    m[:avg_microseconds]
  ]
end

# Identify top inlining candidates
puts
puts "=" * 80
puts "Top Inlining Candidates"
puts "=" * 80
puts

candidates = parslet_methods.select do |m|
  m[:calls] > 50_000 && m[:avg_microseconds] < 5.0
end

if candidates.empty?
  puts "No strong candidates found (need >50k calls and <5μs avg time)"
  puts "Method call overhead may not be significant for this workload."
else
  candidates.first(10).each_with_index do |m, i|
    puts "#{i + 1}. #{m[:name]}"
    puts "   - Calls: #{m[:calls].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "   - Avg time: #{m[:avg_microseconds]}μs"
    puts "   - Potential savings: #{(m[:calls] * 0.1).round}ns (if 10% overhead)"
    puts
  end
end

# Save detailed report
report_file = File.join(__dir__, 'PHASE51a_METHOD_PROFILING.txt')
File.open(report_file, 'w') do |f|
  f.puts "Phase 51a: Method Call Overhead Profiling"
  f.puts "=" * 80
  f.puts
  f.puts "Date: #{Time.now}"
  f.puts "Input: Simple JSON test case"
  f.puts "Size: #{input.bytesize} bytes"
  f.puts "Runs: 10"
  f.puts
  f.puts "=" * 80
  f.puts "All High-Frequency Methods"
  f.puts "=" * 80
  f.puts

  parslet_methods.each do |m|
    f.puts m[:name]
    f.puts "  Calls: #{m[:calls]}"
    f.puts "  Total: #{m[:self_time]}s"
    f.puts "  Average: #{m[:avg_microseconds]}μs"
    f.puts
  end

  f.puts "=" * 80
  f.puts "Recommendations"
  f.puts "=" * 80
  f.puts

  if candidates.empty?
    f.puts "No strong inlining candidates found."
    f.puts "Method call overhead appears to be minimal for this workload."
    f.puts
    f.puts "Recommendation: Skip method inlining, try Phase 51b (instance variable caching)."
  else
    f.puts "Top #{[candidates.length, 5].min} candidates for inlining:"
    f.puts
    candidates.first(5).each_with_index do |m, i|
      f.puts "#{i + 1}. #{m[:name]}"
      f.puts "   Calls: #{m[:calls]}"
      f.puts "   Avg: #{m[:avg_microseconds]}μs"
    end
  end
end

puts "Detailed report saved to: #{report_file}"
puts
puts "Next steps:"
if candidates.empty?
  puts "1. Review report to confirm method call overhead is minimal"
  puts "2. Proceed to Phase 51b (instance variable caching) instead"
else
  puts "1. Review report and identify specific methods to inline"
  puts "2. Create baseline benchmark before inlining"
  puts "3. Inline methods incrementally"
  puts "4. Benchmark after each change"
  puts "5. Keep only beneficial changes"
end
