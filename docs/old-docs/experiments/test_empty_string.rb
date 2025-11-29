#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/parslet'

include Parslet

# Test what empty strings do
empty = str('')

puts "Testing str(''):"
begin
  result = empty.parse('')
  puts "  empty.parse('') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

begin
  result = empty.parse('a')
  puts "  empty.parse('a') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

# Test in alternatives
puts "\nTesting str('') | str('a'):"
alt1 = str('') | str('a')
begin
  result = alt1.parse('')
  puts "  parse('') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

begin
  result = alt1.parse('a')
  puts "  parse('a') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

# Test str('a') | str('')
puts "\nTesting str('a') | str(''):"
alt2 = str('a') | str('')
begin
  result = alt2.parse('')
  puts "  parse('') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

begin
  result = alt2.parse('a')
  puts "  parse('a') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

# Test str('a') | str('') | str('b')
puts "\nTesting str('a') | str('') | str('b'):"
alt3 = str('a') | str('') | str('b')
begin
  result = alt3.parse('')
  puts "  parse('') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

begin
  result = alt3.parse('a')
  puts "  parse('a') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end

begin
  result = alt3.parse('b')
  puts "  parse('b') => #{result.inspect}"
rescue => e
  puts "  ERROR: #{e.message}"
end
