#!/usr/bin/env ruby
# frozen_string_literal: true

require 'bundler/setup'
require 'benchmark'
require_relative '../lib/parslet'

# Test data
email_data = "user@example.com, admin@test.org, hello@world.net\n" * 100
boolean_data = "(a and b) or (c and not d)\n" * 50
comment_data = "/* comment */ code /* more comments */ more code\n" * 100

puts "=" * 80
puts "TESTING EXAMPLE PARSERS"
puts "=" * 80

# Email Parser
begin
  require_relative '../example/email_parser'

  puts "\n#{'-' * 80}"
  puts "EMAIL PARSER"
  puts "Data size: #{email_data.bytesize} bytes"
  puts "#{'-' * 80}"

  parser = EmailParser.new
  time = Benchmark.measure do
    10.times { parser.parse(email_data) }
  end

  avg_time = time.real / 10
  throughput = (email_data.bytesize / 1_024.0 / 1_024.0) / avg_time

  puts "Average time: #{(avg_time * 1000).round(2)} ms"
  puts "Throughput: #{throughput.round(4)} MB/sec"
rescue => e
  puts "Error: #{e.message}"
end

# Boolean Algebra Parser
begin
  require_relative '../example/boolean_algebra'

  puts "\n#{'-' * 80}"
  puts "BOOLEAN ALGEBRA PARSER"
  puts "Data size: #{boolean_data.bytesize} bytes"
  puts "#{'-' * 80}"

  parser = BooleanAlgebra.new
  time = Benchmark.measure do
    10.times { parser.parse(boolean_data) }
  end

  avg_time = time.real / 10
  throughput = (boolean_data.bytesize / 1_024.0 / 1_024.0) / avg_time

  puts "Average time: #{(avg_time * 1000).round(2)} ms"
  puts "Throughput: #{throughput.round(4)} MB/sec"
rescue => e
  puts "Error: #{e.message}"
end

# Comments Parser
begin
  require_relative '../example/comments'

  puts "\n#{'-' * 80}"
  puts "COMMENTS PARSER"
  puts "Data size: #{comment_data.bytesize} bytes"
  puts "#{'-' * 80}"

  parser = CommentsParser.new
  time = Benchmark.measure do
    10.times { parser.parse(comment_data) }
  end

  avg_time = time.real / 10
  throughput = (comment_data.bytesize / 1_024.0 / 1_024.0) / avg_time

  puts "Average time: #{(avg_time * 1000).round(2)} ms"
  puts "Throughput: #{throughput.round(4)} MB/sec"
rescue => e
  puts "Error: #{e.message}"
end

# String Parser
begin
  require_relative '../example/string_parser'

  string_data = '"hello world" "foo bar" "test string"\n' * 100

  puts "\n#{'-' * 80}"
  puts "STRING PARSER"
  puts "Data size: #{string_data.bytesize} bytes"
  puts "#{'-' * 80}"

  parser = StringParser.new
  time = Benchmark.measure do
    10.times { parser.parse(string_data) }
  end

  avg_time = time.real / 10
  throughput = (string_data.bytesize / 1_024.0 / 1_024.0) / avg_time

  puts "Average time: #{(avg_time * 1000).round(2)} ms"
  puts "Throughput: #{throughput.round(4)} MB/sec"
rescue => e
  puts "Error: #{e.message}"
end

puts "\n#{'=' * 80}"
puts "Testing complete!"
puts "=" * 80
