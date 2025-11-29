#!/usr/bin/env ruby
# Benchmark to test impact of all construction-time optimizations:
# - Phase 21: Sequence flattening
# - Phase 24: String concatenation
# - Phase 25: Alternative flattening

require 'bundler/setup'
require 'parslet'
require 'benchmark/ips'

# Test 1: Sequence flattening benefit
# Deep nesting of sequences
def test_sequence_flattening
  parser = Parslet.str('a')
  100.times { parser = parser >> Parslet.str('a') }
  parser
end

# Test 2: String concatenation benefit
# Multiple adjacent strings in sequence
def test_string_concatenation
  Parslet.str('h') >> Parslet.str('t') >> Parslet.str('t') >> Parslet.str('p') >>
    Parslet.str(':') >> Parslet.str('/') >> Parslet.str('/')
end

# Test 3: Alternative flattening benefit
# Deep nesting of alternatives
def test_alternative_flattening
  parser = Parslet.str('a')
  50.times { |i| parser = parser | Parslet.str((97 + i).chr) }
  parser
end

# Test 4: Combined benefits
# Grammar that uses all optimizations
class OptimizedGrammar < Parslet::Parser
  rule(:protocol) { str('http') >> str('s').maybe | str('ftp') }
  rule(:separator) { str(':') >> str('/') >> str('/') }
  rule(:domain_part) { match('[a-z0-9]').repeat(1) }
  rule(:domain) { domain_part >> (str('.') >> domain_part).repeat }
  rule(:url) { protocol >> separator >> domain }
  root(:url)
end

puts "=" * 80
puts "Testing Construction-Time Optimizations"
puts "Phases 21, 24, 25: Flattening & String Concatenation"
puts "=" * 80
puts

# Benchmark grammar construction time
Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Deep sequence (100 levels)") do
    test_sequence_flattening
  end

  x.report("String concatenation (7 strings)") do
    test_string_concatenation
  end

  x.report("Deep alternative (50 options)") do
    test_alternative_flattening
  end

  x.report("Full grammar construction") do
    OptimizedGrammar.new
  end

  x.compare!
end

puts
puts "=" * 80
puts "Testing Parse Performance with Optimized Grammars"
puts "=" * 80
puts

# Create parsers outside benchmark
seq_parser = test_sequence_flattening
str_parser = test_string_concatenation
alt_parser = test_alternative_flattening
url_parser = OptimizedGrammar.new

# Prepare test inputs
seq_input = 'a' * 101
str_input = 'http://'
alt_input = 'z'  # Last alternative
url_input = 'https://www.example.com'

Benchmark.ips do |x|
  x.config(time: 5, warmup: 2)

  x.report("Parse deep sequence") do
    seq_parser.parse(seq_input)
  end

  x.report("Parse concatenated strings") do
    str_parser.parse(str_input)
  end

  x.report("Parse alternative (last)") do
    alt_parser.parse(alt_input)
  end

  x.report("Parse full URL") do
    url_parser.parse(url_input)
  end

  x.compare!
end

puts
puts "=" * 80
puts "Grammar Structure Analysis"
puts "=" * 80
puts

# Show the benefit of optimizations through inspection
puts "\nString concatenation benefit:"
puts "  Before optimization: str('h') >> str('t') >> str('t') >> str('p')"
puts "  Would create: 4 Str atoms"
puts "  After optimization: #{str_parser.inspect}"
puts "  Creates: 1 Str atom"
puts

puts "Sequence flattening benefit:"
deep_seq = Parslet.str('a') >> Parslet.str('b') >> Parslet.str('c')
puts "  Expression: str('a') >> str('b') >> str('c')"
puts "  Structure: #{deep_seq.inspect}"
puts "  Parslets count: #{deep_seq.parslets.size} (flattened)"
puts

puts "Alternative flattening benefit:"
deep_alt = Parslet.str('a') | Parslet.str('b') | Parslet.str('c')
puts "  Expression: str('a') | str('b') | str('c')"
puts "  Structure: #{deep_alt.inspect}"
puts "  Alternatives count: #{deep_alt.alternatives.size} (flattened)"
puts

puts "=" * 80
puts "Summary"
puts "=" * 80
puts "All optimizations reduce:"
puts "  - Object allocation during grammar construction"
puts "  - Parse tree depth"
puts "  - Number of atoms to traverse during parsing"
puts
puts "This leads to:"
puts "  - Faster grammar construction"
puts "  - Lower memory usage"
puts "  - More efficient parsing"
