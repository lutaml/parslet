#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'parsers/pascal_parser'

# Test Pascal parser on all fixtures
fixtures_dir = File.join(__dir__, 'fixtures', 'pascal')
fixtures = Dir.glob(File.join(fixtures_dir, '*.pas')).sort

puts "=" * 80
puts "PASCAL PARSER TESTING"
puts "=" * 80
puts

fixtures.each do |file|
  filename = File.basename(file)
  content = File.read(file)
  parser = PascalParser.new

  print "Testing #{filename.ljust(25)} (#{content.bytesize.to_s.rjust(7)} bytes)... "

  begin
    start_time = Time.now
    parser.parse(content)
    elapsed = Time.now - start_time

    throughput_kb = content.bytesize / elapsed / 1024
    throughput_mb = content.bytesize / elapsed / 1024 / 1024

    puts "✓ #{(elapsed * 1000).round(2).to_s.rjust(8)}ms  #{throughput_mb.round(4).to_s.rjust(8)} MB/s"
  rescue Parslet::ParseFailed => e
    puts "✗ FAILED"
    puts e.parse_failure_cause.ascii_tree
  end
end

puts
puts "=" * 80
