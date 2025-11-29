# Parslet Benchmark Results

## Overview

This document contains the results of benchmarking Parslet example parsers to establish baseline performance metrics and identify optimization opportunities.

**Date**: 2025-10-21
**Ruby Version**: 3.3.2
**Parslet Version**: Current development version
**Target Throughput**: 5.0 MB/sec

## Benchmark Suite

The benchmark suite tests parsing throughput (MB/sec) using real-world parsers from the Parslet examples directory. Each parser is tested with appropriately-sized input data over multiple iterations to calculate average and best-case performance.

### Test Configuration

- **Iterations per parser**: 10
- **Measurement method**: Process.clock_gettime(Process::CLOCK_MONOTONIC)
- **Metrics**: Average time, best time, worst time, throughput (MB/sec)

## Results

### JSON Parser

**Parser**: `example/json.rb` (MyJson::Parser)
**Test Data Size**: 186,541 bytes (0.1779 MB)
**Test Data**: Complex JSON with nested objects, arrays, numbers, strings, booleans

| Metric | Value |
|--------|-------|
| Average Parse Time | 7,537.51 ms |
| Best Parse Time | 6,377.76 ms |
| Worst Parse Time | 9,307.45 ms |
| **Average Throughput** | **0.0236 MB/sec** |
| **Best Throughput** | **0.0279 MB/sec** |
| Success Rate | 10/10 (100%) |

### Calc Parser

**Parser**: `example/calc.rb` (CalcParser)
**Test Data Size**: 71,687 bytes (0.0684 MB)
**Test Data**: Long arithmetic expression with addition, multiplication, division

| Metric | Value |
|--------|-------|
| Average Parse Time | 1,037.13 ms |
| Best Parse Time | 776.59 ms |
| Worst Parse Time | 1,603.58 ms |
| **Average Throughput** | **0.0659 MB/sec** |
| **Best Throughput** | **0.088 MB/sec** |
| Success Rate | 10/10 (100%) |

## Summary

### Performance Ranking

1. **Calc Parser**: 0.0659 MB/sec (fastest)
2. **JSON Parser**: 0.0236 MB/sec (slowest)

### Key Findings

1. **Current vs Target Performance**
   - Fastest parser (Calc): 0.0659 MB/sec
   - Target: 5.0 MB/sec
   - **Gap**: 4.9341 MB/sec (98.7% below target)
   - **Speedup needed**: ~76x improvement required

2. **Parser Complexity vs Performance**
   - Calc parser (simpler grammar) performs ~2.8x better than JSON parser
   - JSON parser handles more complex nested structures (objects, arrays, multiple data types)
   - Both parsers are far below the target throughput

3. **Performance Characteristics**
   - Significant variance in parse times (worst case 15-50% slower than average)
   - Both parsers show consistent behavior across iterations
   - No parsing failures observed in either parser

## Analysis

### Performance Bottlenecks (Hypothesized)

Based on the benchmark results, likely bottlenecks include:

1. **Backtracking overhead**: PEG parsers naturally do more backtracking
2. **Object allocation**: Excessive intermediate object creation during parsing
3. **String operations**: Repeated string slicing and manipulation
4. **Recursion depth**: Deep call stacks for nested structures
5. **Lack of memoization**: Repeated parsing of same patterns

### Next Steps for Profiling

1. **Profile JSON Parser** (slowest, most representative)
   - Use ruby-prof to identify hot spots
   - Analyze memory allocation patterns with memory_profiler
   - Examine call stack depth and frequency

2. **Profile Calc Parser** (for comparison)
   - Identify why it's faster despite larger input
   - Compare patterns with JSON parser

3. **Optimization Targets**
   - String slicing and Position/Slice object creation
   - Backtracking reduction through better grammar design
   - Caching/memoization opportunities
   - Parser combinator overhead

## Recommendations

### Immediate Actions

1. **Run detailed profiling** on JSON parser to identify specific bottlenecks
2. **Create flamegraphs** to visualize where time is spent
3. **Analyze memory allocation** to find excessive object creation

### Long-term Optimizations

1. **Implement memoization** for frequently-parsed patterns
2. **Optimize string operations** (reduce slicing, use string views if possible)
3. **Reduce object allocation** in hot paths
4. **Add fast paths** for common patterns
5. **Consider compilation** of parser rules to more efficient representations

### Benchmark Improvements

1. Add more parsers (ERB, XML, etc.) when data generation issues are resolved
2. Test with varying input sizes to understand scaling behavior
3. Add memory usage metrics
4. Create automated regression testing

## Conclusion

Current Parslet performance is significantly below the 5.0 MB/sec target, achieving only ~1.3% of the target throughput. The 76x improvement needed suggests fundamental optimization work is required in the core parsing engine, not just incremental improvements.

The consistent performance across iterations and lack of failures indicates stability, but the large gap to target performance requires deep profiling and potentially architectural changes to achieve the performance goals.
