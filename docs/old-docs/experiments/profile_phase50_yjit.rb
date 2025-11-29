#!/usr/bin/env ruby
# Phase 50a: YJIT Performance Comparison
# Compares parsing performance with and without YJIT enabled

require 'bundler/setup'
require 'benchmark/ips'
require_relative '../example/json'

# Use the actual parser class
JSONParser = MyJson::Parser

puts "="*80
puts "Phase 50a: YJIT Performance Comparison"
puts "Ruby Version: #{RUBY_VERSION}"
puts "YJIT Enabled: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?}"
puts "="*80
puts

# Load test data
json_file = File.expand_path('../benchmark/fixtures/json/large_structure.json', __dir__)
json_content = File.read(json_file)
file_size = File.size(json_file)

puts "Test file: #{json_file}"
puts "File size: #{file_size} bytes (#{(file_size / 1024.0).round(2)} KB)"
puts

# Check if YJIT is available
if defined?(RubyVM::YJIT)
  puts "✓ YJIT is available"
  if RubyVM::YJIT.enabled?
    puts "✓ YJIT is currently ENABLED"
    puts "  Run without --yjit to compare baseline performance"
  else
    puts "✗ YJIT is currently DISABLED"
    puts "  Run with --yjit flag to enable: ruby --yjit #{__FILE__}"
  end
else
  puts "✗ YJIT not available (requires Ruby 3.1+)"
  puts "  Current Ruby version: #{RUBY_VERSION}"
  exit 1
end
puts

# Warmup to let YJIT compile hot paths
puts "Warming up (20 iterations to allow YJIT compilation)..."
parser = JSONParser.new
20.times { parser.parse(json_content) }
puts "Warmup complete"
puts

# Show YJIT stats if enabled
if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
  stats_before = RubyVM::YJIT.runtime_stats
  puts "YJIT Stats After Warmup:"
  puts "-" * 80
  puts "Compiled blocks: #{stats_before[:compiled_block_count]}"
  puts "Compiled iseqs: #{stats_before[:compiled_iseq_count]}"
  puts "Invalidated blocks: #{stats_before[:invalidated_block_count]}"
  puts "Inline cache misses: #{stats_before[:inline_code_size]}"
  puts
end

# Benchmark
puts "Running benchmark..."
puts "-" * 80

Benchmark.ips do |x|
  x.config(time: 10, warmup: 3)

  x.report("JSON parsing") do
    parser = JSONParser.new
    parser.parse(json_content)
  end

  x.report("JSON parsing (reused parser)") do
    parser.parse(json_content)
  end
end

puts
puts "-" * 80

# Show final YJIT stats if enabled
if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
  puts
  puts "="*80
  puts "FINAL YJIT STATISTICS"
  puts "="*80
  stats = RubyVM::YJIT.runtime_stats

  puts "\n## Compilation Stats"
  puts "-" * 80
  puts "Compiled blocks: #{stats[:compiled_block_count]}"
  puts "Compiled ISEQs: #{stats[:compiled_iseq_count]}"
  puts "Invalidated blocks: #{stats[:invalidated_block_count]}"
  puts "Invalidation ratio: #{(stats[:invalidated_block_count].to_f / stats[:compiled_block_count] * 100).round(2)}%"

  puts "\n## Code Generation"
  puts "-" * 80
  puts "Inline code size: #{stats[:inline_code_size]} bytes"
  puts "Outlined code size: #{stats[:outlined_code_size]} bytes"
  total_code = stats[:inline_code_size] + stats[:outlined_code_size]
  puts "Total generated code: #{total_code} bytes (#{(total_code / 1024.0).round(2)} KB)"

  puts "\n## Side Exits"
  puts "-" * 80
  puts "Side exits: #{stats[:side_exit_count]}"
  puts "Total exits: #{stats[:total_exit_count]}"
  puts "Side exit ratio: #{(stats[:side_exit_count].to_f / stats[:total_exit_count] * 100).round(2)}%" if stats[:total_exit_count] > 0

  puts "\n## Optimization Impact"
  puts "-" * 80
  if stats[:ratio_in_yjit]
    puts "Time in YJIT code: #{(stats[:ratio_in_yjit] * 100).round(2)}%"
  end

  puts
  puts "="*80
  puts "YJIT RECOMMENDATIONS"
  puts "="*80
  puts

  ratio = stats[:ratio_in_yjit] || 0
  if ratio > 0.9
    puts "✓ EXCELLENT: #{(ratio * 100).round(1)}% of time spent in YJIT-compiled code"
    puts "  YJIT is providing maximum benefit for this workload"
  elsif ratio > 0.7
    puts "✓ GOOD: #{(ratio * 100).round(1)}% of time spent in YJIT-compiled code"
    puts "  YJIT is providing significant speedup"
  elsif ratio > 0.5
    puts "○ MODERATE: #{(ratio * 100).round(1)}% of time spent in YJIT-compiled code"
    puts "  YJIT helps but there's room for improvement"
  else
    puts "✗ LOW: Only #{(ratio * 100).round(1)}% of time spent in YJIT-compiled code"
    puts "  Consider investigating why YJIT isn't compiling more code"
  end

  puts

  invalidation_ratio = stats[:invalidated_block_count].to_f / stats[:compiled_block_count]
  if invalidation_ratio > 0.1
    puts "⚠ Warning: High invalidation ratio (#{(invalidation_ratio * 100).round(1)}%)"
    puts "  This may indicate dynamic code patterns that limit YJIT effectiveness"
  else
    puts "✓ Good invalidation ratio (#{(invalidation_ratio * 100).round(1)}%)"
  end

  puts
  puts "To enable YJIT in production:"
  puts "  ruby --yjit your_script.rb"
  puts "  or set RUBY_YJIT_ENABLE=1 environment variable"
  puts
end

puts "="*80
puts "Benchmark complete."
puts
puts "To compare with/without YJIT:"
puts "  Without: ruby #{__FILE__}"
puts "  With:    ruby --yjit #{__FILE__}"
puts "="*80
