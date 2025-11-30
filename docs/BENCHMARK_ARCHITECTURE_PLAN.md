# Benchmark Architecture Revamp Plan

## Overview

Revamp the benchmark system to provide comprehensive comparison between vanilla parslet 2.0 and plurimath parslet across multiple parser types and input sizes.

## Goals

1. **Fair Comparison**: Test same parsers with same inputs on both vanilla and plurimath
2. **Comprehensive Coverage**: Multiple parser types (simple to complex)
3. **Scalability Testing**: Multiple input sizes (tiny to huge)
4. **Reproducible**: Automated, versioned, rerunnable
5. **Clear Reporting**: Easy-to-understand comparison metrics

---

## 1. Parser Selection

Select 4 parsers from `example/` directory with increasing complexity:

### Tier 1: Simple Parser
**Parser**: `example/sentence.rb` or `example/seasons.rb`
- **Complexity**: Basic string matching
- **Rules**: 2-5 rules
- **Use case**: Simple token parsing

### Tier 2: Medium Parser  
**Parser**: `example/calc.rb`
- **Complexity**: Arithmetic with precedence
- **Rules**: 10-15 rules
- **Use case**: Expression parsing with operators

### Tier 3: Complex Parser
**Parser**: `example/json.rb`
- **Complexity**: Nested structures
- **Rules**: 15-20 rules
- **Use case**: Real-world data format

### Tier 4: Very Complex Parser
**Parser**: `example/erb.rb` or `example/minilisp.rb`
- **Complexity**: Multiple context switches
- **Rules**: 20+ rules
- **Use case**: Programming language parsing

---

## 2. Test Data Files

For each parser, create test files of varying sizes:

### File Size Categories

| Category | Size | Purpose |
|----------|------|---------|
| **Tiny** | < 100 bytes | Overhead measurement |
| **Small** | 100-1K | Micro-benchmark |
| **Medium** | 1K-10K | Typical use case |
| **Large** | 10K-100K | Performance scaling |
| **XLarge** | 100K-1M | Stress test (optional) |

### Test Data Location

```
benchmark/
  test_data/
    sentence/
      tiny.txt      (50 bytes)
      small.txt     (500 bytes)
      medium.txt    (5K)
      large.txt     (50K)
    calc/
      tiny.txt      (arithmetic: "2+3*4")
      small.txt     (50 operations)
      medium.txt    (500 operations)
      large.txt     (5000 operations)
    json/
      tiny.json     (simple object)
      small.json    (100 objects)
      medium.json   (1000 objects)
      large.json    (10000 objects)
    erb/
      tiny.erb      (basic template)
      small.erb     (10 tags)
      medium.erb    (100 tags)
      large.erb     (1000 tags)
```

---

## 3. Benchmark Runner Architecture

### 3.1 Dual-Version Testing

**Challenge**: Need to test both vanilla parslet 2.0 and plurimath parslet

**Solution**: Two approaches:

#### Option A: Subprocess Isolation
```ruby
# Run vanilla parslet in subprocess with gem 'parslet', '2.0.0'
# Run plurimath in current process
```

#### Option B: Gemfile.lock Switching
```ruby
# Use bundler to switch between gem versions
# More reliable but slower
```

### 3.2 Benchmark Suite Structure

```
benchmark/
  comprehensive_suite.rb        # Main runner
  parsers/
    sentence_parser.rb          # Wrapped sentence parser
    calc_parser.rb              # Wrapped calc parser
    json_parser.rb              # Wrapped JSON parser
    erb_parser.rb               # Wrapped ERB parser
  test_data/                    # Test input files
  runners/
    vanilla_runner.rb           # Runs with parslet 2.0
    plurimath_runner.rb         # Runs with plurimath
  results/
    comprehensive_v3.1.0.json   # All results in one file
```

### 3.3 Metrics Collected

For each parser + input file + version combination:

```json
{
  "parser": "json",
  "input_file": "medium.json",
  "input_size": 5432,
  "parslet_version": "2.0.0",
  "timing": {
    "ips": 1234.56,
    "stddev": 12.34,
    "iterations": 10000,
    "warmup_seconds": 2,
    "measurement_seconds": 5
  },
  "memory": {
    "allocations": 5432,
    "retained": 123,
    "gc_count": 0
  }
}
```

---

## 4. Report Generator Updates

### 4.1 New Report Structure

```asciidoc
= Comprehensive Parser Benchmarks: Plurimath vs Vanilla Parslet 2.0

== Executive Summary
- Overall speedup: X.Xx across all tests
- Best case: Y.Yx (parser: Z, size: W)
- Worst case: A.Bx (parser: C, size: D)

== Parser-by-Parser Analysis

=== Sentence Parser (Simple)
==== Tiny Input (50 bytes)
[Comparison table]
==== Small Input (500 bytes)
[Comparison table]
...

=== Calculator Parser (Medium)
...

=== JSON Parser (Complex)
...

=== ERB Parser (Very Complex)
...

== Performance Scaling Analysis
- How speedup changes with input size
- Graph: Input Size vs Speedup Ratio

== Memory Efficiency Comparison
- Memory allocations vs input size
- GC frequency comparison

== Conclusions
```

### 4.2 Comparison Tables

For each parser + input size:

```
| Metric              | Vanilla 2.0  | Plurimath | Improvement |
|---------------------|--------------|-----------|-------------|
| Iterations/sec      | 1,234 ips    | 16,542 ips| 13.4x ⬆     |
| Allocations         | 5,432 obj    | 5,432 obj | same        |
| GC Count           | 0            | 0         | same        |
| Microseconds/iter   | 810 µs       | 60 µs     | 13.5x ⬇     |
```

---

## 5. Implementation Steps

### Phase 1: Test Data Creation (1-2 hours)
1. Create `benchmark/test_data/` structure
2. Generate test files for each parser
3. Validate files parse correctly

### Phase 2: Benchmark Runner (2-3 hours)
1. Create `benchmark/comprehensive_suite.rb`
2. Implement dual-version testing (subprocess approach)
3. Add metrics collection
4. Test run and debug

### Phase 3: Report Generator (1-2 hours)
1. Update `benchmark/generate_report.rb`
2. Add comparison tables
3. Add scaling analysis
4. Generate sample report

### Phase 4: Validation (1 hour)
1. Run full benchmark suite
2. Verify results make sense
3. Check report formatting
4. Document usage

**Total Time**: 5-8 hours

---

## 6. Usage

### Running Benchmarks

```bash
# Run comprehensive benchmark suite
ruby -Ilib benchmark/comprehensive_suite.rb

# Results saved to:
# benchmark/results/comprehensive_v3.1.0.json

# Generate report
ruby -Ilib benchmark/generate_report.rb --comprehensive v3.1.0

# Output:
# docs/BENCHMARK_COMPREHENSIVE_v3.1.0.adoc
```

### Comparing Versions

```bash
# Generate comparison report
ruby -Ilib benchmark/generate_report.rb \
  --compare comprehensive_v3.1.0 comprehensive_v3.0.0
```

---

## 7. Benefits of New Architecture

1. **Apples-to-Apples**: Same parser, same input, both versions
2. **Comprehensive**: 4 parsers × 4 sizes × 2 versions = 32 data points
3. **Reproducible**: Versioned test data, automated runs
4. **Scalable**: Easy to add more parsers or sizes
5. **Professional**: Publication-quality reports

---

## 8. Future Enhancements

### 8.1 CI Integration
- Run benchmarks on every release
- Track performance over time
- Alert on regressions

### 8.2 Visualization
- Generate graphs of speedup vs size
- Parser complexity vs improvement
- Memory usage heatmaps

### 8.3 YJIT Comparison
- Add third dimension: with/without YJIT
- Show compound improvements

### 8.4 Platform Testing
- Run on multiple Ruby versions
- Test on different architectures (x86, ARM)
- Cloud vs local performance

---

## 9. File Structure

```
benchmark/
  comprehensive_suite.rb          # Main benchmark runner
  generate_report.rb              # Report generator (updated)
  parsers/                        # Parser wrappers
    sentence_parser.rb
    calc_parser.rb
    json_parser.rb
    erb_parser.rb
  test_data/                      # Test input files
    sentence/
    calc/
    json/
    erb/
  runners/                        # Version-specific runners
    vanilla_runner.rb
    plurimath_runner.rb
  results/                        # JSON results
    comprehensive_v3.1.0.json
  CI_INTEGRATION.md               # CI setup guide
```

---

## 10. Next Steps

1. **Review this plan** with stakeholders
2. **Create test data files** (can start immediately)
3. **Implement subprocess runner** (critical path)
4. **Update report generator** (parallel with #3)
5. **Run and validate** benchmarks
6. **Document findings** in release notes

---

## Appendix: Example Test Files

### sentence/tiny.txt (50 bytes)
```
The quick brown fox jumps over the lazy dog.
```

### calc/tiny.txt (20 bytes)
```
2 + 3 * 4 - 5 / 2
```

### json/tiny.json (50 bytes)
```json
{"name":"John","age":30,"city":"NYC"}
```

### erb/tiny.erb (50 bytes)
```erb
<p>Hello <%= @name %>, welcome!</p>
```

---

*Document Status: DRAFT for review*
*Created: 2025-11-30*
*Author: Performance Optimization Team*