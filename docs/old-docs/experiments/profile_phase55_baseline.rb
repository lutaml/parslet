#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark/ips'
require_relative 'parsers/pascal_parser'

# Phase 55 Baseline: Before Lookahead ivar caching
# This tests parsers with lookahead operations

class SimpleParser < Parslet::Parser
  # Parser with lookahead
  rule(:keyword) { str('if').absent? >> match('[a-z]').repeat(1) }
  rule(:identifier) { keyword }
  root(:identifier)
end

class ComplexParser < Parslet::Parser
  # Multiple lookaheads
  rule(:not_keyword) {
    (str('if') | str('then') | str('else')).absent? >>
    match('[a-z]').repeat(1)
  }
  rule(:expression) { not_keyword >> (str(',') >> not_keyword).repeat }
  root(:expression)
end

parser1 = SimpleParser.new
parser2 = ComplexParser.new

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)

  x.report('simple lookahead') do
    parser1.parse('identifier')
  end

  x.report('complex lookahead') do
    parser2.parse('foo,bar,baz')
  end

  x.compare!
end

puts "\n=== Memory Allocation ==="
require 'objspace'

GC.start
GC.disable

before = ObjectSpace.count_objects
10_000.times { parser1.parse('identifier') }
after = ObjectSpace.count_objects

GC.enable

puts "Total new objects: #{after[:TOTAL] - before[:TOTAL]}"
puts "T_DATA: #{after[:T_DATA] - before[:T_DATA]}"
puts "T_OBJECT: #{after[:T_OBJECT] - before[:T_OBJECT]}"
puts "T_STRING: #{after[:T_STRING] - before[:T_STRING]}"
