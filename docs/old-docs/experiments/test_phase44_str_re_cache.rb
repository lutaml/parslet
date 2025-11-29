#!/usr/bin/env ruby
# Phase 44: Test Str/Re caching impact on Pascal parser
# Compare baseline (no Str/Re caching) vs enabled Str/Re caching

require 'bundler/setup'
require_relative 'parsers/pascal_parser'
require 'benchmark'

# Test files
test_files = [
  { name: 'small_program.pas', path: 'benchmark/fixtures/pascal/small_program.pas' },
  { name: 'medium_program.pas', path: 'benchmark/fixtures/pascal/medium_program.pas' },
  { name: 'large_program.pas', path: 'benchmark/fixtures/pascal/large_program.pas' },
  { name: 'huge_program.pas', path: 'benchmark/fixtures/pascal/huge_program.pas' }
]

def test_parser(name, content, label)
  parser = PascalParser.new
  times = []

  # Warmup
  parser.parse(content)

  # Measure 3 times
  3.times do
    start = Time.now
    parser.parse(content)
    times << (Time.now - start) * 1000  # Convert to ms
  end

  avg = times.sum / times.size
  best = times.min

  printf("  %-30s %8.2fms (best: %8.2fms)\n", name, avg, best)
  { name: name, avg: avg, best: best, label: label }
end

puts "=" * 80
puts "PHASE 44: Str/Re Caching Impact on Pascal Parser"
puts "=" * 80
puts

baseline_results = []
optimized_results = []

# Test 1: Baseline (current behavior - Str/Re NOT cached)
puts "BASELINE: Str/Re caching DISABLED (current behavior)"
puts "-" * 80

test_files.each do |file|
  content = File.read(file[:path])
  size = content.bytesize
  printf("Testing %-30s (%7d bytes)...\n", file[:name], size)
  result = test_parser(file[:name], content, "baseline")
  baseline_results << result.merge(size: size)
end

puts
puts "=" * 80
puts "OPTIMIZED: Enabling Str/Re caching"
puts "-" * 80

# Enable Str/Re caching via monkey-patch
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

test_files.each do |file|
  content = File.read(file[:path])
  size = content.bytesize
  printf("Testing %-30s (%7d bytes)...\n", file[:name], size)
  result = test_parser(file[:name], content, "optimized")
  optimized_results << result.merge(size: size)
end

puts
puts "=" * 80
puts "COMPARISON"
puts "=" * 80
puts

printf("%-30s %12s %12s %10s %12s\n",
       "File", "Baseline", "Optimized", "Speedup", "Improvement")
puts "-" * 80

baseline_results.each_with_index do |baseline, i|
  optimized = optimized_results[i]
  speedup = baseline[:avg] / optimized[:avg]
  improvement = ((baseline[:avg] - optimized[:avg]) / baseline[:avg] * 100)

  printf("%-30s %10.2fms %10.2fms %9.2fx %10.1f%%\n",
         baseline[:name],
         baseline[:avg],
         optimized[:avg],
         speedup,
         improvement)
end

puts
puts "=" * 80
puts "SUMMARY"
puts "=" * 80

total_baseline = baseline_results.map { |r| r[:avg] }.sum
total_optimized = optimized_results.map { |r| r[:avg] }.sum
overall_speedup = total_baseline / total_optimized
overall_improvement = ((total_baseline - total_optimized) / total_baseline * 100)

puts "Total time (baseline):  #{total_baseline.round(2)}ms"
puts "Total time (optimized): #{total_optimized.round(2)}ms"
puts "Overall speedup:        %.2fx" % overall_speedup
puts "Overall improvement:    %.1f%%" % overall_improvement
puts

if overall_speedup > 1.2
  puts "✅ SIGNIFICANT IMPROVEMENT - Str/Re caching provides major benefit"
elsif overall_speedup > 1.0
  puts "⚠️  MINOR IMPROVEMENT - Benefit exists but limited"
else
  puts "❌ REGRESSION - Str/Re caching makes things worse"
end
