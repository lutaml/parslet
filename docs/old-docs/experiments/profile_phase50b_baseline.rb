#!/usr/bin/env ruby
# frozen_string_literal: true

# Baseline benchmark BEFORE frozen string literals optimization
# Measures: object allocation, GC frequency, performance, memory

require_relative '../lib/parslet'
require 'benchmark/ips'
require 'json'

# Sample JSON parser for testing
class MyJson < Parslet::Parser
  rule(:space) { match('\s').repeat }
  rule(:space?) { space.maybe }

  rule(:comma) { space? >> str(',') >> space? }
  rule(:lbrace) { str('{') >> space? }
  rule(:rbrace) { space? >> str('}') }
  rule(:lbracket) { str('[') >> space? }
  rule(:rbracket) { space? >> str(']') }
  rule(:colon) { space? >> str(':') >> space? }

  rule(:true_lit) { str('true').as(:true) }
  rule(:false_lit) { str('false').as(:false) }
  rule(:null_lit) { str('null').as(:null) }

  rule(:digit) { match['0-9'] }
  rule(:number) do
    (str('-').maybe >> digit.repeat(1) >>
     (str('.') >> digit.repeat(1)).maybe).as(:number)
  end

  rule(:string_char) { match['^\\\\"'] | (str('\\') >> any) }
  rule(:string) do
    str('"') >> string_char.repeat.as(:string) >> str('"')
  end

  rule(:value) do
    string | number | object | array |
    true_lit | false_lit | null_lit
  end

  rule(:pair) do
    (string.as(:key) >> colon >> value.as(:val)).as(:pair)
  end

  rule(:object) do
    (lbrace >> (pair >> (comma >> pair).repeat).maybe.as(:object) >> rbrace)
  end

  rule(:array) do
    (lbracket >> (value >> (comma >> value).repeat).maybe.as(:array) >> rbracket)
  end

  root(:value)
end

# Test data
SIMPLE_JSON = '{"name":"test","value":123,"active":true}'
MEDIUM_JSON = '{"users":[{"id":1,"name":"Alice","age":30},{"id":2,"name":"Bob","age":25}],"count":2}'
COMPLEX_JSON = '{"data":{"items":[{"id":1,"tags":["a","b"],"meta":{"created":"2024-01-01"}},{"id":2,"tags":["c"],"meta":{"created":"2024-01-02"}}],"total":2}}'

parser = MyJson.new

puts "=" * 80
puts "Phase 50b Baseline Benchmark (BEFORE frozen string literals)"
puts "=" * 80
puts

# Baseline GC statistics
puts "1. Garbage Collection Analysis"
puts "-" * 80

GC.start(full_mark: true, immediate_sweep: true)
GC.disable

before_gc_count = GC.count
before_gc_stat = GC.stat

# Parse 100 times
100.times { parser.parse(MEDIUM_JSON) }

after_gc_stat = GC.stat
GC.enable
GC.start(full_mark: true, immediate_sweep: true)
after_gc_count = GC.count

puts "GC runs during 100 parses: #{after_gc_count - before_gc_count}"
puts "GC runs per parse: #{(after_gc_count - before_gc_count) / 100.0}"
puts

# Baseline object allocation
puts "2. Object Allocation Analysis"
puts "-" * 80

before_allocated = GC.stat[:total_allocated_objects]
parser.parse(MEDIUM_JSON)
after_allocated = GC.stat[:total_allocated_objects]

objects_per_parse = after_allocated - before_allocated
puts "Objects allocated per parse: #{objects_per_parse}"
puts

# Baseline performance
puts "3. Performance Benchmark"
puts "-" * 80

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("simple parse") do
    parser.parse(SIMPLE_JSON)
  end

  x.report("medium parse") do
    parser.parse(MEDIUM_JSON)
  end

  x.report("complex parse") do
    parser.parse(COMPLEX_JSON)
  end

  x.compare!
end

puts

# Baseline memory usage
puts "4. Memory Usage Analysis"
puts "-" * 80

# Measure memory before
GC.start(full_mark: true, immediate_sweep: true)
mem_before = `ps -o rss= -p #{Process.pid}`.to_i

# Parse many times
1000.times { parser.parse(MEDIUM_JSON) }

# Measure memory after
GC.start(full_mark: true, immediate_sweep: true)
mem_after = `ps -o rss= -p #{Process.pid}`.to_i

puts "Memory before: #{mem_before} KB"
puts "Memory after:  #{mem_after} KB"
puts "Memory delta:  #{mem_after - mem_before} KB"
puts "Memory per parse: #{(mem_after - mem_before) / 1000.0} KB"
puts

# Detailed GC statistics
puts "5. Detailed GC Statistics"
puts "-" * 80

gc_stat = GC.stat
puts "Heap allocated pages: #{gc_stat[:heap_allocated_pages]}"
puts "Heap sorted length: #{gc_stat[:heap_sorted_length]}"
puts "Heap allocatable pages: #{gc_stat[:heap_allocatable_pages]}"
puts "Heap available slots: #{gc_stat[:heap_available_slots]}"
puts "Heap live slots: #{gc_stat[:heap_live_slots]}"
puts "Heap free slots: #{gc_stat[:heap_free_slots]}"
puts "Heap final slots: #{gc_stat[:heap_final_slots]}"
puts "Heap tomb pages: #{gc_stat[:heap_tomb_pages]}"
puts "Total allocated objects: #{gc_stat[:total_allocated_objects]}"
puts "Total freed objects: #{gc_stat[:total_freed_objects]}"
puts "Minor GC count: #{gc_stat[:minor_gc_count]}"
puts "Major GC count: #{gc_stat[:major_gc_count]}"
puts

puts "=" * 80
puts "Baseline metrics saved for comparison with post-optimization results"
puts "=" * 80
