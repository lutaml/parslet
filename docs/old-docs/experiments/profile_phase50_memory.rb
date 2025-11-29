#!/usr/bin/env ruby
# Phase 50a: Memory Profiling - Comprehensive Analysis
# Profiles memory allocations during JSON parsing to identify optimization opportunities

require 'bundler/setup'
require 'memory_profiler'
require_relative '../example/json'
require 'json'

# Use the actual parser class
JSONParser = MyJson::Parser

puts "="*80
puts "Phase 50a: Memory Profiling Analysis"
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

# Warmup
puts "Warming up..."
parser = JSONParser.new
3.times { parser.parse(json_content) }
puts "Warmup complete"
puts

# Profile memory allocations
puts "Profiling memory allocations (50 iterations)..."
report = MemoryProfiler.report do
  parser = JSONParser.new
  50.times do
    parser.parse(json_content)
  end
end

puts
puts "="*80
puts "MEMORY PROFILING RESULTS"
puts "="*80
puts

# Total allocations
puts "## Total Allocations"
puts "-" * 80
puts "Total allocated: #{report.total_allocated_memsize} bytes (#{(report.total_allocated_memsize / 1024.0 / 1024.0).round(2)} MB)"
puts "Total retained:  #{report.total_retained_memsize} bytes (#{(report.total_retained_memsize / 1024.0 / 1024.0).round(2)} MB)"
puts "Total allocated objects: #{report.total_allocated}"
puts "Total retained objects:  #{report.total_retained}"
puts

# Top allocations by class
puts "## Top 15 Allocations by Class"
puts "-" * 80
puts "%-30s %12s %12s" % ["Class", "Count", "Memory (KB)"]
puts "-" * 80
report.allocated_memory_by_class.first(15).each do |entry|
  klass = entry[0]
  data = entry[1]
  next unless data && data[:count] && data[:memsize]
  puts "%-30s %12d %12.2f" % [
    klass,
    data[:count],
    data[:memsize] / 1024.0
  ]
end
puts

# Top allocations by location
puts "## Top 20 Allocation Sources (File:Line)"
puts "-" * 80
puts "%-60s %12s %12s" % ["Location", "Count", "Memory (KB)"]
puts "-" * 80
report.allocated_memory_by_location.first(20).each do |entry|
  location = entry[0]
  data = entry[1]
  next unless data && data[:count] && data[:memsize]
  # Shorten paths for readability
  location_str = location.to_s
  short_location = location_str.gsub(Dir.pwd + '/', '')
  puts "%-60s %12d %12.2f" % [
    short_location[0..59],
    data[:count],
    data[:memsize] / 1024.0
  ]
end
puts

# String allocations (critical for parsers)
puts "## String Allocations Analysis"
puts "-" * 80
string_data = report.allocated_memory_by_class.find { |k, v| k == "String" }
if string_data
  _, data = string_data
  puts "Total strings allocated: #{data[:count]}"
  puts "Total string memory: #{(data[:memsize] / 1024.0).round(2)} KB"
  puts "Average string size: #{(data[:memsize].to_f / data[:count]).round(2)} bytes"

  # Show top string allocation locations
  puts "\nTop 10 String Allocation Sources:"
  puts "-" * 80
  string_locations = report.strings_allocated_by_location.first(10)
  string_locations.each do |location, count|
    short_location = location.gsub(Dir.pwd + '/', '')
    puts "  #{short_location[0..70]} (#{count})"
  end
end
puts

# Array allocations
puts "## Array Allocations Analysis"
puts "-" * 80
array_data = report.allocated_memory_by_class.find { |k, v| k == "Array" }
if array_data
  _, data = array_data
  puts "Total arrays allocated: #{data[:count]}"
  puts "Total array memory: #{(data[:memsize] / 1024.0).round(2)} KB"
  puts "Average array size: #{(data[:memsize].to_f / data[:count]).round(2)} bytes"
end
puts

# Hash allocations
puts "## Hash Allocations Analysis"
puts "-" * 80
hash_data = report.allocated_memory_by_class.find { |k, v| k == "Hash" }
if hash_data
  _, data = hash_data
  puts "Total hashes allocated: #{data[:count]}"
  puts "Total hash memory: #{(data[:memsize] / 1024.0).round(2)} KB"
  puts "Average hash size: #{(data[:memsize].to_f / data[:count]).round(2)} bytes"
end
puts

# Parslet-specific classes
puts "## Parslet Object Allocations"
puts "-" * 80
parslet_classes = report.allocated_memory_by_class.select { |k, v| k.to_s.start_with?('Parslet::') }
if parslet_classes.any?
  puts "%-40s %12s %12s" % ["Class", "Count", "Memory (KB)"]
  puts "-" * 80
  parslet_classes.sort_by { |k, v| -v[:count] }.first(15).each do |klass, data|
    puts "%-40s %12d %12.2f" % [
      klass.to_s.gsub('Parslet::', ''),
      data[:count],
      data[:memsize] / 1024.0
    ]
  end
else
  puts "No Parslet-specific allocations found (objects likely pooled/reused)"
end
puts

# Optimization opportunities
puts "="*80
puts "OPTIMIZATION OPPORTUNITIES"
puts "="*80
puts

total_allocated_mb = report.total_allocated_memsize / 1024.0 / 1024.0
string_mb = string_data ? string_data[1][:memsize] / 1024.0 / 1024.0 : 0
array_mb = array_data ? array_data[1][:memsize] / 1024.0 / 1024.0 : 0
hash_mb = hash_data ? hash_data[1][:memsize] / 1024.0 / 1024.0 : 0

puts "1. String Allocations: #{string_mb.round(2)} MB (#{((string_mb / total_allocated_mb) * 100).round(1)}%)"
puts "   → Consider frozen_string_literal pragma"
puts "   → Use String#<< instead of + for concatenation"
puts

puts "2. Array Allocations: #{array_mb.round(2)} MB (#{((array_mb / total_allocated_mb) * 100).round(1)}%)"
puts "   → Pre-size arrays where size is known"
puts "   → Consider object pooling for frequently created arrays"
puts

puts "3. Hash Allocations: #{hash_mb.round(2)} MB (#{((hash_mb / total_allocated_mb) * 100).round(1)}%)"
puts "   → Review cache implementation"
puts "   → Consider pre-sizing hashes"
puts

retained_pct = (report.total_retained_memsize.to_f / report.total_allocated_memsize * 100).round(1)
puts "4. Retention Rate: #{retained_pct}% of allocations retained"
if retained_pct > 10
  puts "   ⚠ High retention - may indicate memory leak or caching issues"
else
  puts "   ✓ Good - most allocations are garbage collected"
end
puts

puts "="*80
puts "Profile complete. Results saved for analysis."
puts "="*80
