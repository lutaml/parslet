# Continuation Plan: Session 15 - Benchmark Stabilization & Targeted Optimization

**Session**: 15  
**Priority**: CRITICAL - Fix benchmark variance before optimization  
**Target**: Achieve ≥1.30x in 10-12/14 cases (71-86%) with <5% variance  
**Duration**: 3-4 hours  
**Prerequisites**: Session 14 profiling analysis completed

---

## Session 14 Summary

### Completed ✅
- Comprehensive profiling of calc, sentence, and json parsers
- Identified specific bottlenecks with quantified percentages
- Documented lessons learned from failed position caching attempt

### Issues ⚠️
- Benchmark variance observed at ±40-99% (Session 13 claimed <3%)
- Position caching caused severe regressions (-50% to -80%)
- Only 5/14 cases (35.7%) meet ≥1.30x threshold vs 71-86% target

### Key Findings from Profiling
1. **Calc parser**: Base#succ at 9.07% (highest bottleneck)
2. **Sentence parser**: String concatenation at ~7% (Slice#+ and String#+)
3. **JSON parser**: Well-balanced, no dominant bottleneck
4. **All parsers**: Flatten overhead 8-12%

---

## Phase 1: Verify and Fix Benchmark Stability (1-1.5 hours) 🔴 CRITICAL

### Objective
Achieve consistent <5% variance across multiple benchmark runs to enable reliable optimization validation.

### Tasks

#### 1.1: Establish Baseline Variance (30 minutes)

**Action**: Run benchmark 5 times consecutively to measure current variance

```bash
cd /Users/mulgogi/src/plurimath/parslet

# Run 5 times and capture results
for i in {1..5}; do
  echo "=== Run $i ===" | tee -a variance_test.log
  ruby benchmark/fair_comparison.rb 2>&1 | grep -A 30 "FAIR BENCHMARK SUMMARY" | tee -a variance_test.log
  sleep 10  # Cool down between runs
done

# Analyze variance
ruby -e "
  require 'json'
  runs = []
  5.times do |i|
    file = \"benchmark/results/fair_comparison.json\"
    data = JSON.parse(File.read(file)) rescue next
    runs << data['comparisons']
  end
  
  # Group by parser/file
  all_cases = runs.first.map { |c| [c['parser'], c['input_file']] }
  all_cases.each do |parser, file|
    speedups = runs.map do |run|
      case_data = run.find { |c| c['parser'] == parser && c['input_file'] == file }
      case_data['speedup'] if case_data
    end.compact
    
    next if speedups.size < 3
    avg = speedups.sum / speedups.size
    stddev = Math.sqrt(speedups.map { |s| (s - avg)**2 }.sum / speedups.size)
    variance_pct = (stddev / avg * 100).round(1)
    
    puts \"#{parser}/#{file}: #{avg.round(2)}x (±#{variance_pct}%)\"
  end
"
```

**Expected Outcome**: 
- Identify which cases have high variance (>5%)
- Determine if variance is systematic or random

#### 1.2: Investigate Variance Sources (30 minutes)

**Potential Causes**:

1. **CPU frequency scaling** (macOS power management)
   ```bash
   # Check current CPU frequency settings
   sysctl -a | grep -i freq
   pmset -g
   ```

2. **Background processes**
   ```bash
   # Check active processes during benchmark
   top -l 1 -n 10 -o cpu
   ```

3. **JIT compilation state** (YJIT)
   ```bash
   # Disable YJIT to see if it's the cause
   RUBY_YJIT_ENABLE=0 ruby benchmark/fair_comparison.rb
   ```

4. **Parser instance reuse**
   - Current code creates parser once (line 168 in fair_comparison.rb)
   - Solution: Create fresh parser for EACH iteration

**Action**: Test each hypothesis systematically

#### 1.3: Apply Variance Reduction Fixes (30 minutes)

Based on investigation, apply appropriate fixes:

**Fix A: Fresh Parser Per Iteration**

If parser state accumulation is the issue:

```ruby
# In benchmark/fair_comparison.rb, line 180-193
iterations.times do
  # Full GC before each iteration
  GC.start(full_mark: true, immediate_sweep: true)
  GC.compact if GC.respond_to?(:compact)
  GC.disable
  
  # CRITICAL: Create FRESH parser instance
  fresh_parser = parser_class.new  # <-- Add this line
  
  start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  fresh_parser.parse(input)  # <-- Use fresh_parser
  end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  
  GC.enable
  times << (end_time - start_time)
end
```

**Fix B: Increase Iteration Counts Further**

If variance is still high after Fix A:

```ruby
# In benchmark/fair_comparison.rb, line 158-164
iterations = case input_size
when 0...100 then 1000      # Tiny: 1000 (up from 500)
when 100...1000 then 500    # Small: 500 (up from 200)
when 1000...10_000 then 50  # Medium: 50 (up from 30)
when 10_000...100_000 then 20 # Large: 20 (up from 10)
else 10
end
```

**Fix C: Outlier Removal**

If occasional extreme values are causing high variance:

```ruby
# In benchmark/fair_comparison.rb, after line 193
# Remove top and bottom 10% of measurements
trimmed_size = (times.size * 0.1).to_i
sorted_times = times.sort
times = sorted_times[trimmed_size..-trimmed_size-1] if times.size > 20
```

**Fix D: Multiple Warmup Phases**

If JIT/cache warming is inconsistent:

```ruby
# In benchmark/fair_comparison.rb, line 170-172
# Extended warmup: 3 phases
3.times do
  warmup_count.times { parser.parse(input) }
  GC.start(full_mark: true, immediate_sweep: true)
  sleep 0.1
end
```

#### 1.4: Validate Fixes (30 minutes)

**Action**: Run 5 benchmarks again with fixes applied

```bash
for i in {1..5}; do
  echo "=== Run $i (after fixes) ===" | tee -a variance_test_fixed.log
  ruby benchmark/fair_comparison.rb 2>&1 | grep -A 30 "FAIR BENCHMARK SUMMARY" | tee -a variance_test_fixed.log
  sleep 10
done

# Compare before/after variance
diff variance_test.log variance_test_fixed.log
```

**Success Criteria**:
- [ ] All cases show <5% variance
- [ ] Consistent results across 5 runs
- [ ] No systematic drift in performance

---

## Phase 2: Re-establish Performance Baseline (30 minutes) 🟡 HIGH

### Objective
Document stable baseline performance after variance fixes.

### Tasks

#### 2.1: Run Official Baseline (15 minutes)

```bash
# Run 3 official baseline measurements
ruby benchmark/fair_comparison.rb > baseline_run1.txt
sleep 60
ruby benchmark/fair_comparison.rb > baseline_run2.txt
sleep 60
ruby benchmark/fair_comparison.rb > baseline_run3.txt

# Extract and compare
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
    puts \"#{status} #{parser}/#{file}: #{avg.round(2)}x (#{min.round(2)}-#{max.round(2)}, range: #{(range*100).round(0)}%)\"
  end
"
```

#### 2.2: Document Baseline (15 minutes)

Create `docs/SESSION_15_BASELINE.md`:

```markdown
# Session 15 Baseline Performance

**Date**: [Current Date]
**Variance**: <5% (verified across 5 runs)

## Performance by Case

[Include table with: parser/file, avg speedup, variance, status]

## Summary

- Cases meeting ≥1.30x: X/14 (Y%)
- Average speedup: X.XXx
- All variance <5%: [YES/NO]
```

---

## Phase 3: Targeted Optimization - Base#succ (1-1.5 hours) 🟡 HIGH

### Objective
Reduce Base#succ overhead from 9.07% (calc) without breaking functionality.

### Background

From Session 14 profiling:
- **Calc**: Base#succ at 9.07% (102,300 calls)
- **Sentence**: Base#succ at 5.66% (31,900 calls)
- **JSON**: Base#succ at 3.75% (260,600 calls)

Current implementation already optimized:
- Uses frozen constants for common patterns
- Uses `.equal?` for object identity (fastest check)
- Sequential checks for common empty patterns

**Problem**: High overhead comes from call volume, not implementation inefficiency.

### Approach: Reduce Result Wrapping

Instead of optimizing the method, reduce how often it's called.

#### 3.1: Analyze succ Call Patterns (30 minutes)

**Action**: Profile where succ is called most frequently

```bash
cd /Users/mulgogi/src/plurimath/parslet

# Profile with method-level detail
ruby -I lib -r ruby-prof benchmark/profile_case.rb calc small 2>&1 > profile_succ.txt

# Examine call graph
grep -A 20 "Parslet::Atoms::Base#succ" benchmark/results/profiles/calc_small_graph.txt
```

**Questions to answer**:
1. Which atoms call succ most frequently?
2. Are there patterns where succ wrapping is unnecessary?
3. Can we skip succ for certain atom types?

#### 3.2: Implement Selective Wrapping (30 minutes)

**Approach**: Skip succ wrapping for atoms that always produce simple values

**File**: `lib/parslet/atoms/base.rb`

```ruby
# Add method to indicate if result needs wrapping
def needs_wrapping?
  true  # Default: needs wrapping
end
```

**File**: `lib/parslet/atoms/str.rb`, `lib/parslet/atoms/re.rb`

```ruby
# Str and Re produce Parslet::Slice, which doesn't need success wrapping
def needs_wrapping?
  false
end
```

**File**: `lib/parslet/atoms/base.rb` (modify apply method)

```ruby
def apply(source, context, consume_all=false)
  old_pos = source.bytepos
  
  success, value = result = context.try_with_cache(self, source, consume_all)
  
  if success
    context.succ(source)
    
    # Check consume_all...
    if consume_all && source.chars_left>0
      # ... existing code ...
    end
    
    # OPTIMIZATION: Skip succ wrapping for simple atoms
    return result if !needs_wrapping?
    
    return result
  end
  
  source.bytepos = old_pos
  return result
end
```

Wait, this doesn't make sense. The `result` is already wrapped by try_with_cache. Let me reconsider...

Actually, looking at the code, `succ(result)` is called by the atoms themselves (in sequence.rb line 71, 76, 83, 106). The Base#apply method calls `context.succ(source)` which is different.

Let me check the actual implementation in sequence.rb... Yes, I see `return succ([:sequence, value])` on line 71.

So the optimization should be to avoid calling `succ()` when the result is already in the right format.

**Better Approach**: Return pre-constructed success tuples

```ruby
# In lib/parslet/atoms/base.rb, add more frozen constants
SUCCESS_ONE_ELEMENT = lambda { |v| [true, v].freeze }
```

Actually, this won't work either because we can't freeze arrays with dynamic content.

**Real Solution**: The overhead is architectural - we wrap every intermediate result. To reduce this, we'd need to change how parse results are represented (e.g., using a Result class instead of arrays). This is a major refactoring.

**Pragmatic Alternative**: Focus on the 7% string concatenation overhead in sentence parser instead.

---

## Phase 4: Sentence Parser String Concatenation (1 hour) 🟢 MEDIUM

### Objective
Reduce string concatenation overhead from 7% in sentence parser.

### Background

From profiling:
- **Slice#+**: 3.68% (23,800 calls)
- **String#+**: 3.38% (23,800 calls)  
- **Total**: ~7% overhead unique to sentence parser

### Investigation (30 minutes)

#### 4.1: Analyze Sentence Grammar

**File**: `benchmark/fair_comparison.rb`, lines 280-284

```ruby
class SentenceParser < Parslet::Parser
  rule(:sentence) { (match('[^。]').repeat(1) >> str("。")).as(:sentence) }
  rule(:sentences) { sentence.repeat }
  root(:sentences)
end
```

**Question**: Why does this simple grammar cause so much string concatenation?

**Analysis**:
1. `match('[^。]').repeat(1)` creates many Slice objects
2. Each character match creates a Slice
3. Slices are concatenated during result construction

#### 4.2: Profile Sentence Parsing in Detail

```bash
ruby -I lib benchmark/profile_case.rb sentence small 2>&1 > profile_sentence_detail.txt

# Look for:
# 1. Where Slice#+ is called
# 2. Call stack leading to string concatenation
# 3. Alternative approaches
```

### Optimization Options

**Option A: Batch Character Collection**

Modify sentence grammar to reduce intermediate Slices:

```ruby
class SentenceParser < Parslet::Parser
  # Collect characters in one go instead of one-by-one
  rule(:sentence_chars) { match('[^。]').repeat(1).as(:chars) }
  rule(:sentence) { (sentence_chars >> str("。")).as(:sentence) }
  rule(:sentences) { sentence.repeat }
  root(:sentences)
end
```

**Option B: Use String Result Directly**

If Slice concatenation is the issue, convert to string early:

This would require changes to how Slice#+ works - not recommended as it affects all parsers.

**Decision**: Try Option A first (grammar modification)

### Implementation (30 minutes)

1. Modify benchmark sentence parser (fair_comparison.rb)
2. Run benchmark to verify improvement
3. If successful, this validates the approach
4. Document the pattern for users

---

## Phase 5: Validation and Documentation (1 hour) 🔴 CRITICAL

### Objective
Validate all changes and document Session 15 results.

### Tasks

#### 5.1: Final Benchmark With All Changes (30 minutes)

```bash
# Run 3 final benchmarks
for i in {1..3}; do
  echo "=== Final Run $i ===" 
  ruby benchmark/fair_comparison.rb
  sleep 60
done

# Calculate final statistics
ruby -e "
  require 'json'
  data = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
  
  comparisons = data['comparisons']
  meeting_threshold = comparisons.count { |c| c['speedup'] >= 1.30 }
  total = comparisons.size
  avg_speedup = comparisons.map { |c| c['speedup'] }.sum / total
  
  puts \"=\"  * 80
  puts \"FINAL RESULTS\"
  puts \"=\" * 80
  puts \"Cases ≥1.30x: #{meeting_threshold}/#{total} (#{(meeting_threshold*100.0/total).round(1)}%)\"
  puts \"Average speedup: #{avg_speedup.round(2)}x\"
  puts \"Target: 10-12 cases (71-86%)\"
  puts
  puts meeting_threshold >= 10 ? \"✅ TARGET REACHED\" : \"⚠️ TARGET NOT REACHED\"
"
```

**Success Criteria**:
- [ ] 10-12 cases (71-86%) meet ≥1.30x threshold
- [ ] Average speedup ≥1.35x
- [ ] All variance <5%
- [ ] Zero significant regressions
- [ ] 674+ tests passing

#### 5.2: Update Documentation (30 minutes)

**Create**: `docs/SESSION_15_COMPLETE.md`

Structure:
1. Executive Summary
2. Phase 1: Benchmark Stabilization (results, fixes applied)
3. Phase 2: Baseline Establishment
4. Phase 3: Base#succ Analysis (what was learned)
5. Phase 4: Sentence Optimization (if implemented)
6. Final Results
7. Lessons Learned
8. Recommendations for Session 16

**Update**: `docs/IMPLEMENTATION_STATUS_SESSION15.md`

**Move to old-docs/**:
- `docs/SESSION_14_COMPLETE.md` → `docs/old-docs/SESSION_14_COMPLETE.md`
- `docs/SESSION_14_PROFILING_ANALYSIS.md` → `docs/old-docs/SESSION_14_PROFILING_ANALYSIS.md`
- `docs/IMPLEMENTATION_STATUS_SESSION14.md` → `docs/old-docs/IMPLEMENTATION_STATUS_SESSION14.md`

---

## Contingency Plans

### If Variance Cannot Be Fixed
- Document the variance issue in detail
- Use median of 5 runs instead of single runs
- Increase confidence interval requirements
- Focus on large magnitude improvements (≥1.5x) that are above noise

### If Base#succ Cannot Be Optimized
- Skip Phase 3
- Focus entirely on Phase 4 (sentence optimization)
- Target easier wins from profiling analysis

### If Time Runs Short
**Priority Order**:
1. Phase 1 (Benchmark stability) - MUST DO
2. Phase 5 (Validation docs) - MUST DO
3. Phase 2 (Baseline) - HIGH PRIORITY
4. Phase 4 (Sentence) - MEDIUM PRIORITY
5. Phase 3 (Base#succ) - SKIP IF NEEDED

---

## Expected Timeline

**Hour 0-1.5**: Phase 1 - Benchmark stabilization
- 0:00-0:30: Measure baseline variance
- 0:30-1:00: Investigate causes
- 1:00-1:30: Apply and validate fixes

**Hour 1.5-2**: Phase 2 - Establish baseline
- 1:30-1:45: Run official baseline (3 runs)
- 1:45-2:00: Document baseline

**Hour 2-3.5**: Phase 3 or 4 - Optimization
- If Phase 3: Analyze and attempt Base#succ optimization
- If Phase 4: Analyze and optimize sentence grammar

**Hour 3.5-4**: Phase 5 - Validation
- 3:30-4:00: Final benchmarks and documentation

---

## Files to Modify

### Benchmark Infrastructure
- `benchmark/fair_comparison.rb` - Variance reduction fixes

### Core Library (if optimizations applied)
- `lib/parslet/atoms/base.rb` - Base#succ optimization (if feasible)
- `lib/parslet/atoms/str.rb` - Potentially mark as simple value
- `lib/parslet/atoms/re.rb` - Potentially mark as simple value

### Documentation
- `docs/SESSION_15_COMPLETE.md` - Create
- `docs/IMPLEMENTATION_STATUS_SESSION15.md` - Create
- `docs/SESSION_15_BASELINE.md` - Create
- Move Session 14 docs to old-docs/

---

## Success Metrics

### Must Achieve
- [ ] Benchmark variance <5% across all cases
- [ ] 10-12 cases (71-86%) meet ≥1.30x threshold
- [ ] Average speedup ≥1.35x
- [ ] Zero significant regressions
- [ ] 674+ tests passing

### Nice to Have
- [ ] 12+ cases (≥86%) meet ≥1.30x
- [ ] Average speedup ≥1.40x
- [ ] Variance <3% across all cases
- [ ] Architectural insights for future optimization

---

## Key Principles

1. **Measure twice, optimize once**: Always verify stable measurements before optimization
2. **Small, validated steps**: One optimization at a time, full validation between
3. **Fail fast**: If an optimization doesn't work within 30 minutes, move on
4. **Document everything**: Failures teach as much as successes
5. **Maintain quality**: Never sacrifice test pass rate for performance

---

**Session 15 Status**: READY - Clear plan, priorities established, contingencies defined