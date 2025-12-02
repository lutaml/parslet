# Continuation Prompt: Session 15 - Benchmark Stabilization & Targeted Optimization

**Session**: 15  
**Priority**: CRITICAL - Fix benchmark variance before continuing optimization  
**Goal**: Achieve ≥1.30x speedup in 10-12 of 14 benchmark cases (71-86%) with reliable measurements  
**Duration**: 3-4 hours  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, a highly skilled software engineer tasked with fixing benchmark variance issues and achieving ≥1.30x performance improvement in 10-12 of 14 benchmark cases through targeted optimization. Session 14 completed comprehensive profiling but discovered high benchmark variance (±40-99%) that prevents reliable validation of optimizations. You must first stabilize benchmarks to <5% variance, then apply targeted optimizations based on profiling data.

---

## Critical Context from Session 14

### What Was Achieved ✅

1. **Comprehensive Profiling**: Detailed analysis of calc, sentence, and json parsers
2. **Bottleneck Identification**: Quantified overhead percentages for major operations
3. **Position Caching Lesson**: Discovered that caching lightweight objects adds overhead
4. **Documentation**: Created detailed SESSION_14_PROFILING_ANALYSIS.md

### Current Challenge ⚠️

**High Benchmark Variance**: ±40-99% across runs makes optimization validation impossible

**Evidence from Session 14**:
- Run 1: Average 2.31x, erb/medium 6.42x
- Run 2: Average 1.38x, erb/medium 0.28x (same code!)
- Cannot distinguish real improvements from noise

### Performance Status

**Current**: 5/14 cases (35.7%) meet ≥1.30x threshold  
**Target**: 10-12 cases (71-86%)  
**Gap**: Need 5-7 more cases

### Known Bottlenecks from Session 14 Profiling

**Priority 1: Calc Parser**
- Base#succ: 9.07% (102,300 calls) - architectural issue (call volume, not implementation)
- Sequence overhead: 2.81% (32,100 calls)
- Flatten overhead: 10.5% total

**Priority 2: Sentence Parser**
- String concatenation: 7% total (Slice#+ 3.68%, String#+ 3.38%)
- Array indexing: 8.97% (highest of all parsers)
- Flatten overhead: 12.4% total

**Priority 3: All Parsers**
- Flatten operations: 8-12% across all parsers
- Source operations: 2-7% depending on parser

---

## Mission

**Phase 1 (CRITICAL)**: Fix benchmark variance to <5% across all test cases through systematic investigation and stabilization techniques.

**Phase 2-4**: Once measurements are reliable, apply targeted optimizations based on Session 14 profiling to achieve 71-86% success rate.

---

## Your Task

Follow the implementation plan in [`docs/CONTINUATION_PLAN_SESSION15.md`](CONTINUATION_PLAN_SESSION15.md) and track progress in [`docs/IMPLEMENTATION_STATUS_SESSION15.md`](IMPLEMENTATION_STATUS_SESSION15.md).

### Phase 1: Verify and Fix Benchmark Stability (1-1.5 hours) 🔴 CRITICAL

**The Problem**: Benchmark variance ±40-99% prevents validation of any optimizations

**Your Task**: Systematically identify and fix variance sources

1. **Establish baseline variance** (30 minutes):
   ```bash
   cd /Users/mulgogi/src/plurimath/parslet
   
   # Run 5 times and capture results
   for i in {1..5}; do
     echo "=== Run $i ===" | tee -a variance_test.log
     ruby benchmark/fair_comparison.rb 2>&1 | grep -A 30 "FAIR BENCHMARK SUMMARY" | tee -a variance_test.log
     sleep 10
   done
   
   # Analyze variance per case
   ruby -e "
     require 'json'
     runs = []
     5.times do |i|
       data = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
       runs << data['comparisons']
     end
     
     # Calculate variance for each case
     runs.first.each do |case_data|
       parser = case_data['parser']
       file = case_data['input_file']
       
       speedups = runs.map do |run|
         c = run.find { |x| x['parser'] == parser && x['input_file'] == file }
         c['speedup'] if c
       end.compact
       
       next if speedups.size < 3
       avg = speedups.sum / speedups.size
       stddev = Math.sqrt(speedups.map { |s| (s - avg)**2 }.sum / speedups.size)
       variance_pct = (stddev / avg * 100).round(1)
       
       status = variance_pct < 5 ? '✅' : '⚠️'
       puts \"#{status} #{parser}/#{file}: #{avg.round(2)}x (±#{variance_pct}%)\"
     end
   "
   ```

2. **Investigate variance sources** (30 minutes):
   
   Test these hypotheses:
   
   **Hypothesis A: Parser instance reuse**
   - Current code creates parser once, may accumulate state
   - Solution: Create fresh parser for EACH iteration
   
   **Hypothesis B: Insufficient iterations**
   - Session 13 used 500 for tiny, 200 for small
   - May need even more for stability
   
   **Hypothesis C: JIT compilation inconsistency**
   - YJIT state varies between runs
   - Solution: Disable YJIT or extend warmup
   
   **Hypothesis D: Background processes/CPU scaling**
   - macOS power management
   - Solution: Pin CPU frequency or increase cooldown

3. **Apply fixes systematically** (30 minutes):
   
   **Fix A: Fresh Parser Per Iteration** (RECOMMENDED FIRST)
   
   In [`benchmark/fair_comparison.rb`](../benchmark/fair_comparison.rb), line 180-193:
   ```ruby
   iterations.times do
     GC.start(full_mark: true, immediate_sweep: true)
     GC.compact if GC.respond_to?(:compact)
     GC.disable
     
     # CRITICAL: Create FRESH parser instance per iteration
     fresh_parser = parser_class.new
     
     start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
     fresh_parser.parse(input)  # Use fresh instance
     end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
     
     GC.enable
     times << (end_time - start_time)
   end
   ```
   
   **Fix B: Increase Iterations** (if Fix A insufficient)
   
   In [`benchmark/fair_comparison.rb`](../benchmark/fair_comparison.rb), line 158-164:
   ```ruby
   iterations = case input_size
   when 0...100 then 1000      # Tiny: 1000 (up from 500)
   when 100...1000 then 500    # Small: 500 (up from 200)
   when 1000...10_000 then 50  # Medium: 50 (up from 30)
   when 10_000...100_000 then 20 # Large: 20 (up from 10)
   else 10
   end
   ```

4. **Validate fixes** (30 minutes):
   ```bash
   # Run 5 more times with fixes applied
   for i in {1..5}; do
     echo "=== Run $i (after fixes) ==="
     ruby benchmark/fair_comparison.rb 2>&1 | grep -A 30 "FAIR BENCHMARK SUMMARY" | tee -a variance_test_fixed.log
     sleep 10
   done
   
   # Compare before/after
   # Should see variance <5% for all cases
   ```

**Expected Outcome**: All 14 cases show <5% variance across 5 consecutive runs

---

### Phase 2: Re-establish Performance Baseline (30 minutes) 🟡 HIGH PRIORITY

**Your Task**: Document stable baseline after variance fixes

1. **Run 3 official baseline measurements**:
   ```bash
   ruby benchmark/fair_comparison.rb > baseline_run1.txt
   sleep 60
   ruby benchmark/fair_comparison.rb > baseline_run2.txt
   sleep 60
   ruby benchmark/fair_comparison.rb > baseline_run3.txt
   ```

2. **Calculate baseline statistics**:
   ```ruby
   ruby -e "
     require 'json'
     
     runs = [1,2,3].map do |i|
       JSON.parse(File.read('benchmark/results/fair_comparison.json'))
     end
     
     puts 'Baseline Performance (3 runs):'
     puts '=' * 80
     
     comparisons = runs.first['comparisons']
     comparisons.each do |case_data|
       parser = case_data['parser']
       file = case_data['input_file']
       
       speedups = runs.map do |run|
         c = run['comparisons'].find { |x| x['parser'] == parser && x['input_file'] == file }
         c['speedup'] if c
       end.compact
       
       avg = speedups.sum / speedups.size
       min = speedups.min
       max = speedups.max
       range = max - min
       
       status = avg >= 1.30 ? '✅' : '🟡'
       puts \"#{status} #{parser}/#{file}: #{avg.round(2)}x (#{min.round(2)}-#{max.round(2)}, range: #{(range*100).round(1)}%)\"
     end
   "
   ```

3. **Document in SESSION_15_BASELINE.md**

**Expected Outcome**: Clear documentation of starting point for optimization

---

### Phase 3-4: Targeted Optimization (1-1.5 hours) 🟢 MEDIUM PRIORITY

**Once benchmarks are stable**, choose ONE optimization target based on profiling:

#### Option A: Sentence Parser String Concatenation (RECOMMENDED)

**Problem**: 7% overhead from string concatenation (Slice#+ 3.68%, String#+ 3.38%)

**Approach**: Modify sentence grammar to reduce intermediate Slice creation

**Current grammar** (in benchmark/fair_comparison.rb):
```ruby
class SentenceParser < Parslet::Parser
  rule(:sentence) { (match('[^。]').repeat(1) >> str("。")).as(:sentence) }
  rule(:sentences) { sentence.repeat }
  root(:sentences)
end
```

**Problem**: Each character creates a Slice, then they're concatenated

**Solution**: Batch character collection
```ruby
class SentenceParser < Parslet::Parser
  # Collect characters in one go to reduce Slice objects
  rule(:sentence_chars) { match('[^。]').repeat(1) }
  rule(:sentence) { (sentence_chars >> str("。")).as(:sentence) }
  rule(:sentences) { sentence.repeat }
  root(:sentences)
end
```

**Testing**:
1. Modify grammar
2. Run benchmark
3. Check if sentence cases improve
4. Validate no regressions in other parsers

**Expected Impact**: sentence/small, sentence/medium improve by ~5-7%

#### Option B: Base#succ Analysis (ADVANCED)

**Problem**: 9.07% overhead in calc parser

**Challenge**: Method already optimized, issue is call volume (architectural)

**Approach**: Analyze call patterns to identify where wrapping is unnecessary

This is more complex and may not yield results. Only attempt if Phase 3 Option A succeeds quickly.

---

### Phase 5: Validation & Documentation (1 hour) 🔴 CRITICAL

**Your Task**: Validate all changes and document results

1. **Run 3 final benchmarks**:
   ```bash
   for i in {1..3}; do
     echo "=== Final Run $i ==="
     ruby benchmark/fair_comparison.rb
     sleep 60
   done
   ```

2. **Calculate final statistics**:
   ```ruby
   ruby -e "
     require 'json'
     data = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
     
     comparisons = data['comparisons']
     meeting_threshold = comparisons.count { |c| c['speedup'] >= 1.30 }
     total = comparisons.size
     avg_speedup = comparisons.map { |c| c['speedup'] }.sum / total
     
     puts \"Cases ≥1.30x: #{meeting_threshold}/#{total} (#{(meeting_threshold*100.0/total).round(1)}%)\"
     puts \"Average speedup: #{avg_speedup.round(2)}x\"
     puts \"Target: 10-12 cases (71-86%)\"
     puts meeting_threshold >= 10 ? \"✅ TARGET REACHED\" : \"⚠️ TARGET NOT REACHED\"
   "
   ```

3. **Check success criteria**:
   - [ ] 10+ cases (≥71%) meet ≥1.30x?
   - [ ] Average speedup ≥1.35x?
   - [ ] All variance <5%?
   - [ ] Zero significant regressions?
   - [ ] 674+ tests passing?

4. **Create SESSION_15_COMPLETE.md** documenting:
   - Executive summary
   - Phase 1 results (variance reduction)
   - Phase 2 results (baseline)
   - Phase 3-4 results (optimizations)
   - Final performance metrics
   - Lessons learned
   - Recommendations for Session 16

5. **Move Session 14 docs to old-docs/**:
   ```bash
   mv docs/SESSION_14_*.md docs/old-docs/
   mv docs/IMPLEMENTATION_STATUS_SESSION14.md docs/old-docs/
   ```

---

## Quick Start Commands

```bash
# 1. Establish baseline variance (Phase 1.1)
cd /Users/mulgogi/src/plurimath/parslet
for i in {1..5}; do
  echo "=== Run $i ==="
  ruby benchmark/fair_comparison.rb 2>&1 | tail -50
  sleep 10
done

# 2. Apply Fix A - Fresh parser per iteration (Phase 1.3)
# Edit benchmark/fair_comparison.rb line 180-193
# Add: fresh_parser = parser_class.new
# Change: parser.parse(input) → fresh_parser.parse(input)

# 3. Validate fixes (Phase 1.4)
for i in {1..5}; do
  echo "=== Run $i (after fix) ==="
  ruby benchmark/fair_comparison.rb 2>&1 | tail -50
  sleep 10
done

# 4. Run tests to ensure no breakage
bundle exec rspec

# 5. Establish baseline (Phase 2)
ruby benchmark/fair_comparison.rb

# 6. Apply optimization (Phase 3/4)
# Based on which optimization you choose

# 7. Final validation (Phase 5)
ruby benchmark/fair_comparison.rb
ruby benchmark/fair_comparison.rb
ruby benchmark/fair_comparison.rb

# 8. Document in SESSION_15_COMPLETE.md
```

---

## Success Criteria

### Must Achieve (Release Blockers)
- [ ] **Benchmark variance <5% for all cases**
- [ ] **10+ cases (≥71%) meet ≥1.30x threshold**
- [ ] Average speedup ≥1.35x
- [ ] Zero significant regressions (<5% loss)
- [ ] 674+ tests passing

### Quality Gates
- [ ] Variance fixes validated across 5 runs
- [ ] Baseline documented with 3-run average
- [ ] Each optimization backed by profiling data
- [ ] Changes well-tested
- [ ] Documentation comprehensive

### Nice to Have
- [ ] 12+ cases (≥86%) meet ≥1.30x
- [ ] Average speedup ≥1.40x
- [ ] Variance <3% across all cases
- [ ] Architectural insights documented

---

## Contingency Plans

### If Variance Cannot Be Fixed Below 5%
- Accept 5-10% variance as baseline
- Use median of 5 runs instead of single run
- Require larger improvement magnitude (≥1.5x) to be confident
- Focus on cases with naturally lower variance

### If Base#succ Cannot Be Optimized
- Skip it entirely (architectural issue)
- Focus on sentence parser optimization (simpler)
- Target other profiled bottlenecks

### If Sentence Optimization Doesn't Work
- Try alternative grammar structures
- Profile to verify the change had expected effect
- Revert if variance increases
- Document why it didn't work

### If Time Runs Short
**Priority Order** (must complete in order):
1. Phase 1 (Variance) - ABSOLUTELY CRITICAL
2. Phase 5 (Documentation) - CRITICAL
3. Phase 2 (Baseline) - HIGH PRIORITY
4. Phase 3-4 (Optimization) - SKIP IF NEEDED

---

## Important Notes

### What We Have
- ✅ Comprehensive profiling from Session 14
- ✅ Clear bottleneck identification
- ✅ Lesson learned about position caching
- ⚠️ Benchmark instability issue identified

### What We Need
- 🎯 Stable benchmarks (<5% variance)
- 🎯 5-7 more cases reaching ≥1.30x
- 🎯 Validated optimization approach
- 🎯 Comprehensive documentation

### Remember
**Stability before optimization** - Cannot validate improvements without reliable measurements. If Phase 1 takes the full 2 hours, that's OK. Without stable benchmarks, any optimization is guesswork.

**Fail fast** - If an approach doesn't work within 30 minutes, document why and move on. Time is limited.

**Document everything** - Failed attempts teach as much as successes. Future sessions benefit from knowing what doesn't work.

---

**Let's stabilize, optimize, and achieve 71-86% success rate!**