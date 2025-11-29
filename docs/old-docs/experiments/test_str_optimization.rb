#!/usr/bin/env ruby
require 'bundler/setup'
require 'benchmark/ips'
require 'parslet'

# Simple parser that uses many single-character strings
class TestParser < Parslet::Parser
  rule(:space) { str(' ') }
  rule(:comma) { str(',') }
  rule(:colon) { str(':') }
  rule(:lbrace) { str('{') }
  rule(:rbrace) { str('}') }
  rule(:digit) { match['0-9'] }
  rule(:number) { digit.repeat(1) }
  rule(:kvpair) { number >> colon >> space.maybe >> number }
  rule(:object) { lbrace >> kvpair >> (comma >> space.maybe >> kvpair).repeat >> rbrace }
  root(:object)
end

parser = TestParser.new
input = '{1:2,3:4,5:6,7:8,9:10,11:12,13:14,15:16,17:18,19:20}'

puts 'Testing single-character str() optimization...'
puts "Input: #{input}"
puts "Input length: #{input.length} characters"
puts

# Verify it works
result = parser.parse(input)
puts "Parse successful: #{result.inspect}"
puts

Benchmark.ips do |x|
  x.config(time: 3, warmup: 1)
  x.report('parse') { parser.parse(input) }
end
