#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'parslet'
require 'json'

# Instrumented Context to track cache hit/miss rates by atom class
class InstrumentedContext < Parslet::Atoms::Context
  attr_reader :stats

  def initialize(*args)
    super
    @stats = Hash.new { |h, k| h[k] = { hits: 0, misses: 0, calls: 0 } }
  end

  def try_with_cache(obj, source, consume_all)
    return super unless obj.cached?

    beg = source.bytepos
    cache_key = obj.object_id
    atom_class = obj.class.name.split('::').last

    @stats[atom_class][:calls] += 1

    # Track furthest position and evict old cache entries PERIODICALLY
    if beg > @max_position
      @max_position = beg
      @eviction_counter += 1

      if @eviction_counter >= @eviction_frequency
        @eviction_counter = 0
        min_keep_pos = beg - @eviction_threshold
        @cache.delete_if { |pos, _| pos < min_keep_pos }
      end
    end

    # Check if cached
    if @cache[beg].key?(cache_key)
      @hit_counts[cache_key] += 1
      @stats[atom_class][:hits] += 1
      result, advance = @cache[beg][cache_key]
      source.bytepos = beg + advance
      return result
    end

    # Cache miss
    @miss_counts[cache_key] += 1
    @stats[atom_class][:misses] += 1
    result = obj.try(source, self, consume_all)
    advance = source.bytepos - beg

    # Cache with selective memoization
    total_attempts = @hit_counts[cache_key] + @miss_counts[cache_key]
    if total_attempts <= @cache_threshold || @hit_counts[cache_key] > 0
      @cache[beg][cache_key] = [result, advance]
    end

    result
  end

  def print_stats
    puts "\n" + "=" * 70
    puts "CACHE EFFICIENCY BY ATOM TYPE"
    puts "=" * 70
    puts

    total_calls = 0
    total_hits = 0
    total_misses = 0

    sorted_stats = @stats.sort_by { |_, v| -v[:calls] }

    puts "%-20s %12s %12s %12s %8s" % ["Atom Type", "Calls", "Hits", "Misses", "Hit%"]
    puts "-" * 70

    sorted_stats.each do |atom_class, data|
      calls = data[:calls]
      hits = data[:hits]
      misses = data[:misses]
      hit_rate = calls > 0 ? (hits.to_f / calls * 100).round(2) : 0

      total_calls += calls
      total_hits += hits
      total_misses += misses

      puts "%-20s %12d %12d %12d %7.2f%%" % [atom_class, calls, hits, misses, hit_rate]
    end

    puts "-" * 70
    overall_hit_rate = total_calls > 0 ? (total_hits.to_f / total_calls * 100).round(2) : 0
    puts "%-20s %12d %12d %12d %7.2f%%" % ["TOTAL", total_calls, total_hits, total_misses, overall_hit_rate]
    puts

    # Calculate redundancy
    redundant_calls = total_misses  # Each miss means we had to parse
    puts "Analysis:"
    puts "- Total parse attempts: #{total_calls.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "- Cache hits (avoided parsing): #{total_hits.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "- Cache misses (had to parse): #{total_misses.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse}"
    puts "- Overall efficiency: #{overall_hit_rate.round(2)}%"
    puts

    # Identify worst offenders
    puts "Biggest Opportunities (low hit rate + high call count):"
    worst = sorted_stats.select { |_, v| v[:calls] > 10000 }
                        .map { |k, v| [k, v, (v[:hits].to_f / v[:calls] * 100)] }
                        .sort_by { |_, _, rate| rate }
                        .first(5)

    worst.each do |atom, data, rate|
      potential_savings = data[:misses]
      puts "- #{atom}: #{rate.round(2)}% hit rate, #{potential_savings.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} redundant parses"
    end
  end
end

# Monkey-patch Base to use instrumented context
module Parslet::Atoms
  class Base
    def parse_with_debug(source, options = {})
      source = case source
        when String then Parslet::Source.new(source)
        when Source then source
      end

      context = InstrumentedContext.new(options[:reporter])

      result = apply(source, context, true)

      # If we didn't succeed the parse, raise an exception for the user.
      # Success is indicated by Parslet::Atoms::Context#succ, which always
      # returns [true, something].
      unless result.first
        cause = context.instance_variable_get(:@reporter).last_cause
        raise Parslet::ParseFailed.new(source, cause)
      end

      context.print_stats
      return flatten(result.last, true)
    end
  end
end

# JSON parser
class JSONParser < Parslet::Parser
  rule(:value) { object | array | string | number | true_val | false_val | null_val | whitespace.repeat }
  rule(:object) { str('{') >> whitespace.maybe >> (pair >> (str(',') >> pair).repeat).maybe >> whitespace.maybe >> str('}') }
  rule(:pair) { string >> whitespace.maybe >> str(':') >> whitespace.maybe >> value }
  rule(:array) { str('[') >> whitespace.maybe >> (value >> (str(',') >> value).repeat).maybe >> whitespace.maybe >> str(']') }
  rule(:string) { str('"') >> (str('\\') >> any | str('"').absent? >> any).repeat.as(:string) >> str('"') }
  rule(:number) { (str('-').maybe >> match('[0-9]').repeat(1) >> (str('.') >> match('[0-9]').repeat(1)).maybe).as(:number) }
  rule(:true_val) { str('true').as(:true) }
  rule(:false_val) { str('false').as(:false) }
  rule(:null_val) { str('null').as(:null) }
  rule(:whitespace) { match('\s').repeat(1) }
  root(:value)
end

# Test data
json_data = {
  "users" => (1..50).map { |i|
    {
      "id" => i,
      "name" => "User #{i}",
      "email" => "user#{i}@example.com",
      "active" => i.even?,
      "tags" => ["tag1", "tag2", "tag3"],
      "meta" => { "created" => "2025-01-01", "updated" => "2025-01-15" }
    }
  }
}.to_json

puts "Analyzing cache efficiency for JSON parser"
puts "Input size: #{json_data.bytesize} bytes"
puts

parser = JSONParser.new
result = parser.value.parse_with_debug(json_data)

puts "\nParse successful!"
