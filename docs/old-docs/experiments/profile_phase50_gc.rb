#!/usr/bin/env ruby
# Phase 50a: GC Profiling - Garbage Collection Analysis
# Profiles GC behavior during JSON parsing to optimize memory management

require 'bundler/setup'
require_relative '../example/json'

# Use the actual parser class
JSONParser = MyJson::Parser

puts "="*80
puts "Phase 50a: Garbage Collection Profiling"
puts "Ruby Version: #{RUBY_VERSION}"
puts "="*80
puts

# Load test data
json_file = File.expand_path('../benchmark/fixtures/json/large_structure.json', __dir__)
json_content = File.read(json_file)
file_size = File.size(json_file)

puts "Test file: #{json_file}"
puts "File size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"
puts

# Get initial GC stats
GC.start  # Clean slate
initial_stats = GC.stat
initial_count = GC.count

puts "Initial GC State:"
puts "-" * 80
puts "GC count: #{initial_count}"
puts "Heap pages: #{initial_stats[:heap_allocated_pages]}"
puts "Heap live slots: #{initial_stats[:heap_live_slots]}"
puts "Heap free slots: #{initial_stats[:heap_free_slots]}"
puts "Total allocated: #{initial_stats[:total_allocated_objects]}"
puts

# Profile GC during parsing
puts "Profiling GC behavior (100 iterations)..."
puts "-" * 80

# Enable GC profiling
GC::Profiler.enable
GC::Profiler.clear

# Run parsing workload
parser = JSONParser.new
100.times do |i|
  parser.parse(json_content)
  print "." if i % 10 == 0
end
puts

# Get final GC stats
final_stats = GC.stat
final_count = GC.count
gc_runs = final_count - initial_count

puts
puts "="*80
puts "GARBAGE COLLECTION RESULTS"
puts "="*80
puts

# GC frequency
puts "## GC Frequency"
puts "-" * 80
puts "Total GC runs during test: #{gc_runs}"
puts "GC runs per parse: #{(gc_runs / 100.0).round(3)}"
if gc_runs > 50
  puts "  ⚠ High GC frequency - may indicate excessive allocations"
elsif gc_runs < 5
  puts "  ✓ Low GC frequency - efficient memory usage"
else
  puts "  ○ Moderate GC frequency"
end
puts

# Heap statistics
puts "## Heap Statistics"
puts "-" * 80
puts "%-30s %15s %15s %15s" % ["Metric", "Initial", "Final", "Delta"]
puts "-" * 80

heap_metrics = [
  [:heap_allocated_pages, "Allocated pages"],
  [:heap_sorted_length, "Sorted length"],
  [:heap_live_slots, "Live slots"],
  [:heap_free_slots, "Free slots"],
  [:heap_final_slots, "Final slots"],
  [:heap_marked_slots, "Marked slots"],
  [:heap_swept_slots, "Swept slots"]
]

heap_metrics.each do |key, label|
  initial = initial_stats[key] || 0
  final = final_stats[key] || 0
  delta = final - initial
  delta_str = delta >= 0 ? "+#{delta}" : delta.to_s
  puts "%-30s %15d %15d %15s" % [label, initial, final, delta_str]
end
puts

# Memory allocation
puts "## Memory Allocation"
puts "-" * 80
total_alloc_delta = final_stats[:total_allocated_objects] - initial_stats[:total_allocated_objects]
puts "Objects allocated: #{total_alloc_delta}"
puts "Objects per parse: #{(total_alloc_delta / 100.0).round(0)}"
puts

malloc_increase = final_stats[:malloc_increase_bytes] || 0
puts "Malloc increase: #{malloc_increase} bytes (#{(malloc_increase / 1024.0).round(2)} KB)"
puts

# GC time
puts "## GC Time Analysis"
puts "-" * 80
gc_time = GC::Profiler.total_time
puts "Total GC time: #{(gc_time * 1000).round(2)} ms"
puts "Average GC time per run: #{(gc_time * 1000 / gc_runs).round(2)} ms" if gc_runs > 0
puts "GC overhead: #{((gc_time / (Time.now.to_f - initial_stats[:time] rescue 1)) * 100).round(2)}% of execution time"
puts

# GC profiler report
if gc_runs > 0
  puts "## GC Profiler Report (Last 10 GC Runs)"
  puts "-" * 80
  report_lines = GC::Profiler.result.split("\n")
  # Show header + last 10 runs
  puts report_lines.first(2).join("\n") if report_lines.size > 2
  puts report_lines.last([10, report_lines.size - 2].min).join("\n")
  puts
end

GC::Profiler.disable

# Recommendations
puts "="*80
puts "OPTIMIZATION RECOMMENDATIONS"
puts "="*80
puts

# Heap growth
heap_growth = final_stats[:heap_allocated_pages] - initial_stats[:heap_allocated_pages]
if heap_growth > 100
  puts "1. High heap growth (#{heap_growth} pages)"
  puts "   → Consider pre-allocating objects or object pooling"
  puts "   → Review object lifecycle to reduce long-lived allocations"
  puts
end

# GC frequency
if gc_runs > 50
  puts "2. Frequent GC runs (#{gc_runs} during test)"
  puts "   → Increase initial heap size: RUBY_GC_HEAP_INIT_SLOTS=100000"
  puts "   → Adjust growth factor: RUBY_GC_HEAP_GROWTH_FACTOR=1.3"
  puts
elsif gc_runs < 5
  puts "2. Infrequent GC (#{gc_runs} during test)"
  puts "   ✓ Good - memory management is efficient"
  puts
end

# Object allocations
objects_per_parse = total_alloc_delta / 100.0
if objects_per_parse > 10000
  puts "3. High object allocation rate (#{objects_per_parse.round(0)} objects/parse)"
  puts "   → Review memory profiling results for allocation hot spots"
  puts "   → Consider frozen_string_literal pragma"
  puts "   → Evaluate object pooling for frequently created objects"
  puts
end

# Recommended GC settings
puts "="*80
puts "RECOMMENDED GC TUNING"
puts "="*80
puts

puts "For CLI/short-lived processes:"
puts "  export RUBY_GC_HEAP_INIT_SLOTS=40000"
puts "  export RUBY_GC_HEAP_GROWTH_FACTOR=1.8"
puts

puts "For long-running processes (servers):"
puts "  export RUBY_GC_HEAP_INIT_SLOTS=100000"
puts "  export RUBY_GC_HEAP_GROWTH_FACTOR=1.3"
puts "  export RUBY_GC_HEAP_OLDOBJECT_LIMIT_FACTOR=2.0"
puts

puts "For memory-constrained environments:"
puts "  export RUBY_GC_HEAP_INIT_SLOTS=10000"
puts "  export RUBY_GC_HEAP_GROWTH_FACTOR=1.1"
puts "  export RUBY_GC_HEAP_FREE_SLOTS_MIN_RATIO=0.2"
puts

puts "="*80
puts "GC profiling complete."
puts "="*80
