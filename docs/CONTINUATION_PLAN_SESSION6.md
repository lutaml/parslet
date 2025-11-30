# Continuation Plan: Session 6 - Comprehensive Benchmark Implementation

**Session**: 6 of 6 (PRE-RELEASE)
**Priority**: HIGH (Release blocking - comprehensive benchmarks required)
**Duration**: 5-8 hours
**Status**: Ready to begin

---

## Context

Session 5 completed all release preparation tasks EXCEPT comprehensive benchmarks. The user has requested Option B: implement comprehensive benchmarks before release to provide professional, publication-quality comparison data between vanilla parslet 2.0 and plurimath parslet 3.1.0.

**Current State**:
- ✅ Version 3.1.0 ready
- ✅ HISTORY.txt updated
- ✅ Git commit and tag created
- ✅ Gem built and tested
- ✅ Basic benchmark report generated
- ⏳ **Comprehensive benchmark architecture planned but not implemented**

**Architecture Plan**: See [`docs/BENCHMARK_ARCHITECTURE_PLAN.md`](BENCHMARK_ARCHITECTURE_PLAN.md) for full details.

---

## Mission: Implement Comprehensive Benchmark System

Transform benchmark system from simple internal comparison to professional vanilla parslet 2.0 vs plurimath comparison across multiple parser types and input sizes.

---

## Implementation Phases

### Phase 1: Test Data Creation (1-2 hours)

Create test input files for 4 parser types × 4 size categories.

#### 1.1: Directory Structure

```bash
benchmark/test_data/
  sentence/
    tiny.txt
    small.txt
    medium.txt
    large.txt
  calc/
    tiny.txt
    small.txt
    medium.txt
    large.txt
  json/
    tiny.json
    small.json
    medium.json
    large.json
  erb/
    tiny.erb
    small.erb
    medium.erb
    large.erb
```

#### 1.2: Sentence Parser Test Data

Source parser: `example/sentence.rb`

Files to create:
- **tiny.txt** (50 bytes): Single sentence
- **small.txt** (500 bytes): Paragraph of 5-10 sentences
- **medium.txt** (5KB): Article with multiple paragraphs
- **large.txt** (50KB): Long document

#### 1.3: Calculator Parser Test Data

Source parser: `example/calc.rb`

Files to create:
- **tiny.txt** (20 bytes): `2 + 3 * 4 - 5 / 2`
- **small.txt** (200 bytes): 10-20 arithmetic operations
- **medium.txt** (2KB): 100-200 operations with parentheses
- **large.txt** (20KB): 1000+ operations, deeply nested

#### 1.4: JSON Parser Test Data

Source parser: `example/json.rb`

Files to create:
- **tiny.json** (50 bytes): Simple object `{"name":"John","age":30}`
- **small.json** (500 bytes): Array of 10-20 objects
- **medium.json** (5KB): Nested structure with 100+ objects
- **large.json** (50KB): Deep nesting, 1000+ objects

#### 1.5: ERB Parser Test Data

Source parser: `example/erb.rb`

Files to create:
- **tiny.erb** (50 bytes): `<p>Hello <%= @name %></p>`
- **small.erb** (500 bytes): Template with 5-10 ERB tags
- **medium.erb** (5KB): Complex template with loops and conditionals
- **large.erb** (50KB): Large application template

#### 1.6: Validation Script

Create `benchmark/validate_test_data.rb` to verify all files parse correctly with their respective parsers.

---

### Phase 2: Parser Wrappers (30 minutes)

Create standardized wrapper classes for benchmark consistency.

#### 2.1: Base Parser Wrapper

File: `benchmark/parsers/base_parser.rb`

```ruby
module Benchmark
  module Parsers
    class BaseParser
      attr_reader :name, :parser_class
      
      def initialize(name, parser_class)
        @name = name
        @parser_class = parser_class
      end
      
      def parse(input)
        parser_class.new.parse(input)
      end
      
      def test_data_dir
        File.join(__dir__, '..', 'test_data', name)
      end
      
      def test_files
        Dir[File.join(test_data_dir, '*.{txt,json,erb}')]
      end
    end
  end
end
```

#### 2.2: Individual Parser Wrappers

Create wrappers:
- `benchmark/parsers/sentence_parser.rb`
- `benchmark/parsers/calc_parser.rb`
- `benchmark/parsers/json_parser.rb`
- `benchmark/parsers/erb_parser.rb`

Each wrapper:
1. Requires the example parser
2. Inherits from BaseParser
3. Provides parser_class reference

---

### Phase 3: Dual-Version Benchmark Runner (2-3 hours)

Core implementation for running benchmarks against both parslet versions.

#### 3.1: Architecture Decision

**Challenge**: Need to test vanilla parslet 2.0 and plurimath parslet in same run.

**Solution**: Subprocess isolation with Bundler

```ruby
# Run vanilla in subprocess with specific gem version
system("bundle exec ruby benchmark/runners/vanilla_runner.rb")

# Run plurimath in current process
# (already using plurimath)
```

#### 3.2: Vanilla Runner Script

File: `benchmark/runners/vanilla_runner.rb`

Requirements:
- Create temporary Gemfile with `gem 'parslet', '2.0.0'`
- Run benchmarks in subprocess
- Save results to JSON
- Clean up temporary files

#### 3.3: Plurimath Runner Script

File: `benchmark/runners/plurimath_runner.rb`

Requirements:
- Use current plurimath version
- Run same benchmarks as vanilla
- Save results to JSON
- Match vanilla output format

#### 3.4: Comprehensive Suite Main Script

File: `benchmark/comprehensive_suite.rb`

Responsibilities:
1. Discover all parsers and test files
2. Run vanilla runner (subprocess)
3. Run plurimath runner (current process)
4. Merge results into single JSON
5. Save to `benchmark/results/comprehensive_v3.1.0.json`

#### 3.5: Metrics Collection

For each test case, collect:
```ruby
{
  parser: "json",
  input_file: "medium.json",
  input_size: 5432,
  parslet_version: "2.0.0" | "3.1.0",
  timing: {
    ips: 1234.56,
    stddev: 12.34,
    iterations: 10000,
    cycles: 100
  },
  memory: {
    allocations: 5432,
    retained: 123,
    gc_count: 0
  }
}
```

Use `benchmark-ips` gem for timing (if available, otherwise manual).

#### 3.6: Error Handling

- Handle parser errors gracefully (some inputs may not parse)
- Timeout protection (max 60s per test)
- Resource cleanup on failure
- Detailed error logging

---

### Phase 4: Report Generator Enhancement (1-2 hours)

Update `benchmark/generate_report.rb` to handle comprehensive results.

#### 4.1: New Report Structure

```asciidoc
= Comprehensive Benchmark: Plurimath vs Vanilla Parslet 2.0

== Executive Summary
- Overall speedup across all tests
- Best/worst case scenarios
- Key findings

== Parser-by-Parser Analysis
=== Sentence Parser (Simple)
==== Tiny Input
[Comparison table: vanilla vs plurimath]
==== Small Input
[Comparison table]
... (repeat for medium, large)

=== Calculator Parser (Medium)
... (same structure)

=== JSON Parser (Complex)
... (same structure)

=== ERB Parser (Very Complex)
... (same structure)

== Performance Scaling Analysis
- How speedup varies with input size
- Per-parser scaling characteristics

== Memory Efficiency
- Allocation comparison
- GC frequency analysis

== Conclusions
- Summary of findings
- Recommendations
```

#### 4.2: Comparison Table Format

For each test case:

```
[cols="1,1,1,1", options="header"]
|===
| Metric | Vanilla 2.0 | Plurimath 3.1.0 | Improvement

| **Iterations/sec**
| 1,234 ips
| 16,542 ips
| **13.4x faster** ⬆

| **Microseconds/iter**
| 810 µs
| 60 µs
| **13.5x faster** ⬇

| **Allocations**
| 5,432 objects
| 5,432 objects
| Same

| **GC Count**
| 0
| 0
| Same
|===
```

#### 4.3: Scaling Analysis

Generate graphs (ASCII art or data for external plotting):
- X-axis: Input Size (tiny/small/medium/large)
- Y-axis: Speedup Factor
- Line per parser type

#### 4.4: Report Generation Command

```bash
# Generate comprehensive report
ruby -Ilib benchmark/generate_report.rb \
  --comprehensive comprehensive_v3.1.0

# Output: docs/BENCHMARK_COMPREHENSIVE_v3.1.0.adoc
```

---

### Phase 5: Validation & Documentation (1 hour)

#### 5.1: Run Full Benchmark Suite

```bash
# Execute comprehensive benchmarks
ruby -Ilib benchmark/comprehensive_suite.rb

# Expected output:
# - benchmark/results/comprehensive_v3.1.0.json
# - Completion message with summary
```

#### 5.2: Generate Report

```bash
# Generate ADOC report
ruby -Ilib benchmark/generate_report.rb \
  --comprehensive comprehensive_v3.1.0

# Expected output:
# - docs/BENCHMARK_COMPREHENSIVE_v3.1.0.adoc
```

#### 5.3: Validation Checks

- [ ] All 16 test cases run (4 parsers × 4 sizes)
- [ ] Both vanilla and plurimath results present
- [ ] Speedup calculations correct
- [ ] Memory metrics captured
- [ ] Report renders correctly in AsciiDoc viewer
- [ ] Tables formatted properly
- [ ] Comparison data makes sense

#### 5.4: Update Documentation

Update `docs/BENCHMARK_ARCHITECTURE_PLAN.md`:
- Mark implementation complete
- Document actual vs estimated time
- Note any deviations from plan

Create `benchmark/README.md`:
- How to run comprehensive benchmarks
- How to add new parsers
- How to generate reports
- Interpreting results

#### 5.5: Update Release Documentation

Update `HISTORY.txt` if needed:
- Add note about comprehensive benchmarks
- Reference benchmark report

Update `README.adoc`:
- Add section on benchmark methodology
- Link to comprehensive benchmark report

---

## Success Criteria

- [ ] All 4 parsers have test data (4 sizes each = 16 files)
- [ ] Parser wrappers created and tested
- [ ] Vanilla runner successfully runs with parslet 2.0
- [ ] Plurimath runner completes all benchmarks
- [ ] Comprehensive suite generates JSON results
- [ ] Report generator creates professional ADOC report
- [ ] All speedup measurements show improvement over vanilla
- [ ] Memory comparisons show equivalence or improvement
- [ ] Documentation updated
- [ ] Validation passes

---

## Architectural Principles

### Object-Oriented Design

- Each parser wrapped in standardized class
- Base class for common functionality
- Single responsibility: runners run, generators generate
- Open/closed: easy to add new parsers without modifying existing code

### MECE (Mutually Exclusive, Collectively Exhaustive)

- Parser types cover spectrum: simple → very complex
- Size categories cover range: tiny → large
- Metrics comprehensive: timing + memory + GC
- No overlap between test cases

### Separation of Concerns

- **Test Data**: Just input files
- **Parsers**: Wrap example parsers
- **Runners**: Execute benchmarks per version
- **Suite**: Orchestrate overall run
- **Generator**: Create reports from data
- **Validators**: Verify correctness

### Extensibility

Adding new parser:
1. Create test data files
2. Create parser wrapper
3. Run benchmark suite (automatic discovery)
4. Generate report (automatic inclusion)

No modifications to core infrastructure needed.

---

## Time Breakdown

| Phase | Task | Estimated | Notes |
|-------|------|-----------|-------|
| 1 | Test data creation | 1-2h | 16 files, validation |
| 2 | Parser wrappers | 0.5h | Simple delegation |
| 3 | Dual-version runner | 2-3h | Subprocess complexity |
| 4 | Report generator | 1-2h | ADOC formatting |
| 5 | Validation | 1h | Run and verify |
| **Total** | **5.5-8.5h** | **Compress to 5-6h** |

**Compression Strategy**:
- Parallelize test data creation (use generators)
- Simplify runner (accept some manual steps)
- Focus on core comparisons in report
- Defer nice-to-have features

---

## Risk Mitigation

### Risk: Vanilla parslet 2.0 subprocess fails
**Mitigation**: Test subprocess isolation early, have fallback to manual runs

### Risk: Test data too large, benchmarks take forever
**Mitigation**: Start with tiny/small, adjust sizes based on runtime

### Risk: Some parsers don't work with vanilla 2.0
**Mitigation**: Accept incomplete dataset, document limitations

### Risk: Report generator too complex
**Mitigation**: Start with basic tables, enhance iteratively

---

## Deliverables

### Code
- `benchmark/test_data/**/*` (16 test files)
- `benchmark/parsers/**/*.rb` (5 files: base + 4 parsers)
- `benchmark/runners/**/*.rb` (2 files: vanilla + plurimath)
- `benchmark/comprehensive_suite.rb` (1 file: main runner)
- `benchmark/generate_report.rb` (updated)
- `benchmark/validate_test_data.rb` (1 file)

### Data
- `benchmark/results/comprehensive_v3.1.0.json` (complete results)

### Documentation
- `docs/BENCHMARK_COMPREHENSIVE_v3.1.0.adoc` (comprehensive report)
- `benchmark/README.md` (usage guide)
- Updated `README.adoc` (methodology section)
- Updated `HISTORY.txt` (if needed)

### Total Files
- **New**: ~25 files
- **Modified**: 3-4 files

---

## Post-Implementation

After successful implementation:
1. Review results for sanity
2. Update release notes with benchmark findings
3. Proceed with git push and gem publication
4. Archive planning documents to `docs/old-docs/`

---

## Next Session Prompt

See [`docs/CONTINUATION_PROMPT_SESSION6.md`](CONTINUATION_PROMPT_SESSION6.md) for the prompt to start Session 6.

---

*Document Status: ACTIVE PLAN*
*Created: 2025-11-30*
*Session: 6 (Pre-Release)*
*Priority: HIGH - Release Blocking*