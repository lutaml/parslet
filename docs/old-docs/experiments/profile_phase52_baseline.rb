#!/usr/bin/env ruby
# frozen_string_literal: true

# Phase 52 Baseline: Measure current performance before ivar caching

require 'bundler/setup'
require 'parslet'
require 'benchmark/ips'
require 'json'

# Simple JSON parser
class JSONParser < Parslet::Parser
  root(:value)

  rule(:value) {
    object | array | string | number | true_val | false_val | null_val
  }

  rule(:object) {
    str('{') >> spaces? >>
    (pair >> (str(',') >> spaces? >> pair).repeat).maybe.as(:object) >>
    spaces? >> str('}')
  }

  rule(:pair) {
    string.as(:key) >> spaces? >> str(':') >> spaces? >> value.as(:val)
  }

  rule(:array) {
    str('[') >> spaces? >>
    (value >> (str(',') >> spaces? >> value).repeat).maybe.as(:array) >>
    spaces? >> str(']')
  }

  rule(:string) {
    str('"') >> (
      str('\\') >> any |
      str('"').absent? >> any
    ).repeat.as(:string) >> str('"')
  }

  rule(:number) {
    (str('-').maybe >> match('[1-9]') >> match('[0-9]').repeat |
     str('0')).as(:integer) >>
    (str('.') >> match('[0-9]').repeat(1)).maybe >>
    (match('[eE]') >> match('[+-]').maybe >> match('[0-9]').repeat(1)).maybe
  }

  rule(:true_val)  { str('true').as(:true) }
  rule(:false_val) { str('false').as(:false) }
  rule(:null_val)  { str('null').as(:null) }

  rule(:spaces)    { match('\s').repeat(1) }
  rule(:spaces?)   { spaces.maybe }
end

# Test data - more substantial than Phase 51
test_cases = [
  {
    name: "Simple",
    input: '{"name":"test","value":123}'
  },
  {
    name: "Nested",
    input: '{"user":{"name":"Alice","age":30},"items":[1,2,3,4,5]}'
  },
  {
    name: "Array Heavy",
    input: '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20]'
  }
]

parser = JSONParser.new

puts "=" * 80
puts "Phase 52 Baseline: Instance Variable Caching"
puts "=" * 80
puts
puts "Ruby Version: #{RUBY_VERSION}"
puts "YJIT: #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? 'enabled' : 'disabled'}"
puts

test_cases.each do |test_case|
  input = test_case[:input]

  puts "Testing: #{test_case[:name]} (#{input.bytesize} bytes)"

  # Warmup
  3.times { parser.parse(input) }

  # Benchmark
  Benchmark.ips do |x|
    x.config(time: 3, warmup: 1)

    x.report("#{test_case[:name]}") do
      parser.parse(input)
    end
  end

  puts
end

puts "=" * 80
puts "Baseline Complete"
puts "=" * 80
puts
puts "Next: Implement ivar caching in Sequence#try and re-benchmark"
