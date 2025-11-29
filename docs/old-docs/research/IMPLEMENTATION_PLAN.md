# Parslet Benchmarking - Implementation Plan

**Created**: 2025-10-21
**Status**: Active
**Goal**: Unblock benchmarking by creating working parsers for profiling Parslet performance

---

## Executive Summary

The benchmarking project is currently blocked because the EXPRESS parser cannot parse real schemas. This implementation plan pivots to a **Pascal-first strategy** to unblock the benchmarking infrastructure and gather initial performance data.

### Strategy Rationale

1. **Pascal parser is simpler** - Case-insensitive keywords, straightforward syntax
2. **Fixtures already exist** - 4 Pascal test files (7KB to 301KB) ready to use
3. **Unblocks benchmarking** - Can measure baseline performance immediately
4. **Provides reference** - Working parser serves as template for fixing EXPRESS

---

## Phase 1: Cleanup and Preparation (5 minutes)

### 1.1 Remove Irrelevant Documentation
- [x] Remove `rubocop_cleanup_progress.md` (RuboCop cleanup is complete)
- [x] Keep `BENCHMARKING_PLAN.md` and `STATUS.md` (core documentation)
- [x] Create this `IMPLEMENTATION_PLAN.md`

---

## Phase 2: Pascal Parser Implementation (2-3 hours)

### 2.1 Pascal Syntax Analysis

Pascal syntax characteristics to handle:
- **Case-insensitive keywords**: PROGRAM, BEGIN, END, VAR, PROCEDURE, FUNCTION
- **Block structure**: BEGIN...END with semicolon delimiters
- **Declarations**:
  - Variable declarations: `VAR name : type;`
  - Type definitions: `TYPE name = type;`
  - Procedure/Function declarations with parameters
- **Statements**:
  - Assignment: `variable := expression;`
  - Control flow: IF-THEN-ELSE, WHILE-DO, FOR-TO-DO, CASE-OF
  - Procedure/Function calls
- **Comments**: `{ comment }` or `(* comment *)`
- **Literals**: integers, reals, strings (single quotes), booleans

### 2.2 Parser Architecture

```ruby
class PascalParser < Parslet::Parser
  # Whitespace and comments
  rule(:space) { match('\s').repeat(1) }
  rule(:comment_brace) { str('{') >> ... >> str('}') }
  rule(:comment_paren) { str('(*') >> ... >> str('*)') }
  rule(:ws) { (space | comment_brace | comment_paren).repeat }

  # Case-insensitive keywords
  def keyword(kw)
    match["#{kw.downcase}#{kw.upcase}"].repeat(1)
  end

  # Identifiers and literals
  rule(:identifier) { ... }
  rule(:integer) { ... }
  rule(:real) { ... }
  rule(:string_literal) { ... }

  # Program structure
  rule(:program_header) { keyword('program') >> ... }
  rule(:declarations) { ... }
  rule(:statement_block) { keyword('begin') >> ... >> keyword('end') }

  root :program
end
```

### 2.3 Implementation Steps

1. **Create `benchmark/parsers/pascal_parser.rb`**
   - Start with basic program structure (PROGRAM...END.)
   - Add variable declarations (VAR section)
   - Add statement parsing (assignments, control flow)
   - Add procedure/function declarations
   - Handle comments and whitespace

2. **Test incrementally**
   - Start with `small_program.pas` (7KB, 500 lines)
   - Verify correct parsing
   - Measure initial performance

3. **Expand to larger files**
   - Test on `medium_program.pas` (21KB)
   - Test on `large_program.pas` (42KB)
   - Test on `huge_program.pas` (301KB)

### 2.4 Success Criteria
- [ ] Parser successfully parses all 4 Pascal fixtures
- [ ] No parse failures
- [ ] Reasonable performance (establish baseline)
- [ ] Clean parse tree structure

---

## Phase 3: Benchmark Integration (1 hour)

### 3.1 Update Benchmark Suite

Modify `benchmark/benchmark_suite.rb`:
```ruby
require_relative 'parsers/pascal_parser'

class BenchmarkSuite
  def self.run_pascal_benchmarks
    parser = PascalParser.new

    fixtures = [
      'small_program.pas',
      'medium_program.pas',
      'large_program.pas',
      'huge_program.pas'
    ]

    fixtures.each do |fixture|
      content = File.read("benchmark/fixtures/pascal/#{fixture}")
      benchmark_parser(parser, content, fixture)
    end
  end

  def self.benchmark_parser(parser, content, name)
    # Use benchmark-ips
    # Measure throughput in MB/sec
    # Report results
  end
end
```

### 3.2 Create Benchmark Runner

Update `benchmark/benchmark_runner.rb`:
```ruby
#!/usr/bin/env ruby
require 'benchmark/ips'
require_relative 'benchmark_suite'

# Run Pascal benchmarks
puts "=" * 80
puts "PARSLET PERFORMANCE BENCHMARKING - Pascal Parser"
puts "=" * 80
puts

BenchmarkSuite.run_pascal_benchmarks
```

### 3.3 Add Rake Tasks

Ensure `Rakefile` has:
```ruby
namespace :benchmark do
  desc 'Run Pascal parser benchmarks'
  task :pascal do
    ruby 'benchmark/benchmark_runner.rb pascal'
  end

  desc 'Run all benchmarks'
  task :all do
    ruby 'benchmark/benchmark_runner.rb all'
  end
end
```

---

## Phase 4: Initial Performance Measurement (30 minutes)

### 4.1 Baseline Metrics to Capture

For each Pascal fixture, measure:
- **Parse time** (milliseconds)
- **Throughput** (MB/sec)
- **Memory allocations** (using memory_profiler)
- **Success/failure** status

### 4.2 Expected Results

Initial estimates (before optimization):
- Small (7KB): ~0.1-0.5 MB/sec
- Medium (21KB): ~0.1-0.5 MB/sec
- Large (42KB): ~0.1-0.5 MB/sec
- Huge (301KB): ~0.1-0.5 MB/sec

**Target after optimization: 5 MB/sec**

### 4.3 Report Generation

Create `benchmark/reports/pascal_baseline.txt`:
```
PARSLET PERFORMANCE BASELINE - Pascal Parser
Generated: 2025-10-21
Parser: PascalParser
Parslet Version: (current version)

Results:
┌──────────────────────┬─────────┬───────────┬─────────────┬─────────┐
│ File                 │ Size    │ Time (ms) │ Throughput  │ Status  │
├──────────────────────┼─────────┼───────────┼─────────────┼─────────┤
│ small_program.pas    │ 7 KB    │ xx.xx     │ x.xx MB/s   │ ✓       │
│ medium_program.pas   │ 21 KB   │ xx.xx     │ x.xx MB/s   │ ✓       │
│ large_program.pas    │ 42 KB   │ xx.xx     │ x.xx MB/s   │ ✓       │
│ huge_program.pas     │ 301 KB  │ xx.xx     │ x.xx MB/s   │ ✓       │
└──────────────────────┴─────────┴───────────┴─────────────┴─────────┘

Average Throughput: x.xx MB/s
Target Throughput: 5.00 MB/s
Gap to Target: x.xx MB/s (xx%)
```

---

## Phase 5: Profiling (1-2 hours)

### 5.1 Setup Profiling Tools

Use tools already installed:
- `ruby-prof` - Call graph and flat profiles
- `memory_profiler` - Memory allocation tracking
- `stackprof` - CPU sampling

### 5.2 Profile Pascal Parser

```ruby
# Profile with ruby-prof
require 'ruby-prof'

parser = PascalParser.new
content = File.read('benchmark/fixtures/pascal/huge_program.pas')

result = RubyProf.profile do
  parser.parse(content)
end

printer = RubyProf::FlatPrinter.new(result)
printer.print(File.open('benchmark/reports/profiles/pascal_flat.txt', 'w'))
```

### 5.3 Identify Bottlenecks

Look for:
- **String operations** - likely biggest overhead
- **Position tracking** - known expensive operation
- **Parse tree construction** - memory intensive
- **Backtracking** - PEG parser characteristic
- **Repetition handling** - could be optimized

---

## Phase 6: Return to EXPRESS Parser (2-4 hours)

Once Pascal benchmarking is working, return to fix EXPRESS parser.

### 6.1 EXPRESS Parser Issues

**Current blocker**: Declaration bodies not parsing correctly

**Root cause**: TYPE and ENTITY blocks don't consume all content

**Fix strategy**:
1. Analyze line 52 of `real_action_schema.exp`
2. Identify what content is not being matched
3. Expand TYPE/ENTITY body rules to handle:
   - SELECT types
   - Nested structures
   - WHERE clauses
   - DERIVE clauses
   - UNIQUE clauses

### 6.2 Simplified Approach

Instead of full EXPRESS grammar, create **minimal working subset**:
- Schema declaration
- Simple TYPE declarations (no complex nested types)
- Simple ENTITY declarations (basic attributes only)
- Skip complex features initially

This is sufficient for benchmarking purposes.

---

## Phase 7: C Parser (Optional, 2-3 hours)

### 7.1 C Parser Scope

Focus on subset of C:
- Function declarations
- Variable declarations
- Basic control flow (if, for, while)
- Skip: preprocessor directives, complex pointer syntax, macros

### 7.2 Implementation

Similar approach to Pascal:
- Start small and test incrementally
- Focus on structural parsing, not semantic correctness
- Goal is benchmarking, not production C compiler

---

## Success Metrics

### Immediate Success (End of Phase 4)
- [ ] Pascal parser working on all 4 fixtures
- [ ] Baseline performance measurements recorded
- [ ] Benchmark infrastructure validated

### Phase 5 Success
- [ ] Profiling data collected
- [ ] Top 10 bottlenecks identified
- [ ] Optimization priorities established

### Long-term Success
- [ ] All three parsers working (EXPRESS, Pascal, C)
- [ ] Comprehensive benchmark suite
- [ ] 2x performance improvement minimum
- [ ] 5x performance improvement target

---

## Risk Mitigation

### Risk: Pascal parser too complex
**Mitigation**: Start with subset, expand incrementally

### Risk: Performance too slow to measure accurately
**Mitigation**: Use larger fixtures, multiple iterations

### Risk: Profiling doesn't reveal clear bottlenecks
**Mitigation**: Try multiple profiling approaches, analyze different aspects

---

## Timeline Estimate

| Phase | Duration | Completion Date |
|-------|----------|-----------------|
| Phase 1: Cleanup | 5 min | 2025-10-21 |
| Phase 2: Pascal Parser | 2-3 hours | 2025-10-21 |
| Phase 3: Benchmark Integration | 1 hour | 2025-10-21 |
| Phase 4: Initial Measurements | 30 min | 2025-10-21 |
| Phase 5: Profiling | 1-2 hours | 2025-10-21 |
| Phase 6: EXPRESS Fix | 2-4 hours | 2025-10-22 |
| Phase 7: C Parser | 2-3 hours | 2025-10-22 |

**Total estimated time**: 9-14 hours

---

## Next Actions

1. ✅ Create this IMPLEMENTATION_PLAN.md
2. ✅ Update STATUS.md with new strategy
3. ✅ Remove rubocop_cleanup_progress.md
4. → Create Pascal parser
5. → Test on fixtures
6. → Run benchmarks
7. → Profile and analyze

---

## Questions & Decisions

- [ ] Should we implement full Pascal grammar or subset?
  - **Decision**: Start with subset, expand as needed

- [ ] What level of parse tree detail is needed?
  - **Decision**: Enough to be realistic, but focus on structure over semantics

- [ ] Should we fix EXPRESS or skip to C?
  - **Decision**: Return to EXPRESS after Pascal is working

---

## Appendix: Pascal Language Reference

### Keywords (Case-Insensitive)
```
PROGRAM, BEGIN, END, VAR, CONST, TYPE
PROCEDURE, FUNCTION, FORWARD
IF, THEN, ELSE, CASE, OF
WHILE, DO, REPEAT, UNTIL, FOR, TO, DOWNTO
INTEGER, REAL, BOOLEAN, CHAR, STRING
TRUE, FALSE
DIV, MOD, AND, OR, NOT
```

### Basic Syntax Patterns
```pascal
PROGRAM name;
VAR
  variable : type;
BEGIN
  statement;
  statement;
END.
```

### Control Flow
```pascal
IF condition THEN
  statement
ELSE
  statement;

WHILE condition DO
  statement;

FOR variable := start TO end DO
  statement;
```

This reference ensures consistent parser implementation.
