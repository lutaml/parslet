# Parslet Benchmarking and Performance Optimization Plan

## Objective

Improve parslet's parser performance to achieve **5MB/second parsing throughput** on real-world files, with comprehensive benchmarking and profiling infrastructure.

## Background

The parslet library currently lacks comprehensive performance benchmarking, and users have reported slow parsing performance on large files. This plan outlines the steps to:

1. Create a robust benchmarking infrastructure
2. Implement test parsers for real-world scenarios (EXPRESS, Pascal, C)
3. Profile and identify performance bottlenecks
4. Optimize critical paths
5. Validate performance improvements

## Target Languages

### EXPRESS (ISO 10303-11)
- **Primary focus**: Real schemas from ISO 10303 standards
- **Test files**: From `~/src/mn/iso-10303/schemas/resources/`
- **File sizes**: 46KB to 622KB (1,098 to 15,398 lines)
- **Use case**: CAD/engineering data modeling language used in STEP files

### Pascal
- **Test files**: Real Pascal source code
- **File sizes**: 500 to 20,000 lines
- **Use case**: Legacy code parsing, educational projects

### C
- **Test files**: Real C source code
- **File sizes**: 500 to 20,000 lines
- **Use case**: Common systems programming language

## Performance Target

**Parse 5MB in under 1 second** (5MB/sec throughput)

## Implementation Phases

### Phase 1: Fix EXPRESS Parser ⚠️ CURRENT
**Status**: In Progress
**Blocker**: Parser fails on real ISO 10303 schemas

**Tasks**:
1. Debug declaration body parsing in `express_parser_simple.rb`
2. Handle TYPE...END_TYPE and ENTITY...END_ENTITY blocks correctly
3. Support nested structures, expressions, and constraints
4. Test on smallest schema first (real_action_schema.exp - 46KB)
5. Progressively test on larger schemas

**Success Criteria**: Parser successfully handles all 4 real schema files

---

### Phase 2: Create Pascal and C Parsers
**Status**: Not Started
**Dependencies**: Phase 1 completion not required, can work in parallel

**Tasks**:
1. Study Pascal syntax (case-insensitive keywords, begin/end blocks, procedures)
2. Create `benchmark/parsers/pascal_parser.rb`
3. Test on generated Pascal fixtures
4. Study C syntax (preprocessor, statements, declarations)
5. Create `benchmark/parsers/c_parser.rb`
6. Test on generated C fixtures

**Success Criteria**: Both parsers handle their respective fixture files

---

### Phase 3: Implement Benchmark Suite
**Status**: Partially Complete (structure exists, needs integration)

**Tasks**:
1. Update `benchmark/benchmark_suite.rb` to:
   - Load all three parsers
   - Benchmark each parser on all fixture sizes
   - Report throughput (MB/sec) and time
2. Integrate with `benchmark-ips` for iterations per second
3. Add warmup runs to stabilize measurements
4. Create comparison reports (text, JSON, YAML)

**Success Criteria**: Can run `bundle exec rake benchmark:all` and get comprehensive results

---

### Phase 4: Profiling and Analysis
**Status**: Not Started
**Dependencies**: Phase 3

**Tasks**:
1. **Ruby-Prof profiling**:
   - Profile each parser on largest files
   - Generate call graph reports
   - Identify hot spots (methods consuming most time)

2. **Memory Profiler**:
   - Track memory allocations
   - Identify memory-intensive operations
   - Find unnecessary object creation

3. **StackProf**:
   - CPU profiling with flamegraph generation
   - Visualize call stacks
   - Identify deep recursion issues

4. **Analysis**:
   - Document top 10 performance bottlenecks
   - Categorize issues (algorithmic, allocation, string ops, etc.)
   - Prioritize optimization opportunities

**Deliverables**:
- Profile reports in `benchmark/reports/profiles/`
- Analysis document with findings and recommendations

---

### Phase 5: Optimization Implementation
**Status**: Not Started
**Dependencies**: Phase 4

**Focus Areas** (to be refined based on profiling):

1. **String Operations**:
   - Reduce string allocations
   - Use string slicing instead of copying
   - Optimize slice creation

2. **Backtracking Reduction**:
   - Improve parser rule ordering
   - Add memoization where beneficial
   - Use lookahead to avoid unnecessary attempts

3. **Source Position Tracking**:
   - Optimize Position object creation
   - Cache position calculations
   - Lazy position updates

4. **Parse Tree Construction**:
   - Reduce intermediate node creation
   - Flatten where appropriate
   - Optimize capture operations

5. **Pattern Matching**:
   - Optimize repetition handling
   - Improve alternative selection
   - Cache compiled patterns

**Success Criteria**: Achieve 2-5x performance improvement on benchmarks

---

### Phase 6: Validation and Documentation
**Status**: Not Started
**Dependencies**: Phase 5

**Tasks**:
1. Re-run all benchmarks post-optimization
2. Compare before/after performance metrics
3. Verify all tests still pass (regression prevention)
4. Update README with:
   - Benchmark results
   - Performance characteristics
   - Best practices for parser writing
5. Document optimization techniques used
6. Create performance guide for parslet users

**Deliverables**:
- Performance comparison report
- Updated README.adoc
- `benchmark/PERFORMANCE_GUIDE.md`

---

## Tools and Gems

### Already Added
- `benchmark-ips` - Iterations per second benchmarking
- `ruby-prof` - Call graph and method profiling
- `memory_profiler` - Memory allocation tracking
- `stackprof` - CPU sampling profiler

### Rake Tasks
- `rake benchmark:all` - Run comprehensive benchmark suite
- `rake benchmark:examples` - Quick benchmark on examples
- `rake benchmark:export` - Export results to JSON/YAML

## Current Status

### Completed ✅
- Benchmark directory structure
- Fixture generator for all three languages
- Real EXPRESS schemas collected (46KB to 622KB)
- Synthetic fixtures generated for Pascal and C
- Initial EXPRESS parser created
- Profiling gems installed
- Test suites passing (438 Ruby specs, 437 Opal specs)

### In Progress 🔄
- EXPRESS parser debugging (Phase 1)
- Declaration body parsing fix needed

### Pending ⏳
- Pascal parser creation (Phase 2)
- C parser creation (Phase 2)
- Benchmark suite integration (Phase 3)
- Profiling and analysis (Phase 4)
- Optimization implementation (Phase 5)
- Documentation and validation (Phase 6)

## Next Immediate Steps

1. **Debug EXPRESS parser** (Priority: HIGH)
   - Focus on TYPE/ENTITY declaration body parsing
   - Test incremental fixes on real_action_schema.exp
   - Move to larger schemas once basic parsing works

2. **Start Pascal parser** (Priority: MEDIUM, can parallelize)
   - Independent of EXPRESS parser status
   - Use simpler syntax as proof of concept

3. **Prepare benchmark infrastructure** (Priority: MEDIUM)
   - Can mock parser results initially
   - Set up reporting structure

## Success Metrics

- [ ] All three parsers successfully parse their largest fixtures
- [ ] Benchmark suite runs without errors
- [ ] Profile reports generated for all parsers
- [ ] Performance improvements documented
- [ ] **Target**: Achieve 5MB/sec on at least one parser
- [ ] All existing tests continue to pass
- [ ] New benchmarks added to CI pipeline

## Timeline Estimate

- Phase 1: 2-4 hours (debugging, testing)
- Phase 2: 4-6 hours (two parsers)
- Phase 3: 2-3 hours (integration)
- Phase 4: 3-5 hours (profiling, analysis)
- Phase 5: 8-12 hours (optimization, varies by findings)
- Phase 6: 2-3 hours (documentation)

**Total**: 21-33 hours of focused development work

## Notes

- Real EXPRESS schemas provide authentic complexity
- Parser performance varies by language grammar complexity
- Some optimizations may be parser-specific
- Others may benefit all parslet users
- Focus on generalizable improvements where possible
