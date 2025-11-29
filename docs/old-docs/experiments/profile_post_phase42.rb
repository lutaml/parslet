#!/usr/bin/env ruby
# Profile parser performance after Phase 42 to find next bottlenecks
# Phase 42 eliminated Hash#delete_if (22.47%) - what's the new hot spot?

require 'bundler/setup'
require 'parslet'
require 'ruby-prof'

# Use the JSON parser from Phase 42 benchmarks
class JSONParser < Parslet::Parser
  root :value

  rule(:value) { object | array | string | number | bool | null }

  rule(:object) do
    str('{') >> space? >>
    (pair >> (space? >> str(',') >> space? >> pair).repeat).maybe >>
    space? >> str('}')
  end

  rule(:pair) do
    string >> space? >> str(':') >> space? >> value
  end

  rule(:array) do
    str('[') >> space? >>
    (value >> (space? >> str(',') >> space? >> value).repeat).maybe >>
    space? >> str(']')
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

# Load test file
json_input = File.read('benchmark/fixtures/json/large_structure.json')
parser = JSONParser.new

puts "=" * 80
puts "POST-PHASE 42 PROFILING"
puts "=" * 80
puts "Input size: #{json_input.bytesize} bytes"
puts "Profiling with ruby-prof (wall_time)..."
puts

# Profile the parser
result = RubyProf::Profile.profile(measure_mode: RubyProf::WALL_TIME) do
  5.times { parser.parse(json_input) }
end

# Print flat profile
puts "=" * 80
puts "FLAT PROFILE (Top 30 methods by %self)"
puts "=" * 80
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, min_percent: 0.5)

puts
puts "=" * 80
puts "ANALYSIS"
puts "=" * 80

total_time = result.threads.first.total_time
puts "Total time: #{(total_time * 1000).round(2)}ms"
puts

# Find top methods
methods = result.threads.first.methods.sort_by { |m| -m.self_time }
top_10 = methods.first(10)

puts "Top 10 hot spots:"
top_10.each_with_index do |method, i|
  pct = (method.self_time / total_time * 100)
  puts "#{i+1}. #{method.full_name}"
  puts "   %self: #{pct.round(2)}%, calls: #{method.total_calls}, self_time: #{(method.self_time * 1000).round(2)}ms"
end

puts
puts "=" * 80
puts "NEXT OPTIMIZATION TARGET"
puts "=" * 80

# Identify the new bottleneck
top_method = top_10.first
top_pct = (top_method.self_time / total_time * 100)

if top_pct > 15
  puts "CLEAR BOTTLENECK: #{top_method.full_name} at #{top_pct.round(1)}%"
  puts "This is the next optimization target."
elsif top_pct > 10
  puts "MODERATE HOT SPOT: #{top_method.full_name} at #{top_pct.round(1)}%"
  puts "Worth investigating for optimization."
elsif top_pct > 5
  puts "MINOR HOT SPOT: #{top_method.full_name} at #{top_pct.round(1)}%"
  puts "May not be worth optimizing - diminishing returns."
else
  puts "NO CLEAR BOTTLENECK (top method only #{top_pct.round(1)}%)"
  puts "Performance is well-balanced. Focus on algorithmic improvements."
end
