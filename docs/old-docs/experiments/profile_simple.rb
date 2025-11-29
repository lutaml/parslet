#!/usr/bin/env ruby
# Profile the JSON parser using Ruby's built-in profiling

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('../example', __dir__)

require 'parslet'
require 'benchmark'
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
puts "PARSLET PERFORMANCE ANALYSIS"
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

# Detailed timing analysis
puts "\n" + "=" * 70
puts "DETAILED TIMING ANALYSIS (10 iterations)"
puts "=" * 70

times = []
10.times do |i|
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  parser.parse(json_data)
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  times << elapsed
  puts "Iteration #{i + 1}: #{(elapsed * 1000).round(2)} ms"
end

avg_time = times.sum / times.size
min_time = times.min
max_time = times.max
data_size_mb = json_data.bytesize / (1024.0 * 1024.0)

puts "\n" + "=" * 70
puts "STATISTICS"
puts "=" * 70
puts "Average time:     #{(avg_time * 1000).round(2)} ms"
puts "Min time:         #{(min_time * 1000).round(2)} ms"
puts "Max time:         #{(max_time * 1000).round(2)} ms"
puts "Std deviation:    #{(Math.sqrt(times.map { |t| (t - avg_time)**2 }.sum / times.size) * 1000).round(2)} ms"
puts "Throughput (avg): #{(data_size_mb / avg_time).round(4)} MB/sec"
puts "Throughput (max): #{(data_size_mb / min_time).round(4)} MB/sec"

# Memory analysis using ObjectSpace
puts "\n" + "=" * 70
puts "MEMORY ANALYSIS"
puts "=" * 70

GC.start
GC.disable

before_objects = ObjectSpace.count_objects
before_memory = `ps -o rss= -p #{Process.pid}`.to_i

parser.parse(json_data)

after_objects = ObjectSpace.count_objects
after_memory = `ps -o rss= -p #{Process.pid}`.to_i

GC.enable

puts "\nObject allocations during parse:"
[:T_OBJECT, :T_CLASS, :T_MODULE, :T_FLOAT, :T_STRING, :T_REGEXP,
 :T_ARRAY, :T_HASH, :T_STRUCT, :T_BIGNUM, :T_FILE, :T_DATA,
 :T_MATCH, :T_COMPLEX, :T_RATIONAL, :TOTAL].each do |type|
  before = before_objects[type] || 0
  after = after_objects[type] || 0
  diff = after - before
  next if diff == 0
  puts "  #{type.to_s.ljust(15)}: #{diff.to_s.rjust(10)} objects"
end

memory_increase = after_memory - before_memory
puts "\nMemory increase: #{memory_increase} KB"

# Component timing analysis
puts "\n" + "=" * 70
puts "COMPONENT TIMING BREAKDOWN"
puts "=" * 70

puts "\nTesting individual parser components..."

# Test string matching performance
test_string = '"test string with some content"' * 100
string_rule = parser.string

string_time = Benchmark.measure do
  1000.times { string_rule.parse(test_string) rescue nil }
end
puts "String parsing:   #{(string_time.real * 1000).round(2)} ms / 1000 iterations"

# Test number matching performance
test_number = '123 456 789 ' * 100
number_rule = parser.number

number_time = Benchmark.measure do
  1000.times { number_rule.parse(test_number.split.first) rescue nil }
end
puts "Number parsing:   #{(number_time.real * 1000).round(2)} ms / 1000 iterations"

# Test array parsing performance
test_array = '[1, 2, 3, 4, 5]'
array_rule = parser.array

array_time = Benchmark.measure do
  100.times { array_rule.parse(test_array) rescue nil }
end
puts "Array parsing:    #{(array_time.real * 1000).round(2)} ms / 100 iterations"

# Save detailed report
puts "\n" + "=" * 70
puts "SAVING DETAILED REPORT"
puts "=" * 70

report = <<~REPORT
  # Parslet JSON Parser Performance Analysis
  Generated: #{Time.now}

  ## Test Configuration
  - Data size: #{json_data.bytesize} bytes (#{data_size_mb.round(4)} MB)
  - Iterations: 10
  - Parser: MyJson::Parser (example/json.rb)

  ## Performance Metrics
  - Average parse time: #{(avg_time * 1000).round(2)} ms
  - Min parse time: #{(min_time * 1000).round(2)} ms
  - Max parse time: #{(max_time * 1000).round(2)} ms
  - Standard deviation: #{(Math.sqrt(times.map { |t| (t - avg_time)**2 }.sum / times.size) * 1000).round(2)} ms
  - Average throughput: #{(data_size_mb / avg_time).round(4)} MB/sec
  - Best throughput: #{(data_size_mb / min_time).round(4)} MB/sec

  ## Memory Impact
  - Memory increase: #{memory_increase} KB
  - Object allocations: See detailed breakdown in console output

  ## Component Performance (relative)
  - String parsing: #{(string_time.real * 1000).round(2)} ms / 1000 iterations
  - Number parsing: #{(number_time.real * 1000).round(2)} ms / 1000 iterations
  - Array parsing: #{(array_time.real * 1000).round(2)} ms / 100 iterations

  ## Analysis

  Current performance is significantly below the 5.0 MB/sec target.

  Key observations:
  1. Parse time shows #{((max_time / min_time - 1) * 100).round(1)}% variance between best and worst
  2. Memory allocations indicate heavy object creation
  3. Component timing suggests areas for optimization

  ## Recommendations for Optimization

  Based on this analysis, focus areas should be:
  1. Reduce object allocations (especially strings and arrays)
  2. Optimize hot path methods
  3. Consider caching/memoization for repeated patterns
  4. Profile with more detailed tools (ruby-prof, stackprof) once installed
REPORT

File.write('benchmark/reports/performance_analysis.md', report)
puts "\n✓ Detailed report saved to: benchmark/reports/performance_analysis.md"

puts "\n" + "=" * 70
puts "ANALYSIS COMPLETE"
puts "=" * 70
puts "\nNext steps:"
puts "1. Install profiling gems: gem install ruby-prof stackprof memory_profiler"
puts "2. Run detailed profiling to identify specific hot spots"
puts "3. Focus optimization efforts on highest-impact areas"
