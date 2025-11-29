#!/usr/bin/env ruby
# Profile the JSON parser using stackprof

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('../example', __dir__)

require 'parslet'
require 'stackprof'
require 'stringio'
require 'fileutils'

# Suppress output from example file
original_stdout = $stdout
original_stderr = $stderr
$stdout = StringIO.new
$stderr = StringIO.new

require_relative '../example/json'

$stdout = original_stdout
$stderr = original_stderr

# Generate test data
def generate_json_data(size_multiplier = 100)
  users = (1..10 * size_multiplier).map do |i|
    %Q({"id":#{i},"name":"User #{i}","email":"user#{i}@example.com","active":#{i.even?},"score":#{i * 1.5},"tags":["tag#{i}","tag#{i + 1}"],"metadata":{"created":"2024-01-#{i % 28 + 1}","updated":"2024-02-#{i % 28 + 1}","count":#{i * 100}}})
  end.join(",")

  %Q({"users":[#{users}],"summary":{"total":#{10 * size_multiplier},"active":#{5 * size_multiplier},"inactive":#{5 * size_multiplier}}})
end

puts "=" * 70
puts "PROFILING JSON PARSER WITH STACKPROF"
puts "=" * 70

# Create reports directory
FileUtils.mkdir_p('benchmark/reports')

# Generate test data
puts "\nGenerating test data..."
json_data = generate_json_data(100)
puts "Data size: #{json_data.bytesize} bytes (#{(json_data.bytesize / 1024.0 / 1024.0).round(4)} MB)"

# Create parser
parser = MyJson::Parser.new

# Warmup
puts "\nWarmup parse..."
parser.parse(json_data)
puts "✓ Warmup successful"

# Profile with stackprof
puts "\nProfiling (this may take a minute)..."

StackProf.run(mode: :wall, out: 'benchmark/reports/stackprof.dump', raw: true) do
  10.times do
    parser.parse(json_data)
  end
end

puts "\n" + "=" * 70
puts "GENERATING REPORTS"
puts "=" * 70

# Read the profile data
profile = StackProf::Report.new(Marshal.load(File.binread('benchmark/reports/stackprof.dump')))

# Generate text report
puts "\n1. Generating text report..."
File.open('benchmark/reports/stackprof_report.txt', 'w') do |f|
  profile.print_text(false, 50, f)
end
puts "   ✓ Saved to: benchmark/reports/stackprof_report.txt"

# Generate method-specific report
puts "\n2. Generating method report..."
File.open('benchmark/reports/stackprof_methods.txt', 'w') do |f|
  profile.print_method(nil, f)
end
puts "   ✓ Saved to: benchmark/reports/stackprof_methods.txt"

# Print summary to console
puts "\n" + "=" * 70
puts "TOP 30 METHODS BY TOTAL TIME"
puts "=" * 70

profile.print_text(false, 30)

puts "\n" + "=" * 70
puts "PARSLET-SPECIFIC METHODS"
puts "=" * 70
puts "\nFiltering for Parslet methods..."

# Extract frames and filter for Parslet
frames = profile.data[:frames]
parslet_frames = frames.select do |addr, frame|
  frame[:name] =~ /Parslet/
end

# Sort by total samples
sorted_parslet = parslet_frames.sort_by { |addr, frame| -(frame[:total_samples] || 0) }.take(30)

puts "\n%-70s %10s %10s" % ["Method", "Total", "Samples"]
puts "-" * 92

sorted_parslet.each do |addr, frame|
  method_name = frame[:name]
  total = frame[:total_samples] || 0
  samples = frame[:samples] || 0

  # Truncate long names
  method_name = method_name[0..68] + "…" if method_name.length > 69

  puts "%-70s %10d %10d" % [method_name, total, samples]
end

puts "\n" + "=" * 70
puts "PROFILING COMPLETE"
puts "=" * 70
puts "\nReports saved in benchmark/reports/"
puts "\nKey files:"
puts "  - stackprof.dump            (raw profile data)"
puts "  - stackprof_report.txt      (text report with top methods)"
puts "  - stackprof_methods.txt     (detailed method report)"
puts "\nTo generate a flamegraph:"
puts "  stackprof benchmark/reports/stackprof.dump --flamegraph > benchmark/reports/flamegraph.html"
puts "\nTo view specific method:"
puts "  stackprof benchmark/reports/stackprof.dump --method 'MethodName'"
