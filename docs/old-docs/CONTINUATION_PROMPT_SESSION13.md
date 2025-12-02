# Continuation Prompt: Session 13 - Benchmark Stabilization & Per-Parser Optimization

**Session**: 13  
**Priority**: HIGH - Continue performance optimization  
**Goal**: Stabilize benchmarks and achieve ≥1.30x speedup in 10-12/14 cases (71-86%)  
**Duration**: 4-6 hours  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, tasked with stabilizing micro-benchmarks and implementing per-parser cache optimization to achieve ≥1.30x performance improvement in at least 10-12 of 14 benchmark cases. Session 12 made significant progress (4/14 cases meeting threshold) but encountered high variance in measurements. You must stabilize benchmarks and optimize per-parser to continue progress.

---

## Critical Context from Session 12

### What Was Achieved ✅

1. **Root Cause Identified**: Cache overhead is 15-20% of execution time for small inputs
2. **Adaptive Caching Implemented**: Disables cache for inputs <1000 bytes
3. **4 Cases Improved to ≥1.30x**: json/small (1.45x), json/tiny (1.36x), erb/small (1.36x), erb/tiny (1.30x)
4. **Profiling Infrastructure Created**: [`benchmark/profile_case.rb`](../benchmark/profile_case.rb), [`benchmark/benchmark_single.rb`](../benchmark/benchmark_single.rb)

### Current Challenges ⚠️

1. **High Variance**: Micro-benchmarks show ±5-15% variance (sentence/tiny: 0.85x-1.34x!)
2. **Fixed Threshold Limitation**: 1000-byte threshold doesn't optimize all parsers equally
3. **Only 29% Success Rate**: 4/14 cases meet ≥1.30x (need 71-86%)

### Performance Status

**Meeting ≥1.30x** (4/14):
- json/small: 1.45x ✅
- json/tiny: 1.36x ✅  
- erb/small: 1.36x ✅
- erb/tiny: 1.30x ✅

**Below 1.30x** (10/14 - need optimization):
- sentence/tiny: 0.85x (⚠️ high variance)
- calc/medium: 1.12x (need +16%)
- sentence/medium: 1.14x (need +14%)
- calc/large: 1.15x (need +13%)
- calc/small: 1.15x (need +13%)
- erb/medium: 1.15x (need +13%)
- sentence/small: 1.16x (need +12%)
- erb/large: 1.19x (need +9%)
- calc/tiny: 1.20x (need +8%)
- json/medium: 1.21x (need +7%)

---

## Mission

**Stabilize micro-benchmarks and implement per-parser cache optimization to achieve ≥1.30x improvement in 10-12/14 benchmark cases while maintaining zero regressions.**

---

## Your Task

Follow the implementation plan in [`docs/CONTINUATION_PLAN_SESSION13.md`](CONTINUATION_PLAN_SESSION13.md) and track progress in [`docs/IMPLEMENTATION_STATUS_SESSION13.md`](IMPLEMENTATION_STATUS_SESSION13.md).

### Phase 1: Benchmark Stabilization (1.5 hours) 🔴 CRITICAL

**The Problem**: High variance makes it impossible to validate optimizations

**Your Task**: Reduce variance from ±10% to <3%

1. **Increase iteration counts in [`benchmark/fair_comparison.rb`](../benchmark/fair_comparison.rb)**:
   - Tiny inputs (0-100 bytes): 50 → 500 iterations
   - Small inputs (100-1000 bytes): 50 → 200 iterations
   - Medium inputs (1-10KB): Keep 30 iterations
   - Large inputs (>10KB): Keep 10 iterations

2. **Improve GC control**:
   ```ruby
   iterations.times do
     # Full GC before each iteration
     GC.start(full_mark: true, immediate_sweep: true)
     GC.compact if GC.respond_to?(:compact)
     GC.disable
     
     start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
     parser.parse(input)
     end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
     
     GC.enable
     times << (end_time - start_time)
   end
   ```

3. **Multiple runs with median**:
   - Run complete benchmark 3 times
   - Calculate median speedup per case
   - Report confidence interval
   - Flag cases with >3% variance

4. **Validate**: Run benchmarks, verify variance <3%

**Expected Outcome**: Stable, reliable performance measurements

---

### Phase 2: Per-Parser Cache Threshold Tuning (2 hours) 🟡 HIGH PRIORITY

**The Problem**: Fixed 1000-byte threshold doesn't optimize all parsers equally

**Why**: Different parsers have different characteristics:
- JSON: High recursion/repetition → benefits from cache even for small inputs
- Calc: Lower repetition → cache hurts more than helps
- Sentence: Linear grammar → minimal cache benefit regardless

**Your Task**: Implement parser-specific cache thresholds

1. **Profile each parser at multiple sizes**:
   ```bash
   # Profile calc at different sizes
   ruby -I lib benchmark/profile_case.rb calc tiny    # 17 bytes
   ruby -I lib benchmark/profile_case.rb calc small   # 273 bytes
   ruby -I lib benchmark/profile_case.rb calc medium  # 3279 bytes
   
   # Repeat for json, erb, sentence
   ```

2. **Analyze cache benefit**:
   - Look at `try_with_cache` percentage in profiling output
   - If >10%: Cache hurts → increase threshold
   - If <5% and high hit rate: Cache helps → decrease threshold
   - Document findings in `docs/SESSION_13_PROFILING_ANALYSIS.md`

3. **Implement parser-specific thresholds** in [`lib/parslet/atoms/context.rb`](../lib/parslet/atoms/context.rb):
   
   ```ruby
   # Parser-specific cache thresholds (based on profiling)
   PARSER_CACHE_THRESHOLDS = {
     'JsonParser' => 500,      # High repetition, benefits early
     'ErbParser' => 800,       # Moderate repetition
     'CalcParser' => 2000,     # Low repetition, needs larger input
     'SentenceParser' => 5000, # Linear grammar, minimal benefit
     :default => 1000
   }.freeze
   
   def initialize(reporter=..., parser_class: nil, adaptive_cache_threshold: nil)
     # Auto-detect threshold based on parser class
     threshold = adaptive_cache_threshold
     if threshold.nil? && parser_class
       parser_name = parser_class.name.split('::').last
       threshold = PARSER_CACHE_THRESHOLDS[parser_name] || 
                   PARSER_CACHE_THRESHOLDS[:default]
     end
     threshold ||= PARSER_CACHE_THRESHOLDS[:default]
     
     @adaptive_cache_threshold = threshold
     # ... rest of initialization ...
   end
   ```

4. **Update parser integration** (if needed):
   - Ensure context receives parser class info
   - Make backward compatible
   - Test with all parsers

5. **Benchmark and validate**:
   ```bash
   bundle exec rspec  # Ensure tests pass
   ruby benchmark/fair_comparison.rb  # Measure improvement
   ```

**Expected Impact**:
- Calc parsers: +5-10%
- Sentence parsers: +10-15%
- JSON/ERB parsers: Maintain performance
- **Target: 8-10 cases meeting ≥1.30x**

---

### Phase 3: Flatten Optimization (1.5 hours) 🟢 MEDIUM PRIORITY

**The Problem**: Flatten operations still consume 6-7% of execution time

**Profiling shows**: `flatten` is called even when results are already flat

**Your Task**: Skip flatten for atoms that produce flat results by construction

1. **Add flat? method to [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb)**:
   ```ruby
   # Returns true if this atom produces flat results by construction
   def flat?
     false  # Default: assume needs flattening
   end
   ```

2. **Mark atoms that produce flat results**:
   - [`lib/parslet/atoms/str.rb`](../lib/parslet/atoms/str.rb): `def flat?; true; end`
   - [`lib/parslet/atoms/re.rb`](../lib/parslet/atoms/re.rb): `def flat?; true; end`
   - Single-element sequences: Check if child is flat
   - Named atoms: Inherit child's flatness

3. **Skip flatten in [`lib/parslet/atoms/can_flatten.rb`](../lib/parslet/atoms/can_flatten.rb)**:
   ```ruby
   def flatten(value, named=false)
     return value unless value.is_a?(Array)
     
     # Quick check: if marked as flat, skip flattening
     if value.size == 2 && value[0] == :flat
       return value[1]
     end
     
     # ... existing flatten logic ...
   end
   ```

4. **Update atoms to mark flat results**:
   ```ruby
   # In Str#try and Re#try
   def try(source, context, consume_all)
     # ... matching logic ...
     [:flat, result]  # Mark as flat to skip flattening
   end
   ```

5. **Test thoroughly**:
   ```bash
   bundle exec rspec spec/parslet/atoms/  # Test atom behavior
   bundle exec rspec  # Full test suite
   ```

**Expected Impact**: +3-5% improvement across all cases

---

### Phase 4: Validation & Iteration (1 hour) 🔴 CRITICAL

**Your Task**: Verify improvements and iterate if needed

1. **Run stabilized benchmarks** (3 complete runs):
   ```bash
   ruby benchmark/fair_comparison.rb > results1.txt
   ruby benchmark/fair_comparison.rb > results2.txt
   ruby benchmark/fair_comparison.rb > results3.txt
   ```

2. **Calculate statistics**:
   ```ruby
   # Count cases meeting threshold
   ruby -e "
     require 'json'
     results = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
     met = results['comparisons'].count { |c| c['speedup'] >= 1.30 }
     total = results['comparisons'].size
     avg = results['comparisons'].map { |c| c['speedup'] }.sum / total
     puts \"Cases ≥1.30x: #{met}/#{total} (#{(met*100.0/total).round(0)}%)\"
     puts \"Average speedup: #{avg.round(2)}x\"
   "
   ```

3. **Check success criteria**:
   - [ ] 10+ cases (≥71%) meet ≥1.30x? 
   - [ ] Variance <3% for all cases?
   - [ ] Zero significant regressions (<5%)?
   - [ ] 674+ tests passing?
   - [ ] Average speedup ≥1.35x?

4. **If not meeting criteria**, iterate:
   - Profile cases still below 1.30x
   - Identify next bottleneck
   - Apply targeted optimization
   - Re-validate

5. **Document results** in `docs/SESSION_13_COMPLETE.md`

---

## Quick Start Commands

```bash
# 1. Stabilize benchmarks (Phase 1)
# Edit benchmark/fair_comparison.rb to increase iterations
ruby benchmark/fair_comparison.rb  # Run 3 times, check variance

# 2. Profile for per-parser tuning (Phase 2)
ruby -I lib benchmark/profile_case.rb calc small
ruby -I lib benchmark/profile_case.rb json small
ruby -I lib benchmark/profile_case.rb erb small
ruby -I lib benchmark/profile_case.rb sentence small

# 3. Implement per-parser thresholds
# Edit lib/parslet/atoms/context.rb

# 4. Test
bundle exec rspec

# 5. Benchmark
ruby benchmark/fair_comparison.rb

# 6. Validate results
ruby -e "
  require 'json'
  data = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
  met = data['comparisons'].select { |c| c['speedup'] >= 1.30 }
  puts \"Cases meeting ≥1.30x: #{met.size}/#{data['comparisons'].size}\"
  met.each { |c| puts \"  #{c['parser']}/#{c['input_file']}: #{c['speedup']}x\" }
  below = data['comparisons'].select { |c| c['speedup'] < 1.30 }
  puts \"\nCases below 1.30x: #{below.size}\"
  below.each { |c| puts \"  #{c['parser']}/#{c['input_file']}: #{c['speedup']}x\" }
"

# 7. When 10+ cases meet threshold, document in SESSION_13_COMPLETE.md
```

---

## Success Criteria

### Must Achieve (Release Blockers)
- [ ] **10+ cases (≥71%) meet ≥1.30x threshold**
- [ ] Benchmark variance <3% for all cases
- [ ] Zero significant regressions (<5% loss)
- [ ] 674+ tests passing
- [ ] Average speedup ≥1.35x

### Quality Gates
- [ ] Each optimization backed by profiling data
- [ ] Changes well-tested
- [ ] Documentation comprehensive
- [ ] Code remains maintainable
- [ ] Per-parser thresholds documented

### Nice to Have
- [ ] 12+ cases (≥86%) meet ≥1.30x
- [ ] Average speedup ≥1.40x
- [ ] All cases variance <2%
- [ ] 675/675 tests passing
- [ ] Clear path to 100% in Session 14

---

## Expected Timeline

**Hour 1-1.5**: Phase 1 (Stabilization)
- Update fair_comparison.rb with higher iterations
- Improve GC control
- Run 3 benchmark passes
- Verify variance <3%

**Hour 2-4**: Phase 2 (Per-Parser Tuning)
- Profile each parser at multiple sizes
- Analyze cache benefit
- Implement parser-specific thresholds
- Test and benchmark

**Hour 4.5-6**: Phase 3 (Flatten Optimization)
- Add flat? method to base
- Mark flat atoms
- Skip flatten logic
- Test and benchmark

**Hour 6**: Phase 4 (Validation)
- Run final benchmarks (3 passes)
- Calculate statistics
- Verify success criteria
- Document results

---

## Contingency Plans

### If Variance Still High (>5%)
- Increase iterations further (500 → 1000 for tiny)
- Run each benchmark in separate process
- Focus on median over mean
- Accept variance, document limitations

### If Per-Parser Tuning Insufficient
- Try dynamic threshold based on runtime metrics
- Implement per-rule caching decisions
- Focus on next bottleneck (flatten, dispatch)

### If Time Runs Short
**Priority Order**:
1. Phase 1 (Stabilization) - MUST DO
2. Phase 2 (Per-Parser) - MUST DO
3. Phase 4 (Validation) - MUST DO
4. Phase 3 (Flatten) - SKIP IF NEEDED

### If Tests Fail
- Revert problematic changes
- Fix tests if behavior change is correct
- Never ship with failing tests

---

## Important Notes

### What We Have
- ✅ Root cause identified (cache overhead)
- ✅ Adaptive caching implemented
- ✅ Profiling infrastructure
- ✅ 4 cases meeting threshold
- ✅ Zero regressions in stable cases

### What We Need
- 🎯 Stable benchmarks (variance <3%)
- 🎯 Per-parser optimization
- 🎯 10-12 cases meeting ≥1.30x (71-86%)
- 🎯 Clear path to 100%

### Remember
**The variance problem is critical** - we cannot validate optimizations with ±10% measurement noise. Stabilization is the foundation for all other work.

---

**Let's stabilize benchmarks and achieve 71-86% success rate!**