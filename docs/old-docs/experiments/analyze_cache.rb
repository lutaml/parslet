#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'json'
require_relative '../lib/parslet'
require_relative '../example/json'

# Create test JSON
json_data = {
  "users" => (1..50).map { |i|
    {
      "id" => i,
      "name" => "User #{i}",
      "email" => "user#{i}@example.com"
    }
  }
}
json_content = JSON.generate(json_data)

puts "Input size: #{json_content.bytesize} bytes"
puts "Analyzing cache behavior..."
puts

# Extend Context to track cache hits/misses without overriding eviction logic
module Parslet
  module Atoms
    class Context
      attr_reader :cache, :cache_hits, :cache_misses

      alias_method :orig_initialize, :initialize
      def initialize(reporter = Parslet::ErrorReporter::Tree.new)
        orig_initialize(reporter)
        @cache_hits = 0
        @cache_misses = 0
      end

      # Wrap the fetch operation to track hits/misses
      alias_method :orig_try_with_cache, :try_with_cache
      def try_with_cache(obj, source, consume_all)
        unless obj.cached?
          return obj.try(source, self, consume_all)
        end

        beg = source.bytepos
        had_entry = @cache[beg] && @cache[beg].key?(obj.object_id)

        result = orig_try_with_cache(obj, source, consume_all)

        if had_entry
          @cache_hits += 1
        else
          @cache_misses += 1
        end

        result
      end

      def cache_stats
        total_entries = 0
        total_positions = 0
        max_positions = 0
        position_counts = []

        @cache.each do |atom, positions|
          positions_count = positions.size
          total_entries += 1
          total_positions += positions_count
          max_positions = positions_count if positions_count > max_positions
          position_counts << positions_count
        end

        position_counts.sort!
        median = if position_counts.empty?
                   0
                 elsif position_counts.size.odd?
                   position_counts[position_counts.size / 2]
                 else
                   median_idx = position_counts.size / 2
                   (position_counts[median_idx - 1] + position_counts[median_idx]) / 2.0
                 end

        {
          atoms_cached: total_entries,
          total_positions: total_positions,
          max_positions_per_atom: max_positions,
          median_positions_per_atom: median,
          avg_positions_per_atom: total_entries > 0 ? total_positions.to_f / total_entries : 0,
          cache_hits: @cache_hits,
          cache_misses: @cache_misses,
          hit_rate: @cache_hits > 0 ? (@cache_hits.to_f / (@cache_hits + @cache_misses) * 100) : 0
        }
      end
    end
  end
end

parser = MyJson::Parser.new
context = Parslet::Atoms::Context.new

begin
  # Parse with our instrumented context - use parse_with_debug
  source = Parslet::Source.new(json_content)
  result = parser.root.apply(source, context, true)
  success, value = result

  if success
    puts "✓ Parse successful!"
  else
    puts "✗ Parse failed"
  end
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(3).join("\n")
end

puts "\n=== Cache Analysis ==="
stats = context.cache_stats
puts "Atoms cached: #{stats[:atoms_cached]}"
puts "Total cache entries: #{stats[:total_positions]}"
puts "Max positions per atom: #{stats[:max_positions_per_atom]}"
puts "Median positions per atom: #{stats[:median_positions_per_atom]}"
puts "Avg positions per atom: #{stats[:avg_positions_per_atom].round(2)}"
puts "\nCache hits: #{stats[:cache_hits]}"
puts "Cache misses: #{stats[:cache_misses]}"
puts "Hit rate: #{stats[:hit_rate].round(2)}%"

# Memory estimate
cache_size_estimate = stats[:total_positions] * 120 # bytes per entry (key + value pair)
puts "\nEstimated cache memory: #{cache_size_estimate / 1024.0} KB"
puts "Input to cache ratio: #{(cache_size_estimate.to_f / json_content.bytesize).round(2)}x"

puts "\nDone!"
