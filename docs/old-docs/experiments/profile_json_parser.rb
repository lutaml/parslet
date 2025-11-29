#!/usr/bin/env ruby
# Profile the JSON parser using ruby-prof

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('../example', __dir__)

require 'parslet'
require 'ruby-prof'
require 'stringio'
require 'fileutils'

# Suppress output from example file
original_stdout = $stdout
original_stderr = $stderr
$stdout = StringIO.new
$stderr = StringIO.new

require_relative '../example/json'

$stdout = original_stdout
$stderr = original_stderr

# Generate test data
def generate_json_data(size_multiplier = 100)
  users = (1..10 * size_multiplier).map do |i|
    %Q({"id":#{i},"name":"User #{i}","email":"user#{i}@example.com","active":#{i.even?},"score":#{i * 1.5},"tags":["tag#{i}","tag#{i + 1}"],"metadata":{"created":"2024-01-#{i % 28 + 1}","updated":"2024-02-#{i % 28 + 1}","count":#{i * 100}}})
  end.join(",")

  %Q({"users":[#{users}],"summary":{"total":#{10 * size_multiplier},"active":#{5 * size_multiplier},"inactive":#{5 * size_multiplier}}})
end

puts "=" * 70
puts "PROFILING JSON PARSER WITH RUBY-PROF"
puts "=" * 70

# Create reports directory
FileUtils.mkdir_p('benchmark/reports')

# Generate test data
puts "\nGenerating test data..."
json_data = generate_json_data(100)
puts "Data size: #{json_data.bytesize} bytes (#{(json_data.bytesize / 1024.0 / 1024.0).round(4)} MB)"

# Create parser
parser = MyJson::Parser.new

# Warmup
puts "\nWarmup parse..."
parser.parse(json_data)
puts "✓ Warmup successful"

# Profile
puts "\nProfiling (this may take a minute)..."

RubyProf.measure_mode = RubyProf::WALL_TIME

result = RubyProf.profile do
  5.times do
    parser.parse(json_data)
  end
end

puts "\n" + "=" * 70
puts "GENERATING REPORTS"
puts "=" * 70

# 1. Graph report (call graph with time percentages)
puts "\n1. Generating call graph report..."
File.open('benchmark/reports/json_parser_graph.txt', 'w') do |file|
  printer = RubyProf::GraphPrinter.new(result)
  printer.print(file, min_percent: 0.5)
end
puts "   ✓ Saved to: benchmark/reports/json_parser_graph.txt"

# 2. Flat report (methods sorted by self time)
puts "\n2. Generating flat profile report..."
File.open('benchmark/reports/json_parser_flat.txt', 'w') do |file|
  printer = RubyProf::FlatPrinter.new(result)
  printer.print(file, min_percent: 0.5)
end
puts "   ✓ Saved to: benchmark/reports/json_parser_flat.txt"

# 3. Call stack report
puts "\n3. Generating call stack report..."
File.open('benchmark/reports/json_parser_stack.txt', 'w') do |file|
  printer = RubyProf::CallStackPrinter.new(result)
  printer.print(file, min_percent: 0.5)
end
puts "   ✓ Saved to: benchmark/reports/json_parser_stack.txt"

# 4. HTML Graph (if available)
begin
  puts "\n4. Generating HTML call graph..."
  File.open('benchmark/reports/json_parser_graph.html', 'w') do |file|
    printer = RubyProf::GraphHtmlPrinter.new(result)
    printer.print(file, min_percent: 0.5)
  end
  puts "   ✓ Saved to: benchmark/reports/json_parser_graph.html"
rescue => e
  puts "   ⚠ HTML graph not available: #{e.message}"
end

# 5. Generate summary
puts "\n" + "=" * 70
puts "TOP 20 METHODS BY TOTAL TIME"
puts "=" * 70

methods = result.threads.first.methods.sort_by(&:total_time).reverse.take(20)

puts "\n%-60s %10s %10s %8s" % ["Method", "Total (ms)", "Self (ms)", "Calls"]
puts "-" * 90

methods.each do |method|
  method_name = "#{method.klass_name}##{method.method_name}"
  method_name = method_name[0..58] + "…" if method_name.length > 59

  total_ms = (method.total_time * 1000).round(2)
  self_ms = (method.self_time * 1000).round(2)

  puts "%-60s %10.2f %10.2f %8d" % [
    method_name,
    total_ms,
    self_ms,
    method.called
  ]
end

puts "\n" + "=" * 70
puts "TOP 20 METHODS BY SELF TIME"
puts "=" * 70

methods_by_self = result.threads.first.methods.sort_by(&:self_time).reverse.take(20)

puts "\n%-60s %10s %10s %8s" % ["Method", "Self (ms)", "Total (ms)", "Calls"]
puts "-" * 90

methods_by_self.each do |method|
  method_name = "#{method.klass_name}##{method.method_name}"
  method_name = method_name[0..58] + "…" if method_name.length > 59

  total_ms = (method.total_time * 1000).round(2)
  self_ms = (method.self_time * 1000).round(2)

  puts "%-60s %10.2f %10.2f %8d" % [
    method_name,
    self_ms,
    total_ms,
    method.called
  ]
end

# Parslet-specific analysis
puts "\n" + "=" * 70
puts "PARSLET-SPECIFIC METHODS (by self time)"
puts "=" * 70

parslet_methods = result.threads.first.methods
  .select { |m| m.klass_name =~ /Parslet/ }
  .sort_by(&:self_time)
  .reverse
  .take(30)

puts "\n%-60s %10s %10s %8s" % ["Method", "Self (ms)", "Total (ms)", "Calls"]
puts "-" * 90

parslet_methods.each do |method|
  method_name = "#{method.klass_name}##{method.method_name}"
  method_name = method_name[0..58] + "…" if method_name.length > 59

  total_ms = (method.total_time * 1000).round(2)
  self_ms = (method.self_time * 1000).round(2)

  puts "%-60s %10.2f %10.2f %8d" % [
    method_name,
    self_ms,
    total_ms,
    method.called
  ]
end

puts "\n" + "=" * 70
puts "PROFILING COMPLETE"
puts "=" * 70
puts "\nReports saved in benchmark/reports/"
puts "\nKey files:"
puts "  - json_parser_graph.txt  (call graph with percentages)"
puts "  - json_parser_flat.txt   (methods sorted by self time)"
puts "  - json_parser_stack.txt  (call stack view)"
puts "  - json_parser_graph.html (interactive HTML graph)"
