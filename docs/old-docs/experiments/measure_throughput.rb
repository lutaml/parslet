require 'benchmark'
require_relative '../example/json'

# Measure JSON throughput
json_input = '[1, 2, 3, null, "asdfasdf asdfds", {"a": -1.2}, {"b": true, "c": false}, 0.1e24, true, false, [1]]'
json_size_kb = json_input.bytesize / 1024.0

json_parser = MyJson::Parser.new
iterations = 1000
json_time = Benchmark.realtime do
  iterations.times { json_parser.parse(json_input) }
end
json_mb_sec = (json_size_kb * iterations / 1024.0) / json_time

puts "JSON Parser: #{json_mb_sec.round(4)} MB/sec (CanFlatten optimized)"
puts "Iterations: #{iterations}"
puts "Time: #{json_time.round(3)}s"
