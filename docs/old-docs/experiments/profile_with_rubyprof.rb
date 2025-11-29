#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'ruby-prof'
require_relative '../lib/parslet'
require_relative '../example/json'
require_relative '../example/calc'

# Load test data
# Use real JSON example from example/json.rb
json_data = <<~JSON
  [1,2,3,null,"asdfasdf asdfds",{"a":-1.2},{"b":true,"c":false},0.1e24,true,false,[1]]
JSON
json_data = json_data * 200  # Repeat to get meaningful data

calc_data = "1 + 2 * (3 + 4) - 5 / 6\n" * 100

puts "=" * 80
puts "RUBY-PROF DETAILED METHOD PROFILING"
puts "=" * 80

# Profile JSON Parser
puts "\n#{'-' * 80}"
puts "PROFILING JSON PARSER"
puts "Input size: #{json_data.bytesize} bytes"
puts "#{'-' * 80}\n"

parser = MyJson::Parser.new
result = RubyProf.profile do
  3.times { parser.parse(json_data) }
end

# Print flat profile (top methods by self time)
puts "\nTOP 20 METHODS BY SELF TIME:"
puts "-" * 80
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, min_percent: 0.5)

# Print call stack profile
puts "\n\nCALL STACK PROFILE (Top 10 methods):"
puts "-" * 80
printer = RubyProf::CallStackPrinter.new(result)
File.open('benchmark/reports/json_callstack.html', 'w') do |f|
  printer.print(f)
end
puts "Saved to: benchmark/reports/json_callstack.html"

# Print graph profile
puts "\nSaving graph profile..."
printer = RubyProf::GraphPrinter.new(result)
File.open('benchmark/reports/json_graph.txt', 'w') do |f|
  printer.print(f, min_percent: 0.5)
end
puts "Saved to: benchmark/reports/json_graph.txt"

# Skip CallTree - it requires a directory path
puts "\n(Skipping CallTree output - use HTML and TXT reports for analysis)"

# Profile Calc Parser
puts "\n\n#{'-' * 80}"
puts "PROFILING CALC PARSER"
puts "Input size: #{calc_data.bytesize} bytes"
puts "#{'-' * 80}\n"

calc_parser = CalcParser.new
result = RubyProf.profile do
  3.times { calc_parser.parse(calc_data) }
end

# Print flat profile
puts "\nTOP 20 METHODS BY SELF TIME:"
puts "-" * 80
printer = RubyProf::FlatPrinter.new(result)
printer.print(STDOUT, min_percent: 0.5)

# Save detailed reports
printer = RubyProf::CallStackPrinter.new(result)
File.open('benchmark/reports/calc_callstack.html', 'w') do |f|
  printer.print(f)
end

printer = RubyProf::GraphPrinter.new(result)
File.open('benchmark/reports/calc_graph.txt', 'w') do |f|
  printer.print(f, min_percent: 0.5)
end

# Skip CallTree for Calc parser too

puts "\n#{'-' * 80}"
puts "All detailed reports saved to benchmark/reports/"
puts "#{'-' * 80}"
