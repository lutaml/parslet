#!/usr/bin/env ruby
# Benchmark for Phase 21: Sequence Flattening
# Tests the performance impact of flattening nested sequences

require 'bundler/setup'
require 'parslet'
require 'benchmark'

class SequenceFlatteningBench
  include Parslet

  def initialize
    # Create a deeply nested sequence: a >> b >> c >> d >> e >> f >> g >> h
    @simple_seq = str('a') >> str('b') >> str('c') >> str('d') >>
                  str('e') >> str('f') >> str('g') >> str('h')

    # Create a sequence with repetitions: (a >> b)* >> (c >> d)* >> e
    @complex_seq = (str('a') >> str('b')).repeat >>
                   (str('c') >> str('d')).repeat >>
                   str('e')

    # Test inputs
    @simple_input = 'abcdefgh'
    @complex_input = 'ab' * 50 + 'cd' * 50 + 'e'
  end

  def warmup(n = 100)
    puts "Warming up (#{n} iterations)..."
    n.times do
      @simple_seq.parse(@simple_input)
      @complex_seq.parse(@complex_input)
    end
  end

  def run_benchmark(iterations = 10_000)
    puts "\n" + "=" * 60
    puts "Phase 21: Sequence Flattening Benchmark"
    puts "=" * 60

    # Count parslets in the simple sequence
    simple_count = count_parslets(@simple_seq)
    puts "\nSimple sequence depth: #{simple_count} parslets"

    results = {}

    # Benchmark simple sequence
    puts "\nBenchmark 1: Simple nested sequence (#{@simple_input})"
    puts "-" * 60

    GC.disable
    start_time = Time.now
    iterations.times { @simple_seq.parse(@simple_input) }
    end_time = Time.now
    GC.enable

    elapsed = end_time - start_time
    rate = iterations / elapsed
    results[:simple_rate] = rate

    puts "Iterations: #{iterations}"
    puts "Duration: #{elapsed.round(3)}s"
    puts "Rate: #{rate.round(2)} parses/sec"

    # Benchmark complex sequence
    puts "\nBenchmark 2: Complex sequence with repetitions"
    puts "Input: #{@complex_input.size} characters (ab*50 + cd*50 + e)"
    puts "-" * 60

    complex_iterations = [iterations / 10, 100].max  # Fewer iterations for complex case

    GC.disable
    start_time = Time.now
    complex_iterations.times { @complex_seq.parse(@complex_input) }
    end_time = Time.now
    GC.enable

    elapsed = end_time - start_time
    rate = complex_iterations / elapsed
    results[:complex_rate] = rate

    puts "Iterations: #{complex_iterations}"
    puts "Duration: #{elapsed.round(3)}s"
    puts "Rate: #{rate.round(2)} parses/sec"

    # Object allocation test
    puts "\nBenchmark 3: Object allocation (simple sequence)"
    puts "-" * 60

    before_count = ObjectSpace.count_objects[:T_OBJECT]
    1000.times { @simple_seq.parse(@simple_input) }
    after_count = ObjectSpace.count_objects[:T_OBJECT]

    allocated = after_count - before_count
    per_parse = allocated / 1000.0
    results[:objects_per_parse] = per_parse

    puts "Objects allocated: #{allocated}"
    puts "Per parse: #{per_parse.round(2)}"

    puts "\n" + "=" * 60
    puts "Summary"
    puts "=" * 60
    puts "Simple sequence: #{results[:simple_rate].round(2)} parses/sec"
    puts "Complex sequence: #{results[:complex_rate].round(2)} parses/sec"
    puts "Objects/parse: #{results[:objects_per_parse].round(2)}"
    puts "=" * 60

    results
  end

  private

  def count_parslets(parslet)
    case parslet
    when Parslet::Atoms::Sequence
      parslet.parslets.size
    else
      1
    end
  end
end

if __FILE__ == $0
  bench = SequenceFlatteningBench.new
  bench.warmup
  bench.run_benchmark
end
