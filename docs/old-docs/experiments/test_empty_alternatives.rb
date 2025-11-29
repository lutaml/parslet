#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'parslet'
require 'benchmark'

include Parslet

puts "Testing empty string behavior in Parslet"
puts "=" * 60

# Test 1: What does str('') do?
puts "\nTest 1: str('') behavior"
empty = str('')
begin
  result = empty.parse('')
  puts "  str('').parse('') => #{result.inspect}"
rescue => e
  puts "  str('').parse('') => ERROR: #{e.message}"
end

begin
  result = empty.parse('abc')
  puts "  str('').parse('abc') => #{result.inspect}"
rescue => e
  puts "  str('').parse('abc') => ERROR: #{e.message}"
end

# Test 2: str('') | str('a')
puts "\nTest 2: str('') | str('a') behavior"
choice1 = str('') | str('a')
%w['' 'a' 'ab' 'b'].each do |input|
  test_input = eval(input)
  begin
    result = choice1.parse(test_input)
    puts "  (str('') | str('a')).parse(#{input}) => #{result.inspect}"
  rescue => e
    puts "  (str('') | str('a')).parse(#{input}) => ERROR: #{e.class}"
  end
end

# Test 3: str('a') | str('')
puts "\nTest 3: str('a') | str('') behavior (reversed order)"
choice2 = str('a') | str('')
%w['' 'a' 'ab' 'b'].each do |input|
  test_input = eval(input)
  begin
    result = choice2.parse(test_input)
    puts "  (str('a') | str('')).parse(#{input}) => #{result.inspect}"
  rescue => e
    puts "  (str('a') | str('')).parse(#{input}) => ERROR: #{e.class}"
  end
end

# Test 4: str('a').maybe behavior for comparison
puts "\nTest 4: str('a').maybe for comparison"
maybe_a = str('a').maybe
%w['' 'a' 'ab' 'b'].each do |input|
  test_input = eval(input)
  begin
    result = maybe_a.parse(test_input)
    puts "  str('a').maybe.parse(#{input}) => #{result.inspect}"
  rescue => e
    puts "  str('a').maybe.parse(#{input}) => ERROR: #{e.class}"
  end
end

# Test 5: Multiple alternatives with empty
puts "\nTest 5: str('a') | str('b') | str('') behavior"
choice3 = str('a') | str('b') | str('')
%w['' 'a' 'b' 'c'].each do |input|
  test_input = eval(input)
  begin
    result = choice3.parse(test_input)
    puts "  (str('a') | str('b') | str('')).parse(#{input}) => #{result.inspect}"
  rescue => e
    puts "  (str('a') | str('')).parse(#{input}) => ERROR: #{e.class}"
  end
