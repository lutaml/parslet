#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'memory_profiler'
require 'json'
require_relative '../lib/parslet'
require_relative '../example/json'

# Create a medium-sized JSON test
json_data = {
  "users" => (1..100).map { |i|
    {
      "id" => i,
      "name" => "User #{i}",
      "email" => "user#{i}@example.com",
      "active" => i.even?,
      "metadata" => {
        "created" => "2024-01-#{i % 28 + 1}",
        "tags" => ["tag#{i}", "tag#{i + 1}"]
      }
    }
  }
}
json_content = JSON.generate(json_data)

puts "Input size: #{json_content.bytesize} bytes"
puts "Profiling memory usage with detailed cache metrics..."
puts

# Monkey-patch Context to track cache statistics
module Parslet
  module Atoms
    class Context
      attr_reader :cache

      def cache_stats
        total_entries = 0
        total_positions = 0
        max_positions = 0

        @cache.each do |atom, positions|
          positions_count = positions.size
          total_entries += 1
          total_positions += positions_count
          max_positions = positions_count if positions_count > max_positions
        end

        {
          atoms_cached: total_entries,
          total_positions: total_positions,
          max_positions_per_atom: max_positions,
          avg_positions_per_atom: total_entries > 0 ? total_positions.to_f / total_entries : 0
        }
      end
    end
  end
end

parser = MyJson::Parser.new

# Profile the parsing with memory tracking
context = nil
report = MemoryProfiler.report do
  begin
    result = parser.parse(json_content)
    context = parser.instance_variable_get(:@context) if parser.respond_to?(:instance_variable_get)
  rescue Parslet::ParseFailed => e
    puts "Parse failed (expected for profiling): #{e.message[0..100]}"
  end
end

puts "\n=== Memory Profile Results ==="
puts "Total allocated: #{report.total_allocated_memsize / 1024.0 / 1024.0} MB"
puts "Total retained: #{report.total_retained_memsize / 1024.0 / 1024.0} MB"
puts

puts "Allocated objects by class:"
report.allocated_memory_by_class.first(15).each do |entry|
  puts "  #{entry.inspect}"
end
puts

# Try to get context if available
if context
  stats = context.cache_stats
  puts "\n=== Cache Statistics ==="
  puts "Atoms cached: #{stats[:atoms_cached]}"
  puts "Total positions cached: #{stats[:total_positions]}"
  puts "Max positions per atom: #{stats[:max_positions_per_atom]}"
  puts "Avg positions per atom: #{stats[:avg_positions_per_atom].round(2)}"

  # Calculate memory used by cache
  cache_size_estimate = stats[:total_positions] * 100 # rough estimate bytes per cache entry
  puts "Estimated cache memory: #{cache_size_estimate / 1024.0} KB"
end

puts "\nDone!"
