#!/usr/bin/env ruby

require 'bundler/setup'
require 'stackprof'
require_relative '../lib/parslet'

# Profile current hot spots after Phase 52 optimizations
# This will help identify the next optimization target

class SimpleParser < Parslet::Parser
  rule(:value) { str('"') >> (str('"').absent? >> any).repeat >> str('"') }
  rule(:pair) { value.as(:key) >> str(':') >> value.as(:val) }
  rule(:object) { str('{') >> pair >> str('}') }
  root(:object)
end

class NestedParser < Parslet::Parser
  rule(:spaces) { match('\s').repeat(1) }
  rule(:spaces?) { spaces.maybe }

  rule(:value) {
    str('"') >> (str('"').absent? >> any).repeat.as(:string) >> str('"') |
    str('[') >> spaces? >> array_items >> spaces? >> str(']') |
    object
  }

  rule(:pair) {
    spaces? >>
    str('"') >> match('[^"]').repeat.as(:key) >> str('"') >>
    spaces? >> str(':') >> spaces? >>
    value.as(:val)
  }

  rule(:array_items) {
    (value >> (spaces? >> str(',') >> spaces? >> value).repeat).maybe
  }

  rule(:object) {
    str('{') >> spaces? >>
    (pair >> (spaces? >> str(',') >> spaces? >> pair).repeat).maybe >>
    spaces? >> str('}')
  }

  root(:object)
end

SIMPLE_INPUT = '{"key":"value"}'
NESTED_INPUT = '{"a":"1","b":["2","3"]}'

puts "Ruby Version: #{RUBY_VERSION}"
puts "Profiling hot spots after Phase 52 optimizations..."
puts

# Warm up
parser = NestedParser.new
100.times { parser.parse(NESTED_INPUT) }

# Profile with StackProf
StackProf.run(mode: :cpu, out: 'tmp/stackprof-phase54-cpu.dump', raw: true) do
  1000.times { parser.parse(NESTED_INPUT) }
end

puts "Profile saved to tmp/stackprof-phase54-cpu.dump"
puts
puts "Analyzing top methods..."
puts "=" * 80

# Load and analyze
results = StackProf::Report.new(Marshal.load(File.binread('tmp/stackprof-phase54-cpu.dump')))

puts "\nTop 30 methods by total time:"
puts "-" * 80

results.print_text(false, 30)

puts "\n" + "=" * 80
puts "Analysis Guide"
puts "=" * 80
puts <<~GUIDE

Look for:
1. Methods in lib/parslet/atoms/ with high sample counts
2. Methods called frequently (high total %)
3. Methods with instance variable access that could be cached
4. Methods with repeated calculations that could be memoized

Candidates for Phase 54:
- Repetition#try (if high in profile)
- Re#try (regex matching)
- Str#try (string matching)
- Lookahead#try
- Any other atoms/* methods with @ivar access

Avoid:
- Methods already optimized in Phase 52 (Sequence, Alternative, Named)
- Methods with low call counts
- Methods without instance variable access

Decision Criteria:
- Method must be in top 20 by total time
- Method must access instance variables
- Expected improvement: >5%
GUIDE
