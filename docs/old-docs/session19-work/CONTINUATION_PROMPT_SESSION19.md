# Continuation Prompt: Session 19 - Post-Integer Position Profiling

**Session**: 19  
**Priority**: MEDIUM  
**Goal**: Profile v3.3.0, identify next optimization target, achieve 1.45-1.50x cumulative  
**Duration**: 7 days (compressed timeline)  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, a highly skilled software engineer tasked with profiling Parslet v3.3.0 to identify the next optimization target and achieve 1.45-1.50x cumulative performance improvement.

---

## Critical Context from Session 18

### Performance Baseline (v3.3.0)

**Current Performance**:
- Average speedup: **3.48x** ±2.47x (vs. vanilla 2.0.0)
- Mechanism: Eliminated Position object allocation overhead
- Tests: **713/714 passing** (1 pre-existing failure)
- Status: **Production ready**

### Benchmark Results (3 runs)
- Run 1: 6.36x average
- Run 2: 2.67x average  
- Run 3: 1.41x average
- **Overall**: 3.48x average

### Key Achievement

Successfully eliminated Position object allocation from hot path:
- **Before**: `Position.new()` on every `source.pos` call
- **After**: Direct integer return (zero allocations)
- **Impact**: Dramatic speedup in parsing operations

---

## Mission

Profile v3.3.0 to identify the next optimization bottleneck and achieve 1.45-1.50x cumulative performance (vs. vanilla 2.0.0).

### Target Improvement

- **Primary target**: 1.45-1.50x cumulative (vs. vanilla 2.0.0)
- **Additional gain**: +3-5% over v3.3.0 (3.48x → 3.62x average)
- **Stretch target**: 1.55x cumulative
- **Quality**: Maintain 713/714 tests passing

---

## Your Task

Follow the implementation plan in [`docs/CONTINUATION_PLAN_SESSION19.md`](CONTINUATION_PLAN_SESSION19.md) and track progress in [`docs/IMPLEMENTATION_STATUS_SESSION19.md`](IMPLEMENTATION_STATUS_SESSION19.md).

### Phase 1: Memory Profiling (Day 1-2) 🔴 CRITICAL

**Your Task**: Verify Position elimination and identify next allocation bottleneck

#### 1.1: Verify Position Elimination

**Run memory profiler**:
```bash
ruby -r memory_profiler -e '
  require "parslet"
  
  MemoryProfiler.report do
    # Test with JSON parser on sample input
    json = Parslet::Examples::JsonParser.new
    1000.times do
      json.parse("{\"foo\": \"bar\"}")
    end
  end.pretty_print(detailed_report: false)
' > docs/memory_profile_v3.3.0.txt
```

**Analyze output**:
- Look for "Position" in allocated objects
- Should be 0 or near-zero Position allocations
- Compare with Session 15 baseline (if available)
- Calculate reduction percentage

**Document**:
- Position allocations eliminated: Yes/No
- Percentage reduction from Session 15
- Verification complete

#### 1.2: Identify Next Allocation Bottleneck

**Analyze memory profile**:
```bash
# Look at top allocated object types
grep -A 20 "allocated objects by class" docs/memory_profile_v3.3.0.txt
```

**Questions to answer**:
1. What is the most frequently allocated object type?
2. Where in the codebase are these being allocated?
3. Are these allocations necessary or avoidable?
4. What would be the performance impact of reducing them?

**Deliverable**: Create [`docs/PROFILING_ANALYSIS_SESSION19.md`](PROFILING_ANALYSIS_SESSION19.md) with:
- Memory profiling results
- Top allocation sources
- Analysis of necessity
- Recommended optimization target

---

### Phase 2: CPU Profiling (Day 2-3) 🔴 CRITICAL

**Your Task**: Identify CPU-bound hotspots after allocation optimization

#### 2.1: Profile CPU Hotspots

**Run stackprof**:
```bash
# Create profiling script if needed
cat > benchmark/profile_session19.rb << 'EOF'
require 'stackprof'
require 'parslet'

# Load example parsers
load 'benchmark/parsers/json_parser.rb'
load 'benchmark/parsers/calc_parser.rb'

# Profile JSON parser (most stable from Session 18)
json = JsonParser.new
input = File.read('benchmark/inputs/json/small.json')

StackProf.run(mode: :cpu, out: 'stackprof-session19-cpu.dump') do
  1000.times do
    json.parse(input) rescue nil
  end
end
EOF

ruby benchmark/profile_session19.rb
stackprof --mode=cpu stackprof-session19-cpu.dump --text --limit 30 > docs/cpu_profile_v3.3.0.txt
```

**Analyze**:
- Top 30 methods by CPU time (samples)
- Top 30 methods by call count
- Look for patterns:
  - Cache lookups (Context#try_with_cache)
  - String operations (concatenation, slicing)
  - Array operations (flatten, push, etc.)
  - Method call overhead

**Deliverable**: Add CPU profiling results to PROFILING_ANALYSIS_SESSION19.md

#### 2.2: Identify Optimization Opportunities

**Prioritize candidates**:

**High Impact, Low Complexity** (prioritize):
- Frozen string literals for error messages
- Method inlining for frequently called methods
- Array pre-allocation for known sizes

**High Impact, Medium Complexity**:
- Cache optimization (smarter eviction, better keys)
- String pooling for repeated values
- Hash optimization for faster lookups

**High Impact, High Complexity**:
- Fundamental algorithm changes
- Data structure replacements
- Major architectural refactoring

**Select one optimization target** based on:
1. Highest CPU time in profiling
2. Clear optimization path
3. Measurable improvement potential

**Deliverable**: Updated PROFILING_ANALYSIS_SESSION19.md with:
- Prioritized optimization candidates
- Selected target for implementation
- Estimated impact and complexity
- Implementation approach

---

### Phase 3: Targeted Optimization (Day 3-5) 🟡 HIGH PRIORITY

**Your Task**: Implement the highest-priority optimization from profiling

#### 3.1: Design Optimization

Based on profiling results, design the optimization.

**Likely scenarios**:

**Scenario A: Context Caching Bottleneck**
```ruby
# Current: Hash-based cache
@cache[position][parslet_id] = result

# Optimization options:
# 1. Use more efficient keys
# 2. Implement LRU eviction
# 3. Pre-allocate hash capacity
# 4. Use different data structure
```

**Scenario B: String Allocation Bottleneck**
```ruby
# Current: String allocations for error messages
error_msgs[:failed] = "Expected #{@str.inspect}, but got "

# Optimization: Frozen string literals
@error_msgs = {
  premature: 'Premature end of input'.freeze,
  failed: "Expected #{@str.inspect}, but got ".freeze
}.freeze
```

**Scenario C: Method Call Overhead**
```ruby
# Current: Multiple method calls
source.pos
source.bytepos

# Optimization: Inline or cache
# (Less likely given Session 18 already optimized this)
```

**Design requirements**:
- Maintain architectural correctness
- Preserve all test coverage
- Backward compatible API
- Clear, measurable improvement

**Deliverable**: Design document in PROFILING_ANALYSIS_SESSION19.md

#### 3.2: Implement Optimization

**Implementation strategy**:
1. Make ONE change at a time
2. Run tests after each change
3. Commit if tests pass
4. If tests fail, verify behavior is correct (tests may need updating)
5. Benchmark after all changes complete

**Example: Frozen String Literals**
```ruby
# Find all error message definitions
grep -r "error_msgs\s*=" lib/parslet/atoms/

# Update each file to use frozen strings
# Pattern:
# Before:
error_msgs[:failed] = "Expected #{foo}"

# After:
@error_msgs = {
  failed: "Expected #{foo}".freeze
}.freeze
```

**Validation after implementation**:
- Run full test suite: `bundle exec rspec`
- Expected: 713/714 passing (baseline maintained)
- Run single benchmark: `ruby benchmark/fair_comparison.rb`
- Look for improvement vs. v3.3.0

**Deliverable**: Implementation complete with tests passing

---

### Phase 4: Benchmarking (Day 5-6) 🔴 CRITICAL

**Your Task**: Validate performance improvement with 3 runs

#### 4.1: Run Fair Comparison (3 runs)

**Important**: Run 3 times with 60-second cooldown to validate stability

```bash
echo "=== BENCHMARK RUN 1/3 ===" && ruby benchmark/fair_comparison.rb

sleep 60

echo "=== BENCHMARK RUN 2/3 ===" && ruby benchmark/fair_comparison.rb

sleep 60

echo "=== BENCHMARK RUN 3/3 ===" && ruby benchmark/fair_comparison.rb
```

**Record results**:
- Run 1: Average speedup
- Run 2: Average speedup
- Run 3: Average speedup
- Overall average

**Expected results** (adjust based on optimization):
- Modest improvement: 3.52x - 3.58x (+3-5% over v3.3.0)
- Good improvement: 3.58x - 3.70x (+5-10% over v3.3.0)
- Exceptional: >3.70x (>10% over v3.3.0)

#### 4.2: Compare vs. Baselines

**Create comparison matrix**:

| Metric | Vanilla 2.0.0 | v3.2.0 | v3.3.0 | v3.4.0 | Change |
|--------|--------------|--------|--------|--------|--------|
| Average | 1.0x | 1.27x | 3.48x | ??? | +?% |
| JSON | 1.0x | 1.7x | 2.17x | ??? | +?% |
| Calc | 1.0x | 1.3x | 3.92x | ??? | +?% |

**Validate**:
- Is improvement measurable and repeatable?
- Are all test cases stable or improved?
- Any regressions present?
- Is variance acceptable (±5-10%)?

**Deliverable**: Create [`docs/BENCHMARK_RESULTS_v3.4.0.md`](BENCHMARK_RESULTS_v3.4.0.md)

---

### Phase 5: Documentation (Day 6-7) 🟡 HIGH PRIORITY

**Your Task**: Document v3.4.0 optimization and results

#### 5.1: Update Performance Documentation

Update [`docs/PERFORMANCE_BENCHMARKS.adoc`](PERFORMANCE_BENCHMARKS.adoc):

Add v3.4.0 section:
```asciidoc
=== Version 3.4.0 Results

Optimization: [Brief description of what was optimized]

Overall Performance:
- Average: X.XXx (vs. vanilla 2.0.0)
- Improvement over v3.3.0: +X.X%

[Table of results by parser]
```

#### 5.2: Update Architecture Roadmap

Update [`docs/ARCHITECTURE_V4_PLAN.adoc`](ARCHITECTURE_V4_PLAN.adoc):

Find the phase that corresponds to the optimization implemented and mark it complete.

#### 5.3: Update README

Update [`README.adoc`](../../README.adoc):

Find performance numbers and update to v3.4.0 results.

#### 5.4: Create Release Notes

Create [`docs/RELEASE_NOTES_v3.4.0.md`](RELEASE_NOTES_v3.4.0.md):

```markdown
# Parslet v3.4.0 Release Notes

Date: [DATE]

## Performance Improvements

### [Optimization Name]

[Brief description of optimization]

**Impact**: +X% improvement over v3.3.0, X.XXx vs. vanilla 2.0.0

**Details**:
- [Technical detail 1]
- [Technical detail 2]

## Benchmarks

[Key benchmark results]

## Breaking Changes

[None expected, or list if any]

## Migration

[None required, or steps if needed]
```

#### 5.5: Create Session Completion Document

Create [`docs/SESSION_19_COMPLETE.md`](SESSION_19_COMPLETE.md):

Document:
- Profiling findings (memory + CPU)
- Optimization selected and why
- Implementation approach
- Performance results
- Lessons learned
- Recommendations for v3.5.0

---

## Critical Principles (MUST FOLLOW)

### Object-Oriented Architecture

1. **Single Responsibility**: Each class/method has one clear purpose
2. **Open/Closed**: Extend behavior without modifying existing code
3. **Separation of Concerns**: Optimization ≠ correctness ≠ testing
4. **Backward Compatibility**: Maintain existing APIs

### MECE (Mutually Exclusive, Collectively Exhaustive)

1. **Profiling**: Memory vs. CPU (distinct domains)
2. **Optimization**: One target at a time (focused effort)
3. **Validation**: Tests vs. Benchmarks vs. Profiling (complementary)

### Testing Philosophy

1. **Behavior correctness > passing tests**: Tests may need updates
2. **Incremental testing**: Test after each change
3. **Baseline maintenance**: 713/714 passing required
4. **Profile to verify**: Confirm bottleneck actually reduced

---

## Contingency Plans

### If No Clear Bottleneck Found

**Option A**: Micro-optimizations
- Frozen string literals everywhere
- Method inlining (manual or via metaprogramming)
- Array pre-allocation
- Combined estimated impact: +2-3%

**Option B**: Developer Experience
- Better error messages
- Enhanced debugging tools
- API improvements
- Ship as v3.3.1 (focus shift)

**Option C**: Ship v3.3.0 as Final
- Already far exceeded target (3.48x vs. 1.35x)
- Move to feature development
- Declare victory on optimization

### If Target Not Met

**Decision tree**:
- 3.52x+ (modest gain): Ship as v3.4.0 ✓
- 3.48-3.52x (minimal gain): Ship as v3.3.1, document findings
- <3.48x (regression): Investigate cause, may revert
- <3.35x (significant regression): Revert, different approach

**Remember**: Even small gains are valuable if:
- Reproducible across 3 runs
- Tests still passing
- Code quality maintained or improved

### If Behind Schedule

**Priority order**:
1. Profiling (Days 1-2) - **DO NOT SKIP**
2. Select optimization target (Day 3) - **DO NOT SKIP**
3. Implement (Days 4-5) - **DO NOT SKIP**
4. Benchmark (Day 6) - **DO NOT SKIP**
5. Documentation (Day 7) - Can defer to v3.4.1

---

## Quick Start Commands

```bash
# 1. Memory profiling
ruby -r memory_profiler -e '
  require "parslet"
  require "benchmark/parsers/json_parser"
  
  MemoryProfiler.report do
    json = JsonParser.new
    1000.times { json.parse("{\"a\":1}") rescue nil }
  end.pretty_print
' > docs/memory_profile_v3.3.0.txt

# 2. CPU profiling
ruby benchmark/profile_session19.rb  # Create this script first
stackprof stackprof-session19-cpu.dump --text --limit 30 > docs/cpu_profile_v3.3.0.txt

# 3. Analyze profiles
cat docs/memory_profile_v3.3.0.txt docs/cpu_profile_v3.3.0.txt

# 4. Implement optimization
# [Edit files based on profiling results]

# 5. Test
bundle exec rspec

# 6. Benchmark (3 runs)
ruby benchmark/fair_comparison.rb && sleep 60 && \
ruby benchmark/fair_comparison.rb && sleep 60 && \
ruby benchmark/fair_comparison.rb
```

---

## Success Criteria

### Must Achieve (Release Blockers)

- [ ] **Profiling complete**: Memory + CPU analysis done
- [ ] **Bottleneck identified**: Clear optimization target
- [ ] **Optimization implemented**: Code complete, tests passing
- [ ] **Performance measured**: 3 benchmark runs complete
- [ ] **Results documented**: All docs updated
- [ ] **Tests passing**: 713/714 baseline maintained

### Quality Gates

- [ ] Correct architecture maintained
- [ ] MECE principles followed
- [ ] Separation of concerns preserved
- [ ] Backward compatible API
- [ ] Reproducible improvements (3 runs)

### Nice to Have

- [ ] Stretch target achieved (1.55x cumulative)
- [ ] Memory usage reduced (measured)
- [ ] GC stats improved
- [ ] Additional opportunities identified for v3.5.0

---

## Expected Timeline

- **Day 1**: Memory profiling, verify Position elimination
- **Day 2**: CPU profiling, identify bottleneck
- **Day 3**: Select optimization target, design approach
- **Day 4**: Implement optimization (part 1)
- **Day 5**: Implement optimization (part 2), test thoroughly
- **Day 6**: Run 3 benchmark runs, analyze results
- **Day 7**: Update all documentation, create session completion

**Total**: 7 days compressed

---

## Important Notes

### Benchmark Variance is Normal

Session 18 showed high variance (1.41x - 6.36x). This is normal due to:
- GC timing differences
- System load variations
- Cache warming effects
- Statistical variance

**Solution**: Run 3 times, average results, accept ±10-20% variance.

### Profile First, Optimize Second

**Do not** guess at optimizations. Always:
1. Profile to identify actual bottleneck
2. Verify bottleneck is worth optimizing
3. Design optimization approach
4. Implement and measure
5. Validate improvement is real

### Some Optimizations May Not Help

Not all optimizations will show measurable improvement:
- Micro-optimizations: May be too small to measure
- Wrong target: Not actually the bottleneck
- Implementation issues: Done incorrectly

**Be prepared to**:
- Revert changes if no improvement
- Try different approach
- Accept that some optimizations don't work

### Documentation is Critical

Even if optimization doesn't achieve target:
- Document what was tried
- Document results (good or bad)
- Document lessons learned
- Help future optimization efforts

---

## Next Session Preview

After v3.4.0 ships (Session 19 complete):

**Session 20 Options**:

1. **Continue optimization** (if clear next target exists)
   - Target: 1.55x+ cumulative
   - Duration: 1-2 weeks

2. **Feature development** (if optimization plateaus)
   - New parser features
   - API enhancements
   - Developer experience

3. **Maintenance phase** (if optimization complete)
   - Bug fixes
   - Stability improvements
   - Documentation updates

**Decision**: Based on Session 19 profiling results and project priorities.

---

**Let's profile v3.3.0, find the next bottleneck, and keep improving performance!**