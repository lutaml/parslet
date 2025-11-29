#!/usr/bin/env ruby
# frozen_string_literal: true

# Analyze hot spots from profiling data
puts "Top Hot Spots from JSON Parser Profile (after Phase 42):"
puts "=" * 70
puts

hot_spots = [
  { name: "Hash#delete_if", percent: 22.47, calls: 889870, status: "✅ FIXED in Phase 42" },
  { name: "Context#try_with_cache", percent: 10.67, calls: 7313380, status: "Core caching logic" },
  { name: "Integer#<", percent: 10.44, calls: 178529941, status: "⚠️ 178M calls!" },
  { name: "Base#apply", percent: 5.12, calls: 7313380, status: "Core parsing" },
  { name: "CanFlatten#flatten", percent: 3.46, calls: 2990295, status: "Array flattening" },
  { name: "StringScanner#charpos", percent: 3.31, calls: 915210, status: "Position tracking" },
  { name: "Source#bytepos", percent: 2.87, calls: 15478215, status: "Position getter" },
  { name: "Sequence#try", percent: 2.84, calls: 1709910, status: "Core parsing" },
  { name: "Str#try", percent: 2.82, calls: 1717390, status: "String matching" }
]

hot_spots.each_with_index do |spot, i|
  puts "#{i + 1}. #{spot[:name]}"
  puts "   #{spot[:percent]}% of runtime, #{spot[:calls].to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse} calls"
  puts "   Status: #{spot[:status]}"
  puts
end

puts "=" * 70
puts "\nNext optimization target: Integer#< with 178M calls (10.44%)"
puts "This suggests heavy comparison operations in tight loops."
puts "\nLikely sources:"
puts "- Position/byte offset comparisons"
puts "- Array bounds checking"
puts "- Cache eviction threshold checks"
puts "- Loop conditions in repetitions"
