# Continuation Plan: Session 14 - Targeted Optimization for Calc/Sentence Parsers

**Session**: 14  
**Goal**: Achieve ≥1.30x in 10-12/14 cases (71-86%) through targeted optimization  
**Priority**: HIGH - Continue performance optimization path  
**Estimated Duration**: 3-4 hours

---

## Current Status from Session 13

### Achievement Summary
- ✅ Benchmark stabilization: Variance <3% for all cases
- ✅ Zero regressions: 100% cases ≥1.0x
- ✅ Critical fix: json/medium 0.62x → 1.50x
- ⚠️ Only 5/14 cases (35.7%) meet ≥1.30x threshold
- ⚠️ Calc/Sentence parsers consistently 1.12-1.19x

### Performance Status

**Cases Meeting ≥1.30x** (5/14 = 35.7%):
- json/tiny: 1.59x ✅
- json/medium: 1.50x ✅
- json/small: 1.48x ✅
- erb/small: 1.42x ✅
- sentence/tiny: 1.33x ✅

**Cases Close to Threshold** (need +5-16%):
- erb/large: 1.23x (need +5.7%)
- calc/large: 1.19x (need +9.2%)
- calc/small: 1.19x (need +9.2%)
- erb/tiny: 1.18x (need +10.2%)
- sentence/medium: 1.18x (need +10.2%)
- erb/medium: 1.15x (need +13%)
- calc/medium: 1.14x (need +14%)
- calc/tiny: 1.14x (need +14%)
- sentence/small: 1.12x (need +16%)

### Key Insight
Calc and Sentence parsers show **consistent 1.12-1.19x** across ALL input sizes, suggesting a **parser-specific bottleneck** rather than cache/flatten issues.

---

## Session 14 Objectives

**Primary Goals**:
1. Profile calc/sentence parsers to identify specific bottlenecks
2. Implement targeted optimizations for identified bottlenecks
3. Achieve ≥1.30x in 10-12/14 cases (71-86%)
4. Maintain zero regressions and stable variance

**Secondary Goals**:
5. Optimize position tracking (4.29% overhead)
6. Optimize source operations (4.10% overhead)
7. Document all optimizations

---

## Session 14 Phases

### Phase 1: Targeted Profiling (1 hour)

**Objective**: Identify calc/sentence-specific bottlenecks

**Tasks**:

1. **Profile calc at multiple sizes**:
   ```bash
   ruby -I lib benchmark/profile_case.rb calc tiny
   ruby -I lib benchmark/profile_case.rb calc small
   ruby -I lib benchmark/profile_case.rb calc medium
   ```

2. **Profile sentence at multiple sizes**:
   ```bash
   ruby -I lib benchmark/profile_case.rb sentence tiny
   ruby -I lib benchmark/profile_case.rb sentence small
   ruby -I lib benchmark/profile_case.rb sentence medium
   ```

3. **Compare to JSON (working well)**:
   ```bash
   ruby -I lib benchmark/profile_case.rb json small
   ```

4. **Analyze differences**:
   - Method distribution
   - Call counts
   - Hot spots unique to calc/sentence
   - Document in `docs/SESSION_14_PROFILING_ANALYSIS.md`

**Expected Findings**:
- Calc: Likely sequence/choice overhead (complex grammar)
- Sentence: Likely repetition overhead (simple but repetitive)
- Compare to JSON: Different pattern despite similar performance

**Deliverable**: Clear identification of calc/sentence bottlenecks

---

### Phase 2: Position Tracking Optimization (1 hour)

**Objective**: Reduce position tracking overhead from 4.29% to <2%

**Profiling shows**: `Parslet::Atoms::Base#succ` is 4.29% of execution time

**Approach**: Reduce position allocation and lookups

**Tasks**:

1. **Analyze current position usage** in [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb):
   ```ruby
   # Current: Creates success arrays frequently
   def succ(result)
     return SUCCESS_NIL if result.nil?
     [true, result]
   end
   ```

2. **Check position creation** in [`lib/parslet/source.rb`](../lib/parslet/source.rb):
   - How often is `Parslet::Position` created?
   - Can we cache positions at byte boundaries?
   - Can we use integers instead of Position objects for hot paths?

3. **Implement position caching**:
   ```ruby
   # Potential optimization in Source
   @position_cache = Array.new(1000)  # Cache first 1000 positions
   
   def pos
     bytepos_val = bytepos
     if bytepos_val < 1000
       @position_cache[bytepos_val] ||= Position.new(self, bytepos_val)
     else
       Position.new(self, bytepos_val)
     end
   end
   ```

4. **Benchmark impact**:
   - Run suite before/after
   - Check calc/sentence improvement
   - Verify no regressions

**Expected Impact**: +2-4% improvement across all cases

**Deliverable**: Position tracking optimized

---

### Phase 3: Source Operation Optimization (1 hour)

**Objective**: Reduce source operation overhead from 4.10% to <2%

**Profiling shows**: `Parslet::Source#bytepos` called 9.4M times (4.10% overhead)

**Approach**: Inline caching and reduced method calls

**Tasks**:

1. **Analyze bytepos usage patterns**:
   - Where is bytepos called most?
   - Can we cache it at loop level?
   - Can we use local variables instead?

2. **Implement inline caching in hot loops**:
   ```ruby
   # In try methods, cache bytepos locally
   def try(source, context, consume_all)
     beg_pos = source.bytepos  # Cache once
     # ... use beg_pos instead of source.bytepos ...
   end
   ```

3. **Reduce Position#initialize calls** (1.57% overhead):
   - Positions created 2.65M times
   - Can we reuse positions?
   - Can we delay creation?

4. **Optimize common patterns** in [`lib/parslet/atoms/sequence.rb`](../lib/parslet/atoms/sequence.rb), [`lib/parslet/atoms/alternative.rb`](../lib/parslet/atoms/alternative.rb):
   - Cache position at start
   - Reuse across alternatives
   - Restore only on failure

**Expected Impact**: +2-3% improvement across all cases

**Deliverable**: Source operations optimized

---

### Phase 4: Parser-Specific Optimizations (1-1.5 hours)

**Objective**: Target calc/sentence-specific bottlenecks

**Based on profiling findings**, implement:

#### Option A: If calc shows sequence/choice overhead

**Problem**: Complex grammar with many sequences/alternatives

**Solution**: Optimize sequence/choice dispatch

1. **Fast-path for 2-element sequences**:
   ```ruby
   def try_sequence_of_two(a, b, source, context)
     # Optimized path without array allocation
   end
   ```

2. **Choice memoization**:
   - Cache which alternative succeeded at position
   - Skip failed alternatives on repeated access

3. **Benchmark improvement on calc cases**

#### Option B: If sentence shows repetition overhead

**Problem**: Simple but highly repetitive grammar

**Solution**: Optimize repetition handling

1. **Batch repetition results**:
   ```ruby
   # Instead of: result << item; result << item; ...
   # Use: results.concat(batch)
   ```

2. **Lazy repetition flattening**:
   - Don't flatten until needed
   - Mark as needs-flattening

3. **Benchmark improvement on sentence cases**

#### Option C: If both show similar issue

**Problem**: Common bottleneck across both

**Solution**: Optimize the shared code path

1. **Identify common hot method**
2. **Implement targeted optimization**
3. **Benchmark both parser types**

**Expected Impact**: +5-10% for calc/sentence parsers

**Deliverable**: Parser-specific optimizations implemented

---

### Phase 5: Validation & Iteration (30 minutes)

**Objective**: Verify we've reached 71-86% threshold

**Tasks**:

1. **Run complete benchmark suite** (3 runs):
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
     data = JSON.parse(File.read('benchmark/results/fair_comparison.json'))
     met = data['comparisons'].count { |c| c['speedup'] >= 1.30 }
     total = data['comparisons'].size
     avg = data['comparisons'].map { |c| c['speedup'] }.sum / total
     puts \"Cases ≥1.30x: #{met}/#{total} (#{(met*100.0/total).round(0)}%)\"
     puts \"Average speedup: #{avg.round(2)}x\"
   "
   ```

3. **Check success criteria**:
   - [ ] 10+ cases (≥71%) meet ≥1.30x?
   - [ ] Average speedup ≥1.35x?
   - [ ] All variance <3%?
   - [ ] Zero significant regressions?
   - [ ] 674+ tests passing?

4. **If not meeting criteria**:
   - Identify remaining gaps
   - Profile slowest cases
   - One more targeted optimization
   - Re-validate

5. **Document results** in `docs/SESSION_14_COMPLETE.md`

**Deliverable**: Validated performance improvements

---

## Expected Outcomes

### Optimistic (Best Case)
- 12/14 cases (86%) meet ≥1.30x
- Average speedup: ≥1.40x
- All calc/sentence cases >1.25x
- Ready for release

### Realistic (Expected Case)
- 10-11/14 cases (71-79%) meet ≥1.30x
- Average speedup: ≥1.35x
- Calc/sentence improved but some still <1.30x
- Need minor Session 15 polish

### Pessimistic (Worst Case)
- 8-9/14 cases (57-64%) meet ≥1.30x
- Average speedup: 1.30-1.33x
- Calc/sentence bottleneck harder than expected
- Need Session 15 for different approach

---

## Risk Assessment

### High Risk
1. **Calc/sentence bottleneck is architectural** (⚠️)
   - May not be fixable with micro-optimizations
   - Mitigation: Profile thoroughly before implementing
   - Fallback: Accept 8-10 cases, document limitations

### Medium Risk
2. **Position/source optimizations break tests** (⚠️)
   - Heavy caching may cause subtle bugs
   - Mitigation: Comprehensive testing
   - Fallback: Revert specific changes

3. **Optimization interactions** (⚠️)
   - Multiple optimizations may conflict
   - Mitigation: Implement incrementally, benchmark each
   - Fallback: Binary search to find conflict

### Low Risk
4. **Time overrun** (✓)
   - 3-4 hour estimate may be tight
   - Mitigation: Prioritize highest-impact changes
   - Fallback: Complete in Session 15

---

## Deliverables

### Code Changes
1. [`lib/parslet/source.rb`](../lib/parslet/source.rb) - Position caching
2. [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb) - Position optimization
3. [`lib/parslet/atoms/sequence.rb`](../lib/parslet/atoms/sequence.rb) - Sequence optimization (if needed)
4. [`lib/parslet/atoms/repetition.rb`](../lib/parslet/atoms/repetition.rb) - Repetition optimization (if needed)
5. Parser-specific optimizations based on profiling

### Documentation
1. `docs/SESSION_14_PROFILING_ANALYSIS.md` - Calc/sentence profiling
2. `docs/SESSION_14_OPTIMIZATION_DETAILS.md` - Implementation details
3. `docs/SESSION_14_COMPLETE.md` - Final results
4. Update `docs/_pages/optimizations.adoc` - Document new optimizations

### Testing
1. Test suite validation (≥674/675 passing)
2. Benchmark validation (3 runs, median speedup)
3. Regression testing

---

## Success Metrics

**Must Achieve**:
- [ ] 10+ cases (≥71%) meet ≥1.30x threshold
- [ ] Average speedup ≥1.35x
- [ ] Zero significant regressions (<5% loss)
- [ ] 674+ tests passing
- [ ] All variance <3%

**Nice to Have**:
- [ ] 12+ cases (≥86%) meet ≥1.30x
- [ ] Average speedup ≥1.40x
- [ ] All calc/sentence cases ≥1.25x
- [ ] 675/675 tests passing
- [ ] Clear path to 100% in future

---

## Contingency Plans

### If Calc/Sentence Bottleneck is Hard to Fix
1. Focus on other 4 close cases (erb/large, erb/tiny, erb/medium, calc/large)
2. Get these to ≥1.30x with position/source optimizations
3. Accept calc/sentence at 1.15-1.20x for now
4. Document as future work

### If Position Optimization Breaks Tests
1. Revert position caching
2. Focus on source operation caching only
3. Implement simpler optimizations

### If Time Runs Short
**Priority Order**:
1. Phase 1 (Profiling) - MUST DO
2. Phase 5 (Validation) - MUST DO
3. Phase 2 (Position) - HIGH PRIORITY
4. Phase 3 (Source) - HIGH PRIORITY
5. Phase 4 (Parser-specific) - SKIP IF NEEDED

### If Tests Fail
- Revert problematic changes immediately
- Analyze test failure cause
- Fix logic or update tests if behavior is correct
- Never ship with failing tests

---

## Key Principles

1. **Profile before optimizing** - Don't guess, measure
2. **Incremental changes** - One optimization at a time
3. **Continuous validation** - Test after each change
4. **Document thoroughly** - Future sessions benefit
5. **Quality over quantity** - 10 solid cases better than 12 unstable

---

## Timeline

**Hour 0-1**: Phase 1 (Profiling)
- Profile calc/sentence at multiple sizes
- Compare to JSON
- Identify bottlenecks
- Document findings

**Hour 1-2**: Phase 2 (Position Optimization)
- Implement position caching
- Test and validate
- Benchmark improvement

**Hour 2-3**: Phase 3 (Source Optimization)
- Implement source operation caching
- Test and validate
- Benchmark improvement

**Hour 3-4**: Phase 4 (Parser-Specific)
- Implement targeted optimizations
- Test and validate
- Run full benchmarks

**Hour 4**: Phase 5 (Validation)
- Final benchmark runs (3x)
- Verify success criteria
- Document results

---

**Session 14 ready to start. Focus: Profile → Position → Source → Parser-Specific → Validate**