# Continuation Plan: Session 13 - Stabilization & Per-Parser Optimization

**Session**: 13  
**Goal**: Stabilize benchmarks and optimize per-parser to achieve ≥1.30x in 10-12/14 cases  
**Priority**: HIGH - Continue performance optimization path  
**Estimated Duration**: 4-6 hours

---

## Current Status from Session 12

### Achievement Summary
- ✅ Identified root cause: Cache overhead (15-20% for small inputs)
- ✅ Implemented adaptive caching (threshold: 1000 bytes)
- ✅ Improved 4-6 cases significantly
- ⚠️ High variance in micro-benchmarks (±5-15%)
- ⚠️ Only 4/14 cases (29%) meet ≥1.30x threshold

### Performance Status

**Cases Meeting ≥1.30x** (4/14 = 29%):
- json/small: 1.45x ✅
- json/tiny: 1.36x ✅
- erb/small: 1.36x ✅
- erb/tiny: 1.30x ✅

**Cases Below 1.30x** (10/14 = 71%):
- sentence/tiny: 0.85x (high variance: ±10.3%)
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

## Session 13 Objectives

**Primary Goals**:
1. Stabilize micro-benchmarks (reduce variance to <3%)
2. Implement per-parser cache threshold tuning
3. Optimize flatten operations for remaining bottleneck
4. Achieve ≥1.30x in 10-12/14 cases (71-86%)

**Secondary Goals**:
5. Document all optimizations in official docs
6. Maintain zero regressions
7. Keep test suite passing (674/675 minimum)

---

## Session 13 Phases

### Phase 1: Benchmark Stabilization (1.5 hours)

**Objective**: Reduce micro-benchmark variance from ±10% to <3%

**Tasks**:

1. **Improve iteration counts**
   - Increase iterations for tiny inputs: 50 → 500
   - Increase iterations for small inputs: 50 → 200
   - Keep medium/large as-is (10-30 iterations)

2. **Better GC control**
   ```ruby
   # Before each iteration
   GC.start(full_mark: true, immediate_sweep: true)
   GC.compact if GC.respond_to?(:compact)
   GC.disable
   
   # Measure
   
   GC.enable
   ```

3. **Multiple runs with statistical analysis**
   - Run benchmark 3 times
   - Use median speedup
   - Report confidence interval
   - Flag results with high variance

4. **Update [`benchmark/fair_comparison.rb`](../benchmark/fair_comparison.rb)**
   - Implement improved methodology
   - Add variance thresholds
   - Report measurement quality

**Deliverable**: Stable benchmarks with <3% variance

**Expected Impact**: Reliable performance measurement

---

### Phase 2: Per-Parser Cache Threshold Tuning (2 hours)

**Objective**: Optimize cache threshold for each parser type

**Approach**: Profile-guided per-parser tuning

**Tasks**:

1. **Profile each parser at various input sizes**
   - Profile calc at: 17, 273, 3279, 51587 bytes
   - Profile json at: 37, 759, 5207 bytes
   - Profile erb at: 25, 308, 6284, 62840 bytes
   - Profile sentence at: 30, 774, 38700 bytes

2. **Analyze cache benefit vs overhead**
   - Measure cache hit rate
   - Measure cache operation time
   - Calculate benefit threshold per parser
   - Document findings

3. **Implement parser-specific thresholds**
   
   Modify [`lib/parslet/atoms/context.rb`](../lib/parslet/atoms/context.rb):
   ```ruby
   # Parser-specific cache thresholds based on profiling
   PARSER_CACHE_THRESHOLDS = {
     # JSON: High recursion/repetition, benefits from cache earlier
     'JsonParser' => 500,
     
     # ERB: Moderate repetition, benefits from cache earlier  
     'ErbParser' => 800,
     
     # Calc: Lower repetition, needs larger input for cache benefit
     'CalcParser' => 2000,
     
     # Sentence: Simple linear grammar, minimal cache benefit
     'SentenceParser' => 5000,
     
     # Default for unknown parsers
     :default => 1000
   }
   
   def initialize(reporter=..., parser_class: nil)
     # Determine threshold based on parser class
     threshold = if parser_class
       parser_name = parser_class.name.split('::').last
       PARSER_CACHE_THRESHOLDS[parser_name] || 
         PARSER_CACHE_THRESHOLDS[:default]
     else
       PARSER_CACHE_THRESHOLDS[:default]
     end
     
     @adaptive_cache_threshold = threshold
     # ... rest of initialization ...
   end
   ```

4. **Update parsers to pass class info**
   - Modify parser base class if needed
   - Ensure context receives parser class
   - Backward compatible implementation

**Deliverable**: Per-parser optimized cache thresholds

**Expected Impact**: 
- JSON parsers: Maintain current performance
- Calc parsers: +5-10% improvement
- Sentence parsers: +10-15% improvement
- ERB parsers: Maintain or +5% improvement

---

### Phase 3: Flatten Optimization (1.5 hours)

**Objective**: Reduce flatten overhead from 6-7% to 3-4%

**Profiling shows**: Flatten is still 6-7% of execution time

**Approach**: Add "flat by construction" optimization

**Tasks**:

1. **Add flat? method to atoms**
   
   In [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb):
   ```ruby
   # Returns true if this atom produces flat results by construction
   # (no array/hash nesting that needs flattening)
   def flat?
     false  # Default: assume needs flattening
   end
   ```

2. **Mark flat atoms**
   
   Identify atoms that produce flat results:
   - `Str` - always produces string → flat
   - `Re` - always produces string → flat
   - Single-element `Sequence` - if child is flat → flat
   - `Named` - inherits child's flatness
   - `Repetition` of flat atom → potentially flat

3. **Skip flatten for flat atoms**
   
   In [`lib/parslet/atoms/can_flatten.rb`](../lib/parslet/atoms/can_flatten.rb):
   ```ruby
   def flatten(value, named=false)
     # Skip flattening if already flat
     return value unless value.is_a?(Array)
     
     # Check if this is from a flat atom
     if value.size == 2 && value[0] == :flat
       return value[1]  # Already flat, return  directly
     end
     
     # ... existing flatten logic ...
   end
   ```

4. **Update atoms to use flat marker**
   ```ruby
   # In Str#try
   def try(source, context, consume_all)
     # ... matching logic ...
     [:flat, slice]  # Mark as flat
   end
   ```

**Deliverable**: Reduced flatten overhead

**Expected Impact**: +3-5% improvement across all cases

---

### Phase 4: Validation & Iteration (1 hour)

**Objective**: Verify improvements and iterate if needed

**Tasks**:

1. **Run stabilized benchmarks**
   - Execute 3 complete runs
   - Calculate median speedup per case
   - Verify variance <3%

2. **Check thresholds**
   - Count cases ≥1.30x
   - Target: 10-12 cases (71-86%)
   - Identify remaining gaps

3. **Test suite validation**
   - Run full test suite: `bundle exec rspec`
   - Target: 674/675 minimum (maintain current)
   - Fix any new failures

4. **Regression check**
   - Verify no case drops below 1.0x
   - Verify no case loses >5% performance
   - Document any trade-offs

5. **Iterate if needed**
   - If <10 cases meet threshold, profile again
   - Identify next bottleneck
   - Apply targeted optimization
   - Repeat validation

**Deliverable**: Validated performance improvements

**Success Criteria**:
- 10-12/14 cases (71-86%) ≥1.30x
- Average speedup ≥1.35x
- Zero significant regressions
- 674/675+ tests passing
- Variance <3% for all cases

---

## Expected Outcomes

### Optimistic (Best Case)
- 12/14 cases (86%) meet ≥1.30x
- Average speedup: 1.40x
- All improvements stable (<3% variance)
- Clear path to 100% in Session 14

### Realistic (Expected Case)
- 10-11/14 cases (71-79%) meet ≥1.30x
- Average speedup: 1.35-1.38x
- Most cases stable, some still variable
- Need Session 14 for remaining cases

### Pessimistic (Worst Case)
- 8-9/14 cases (57-64%) meet ≥1.30x
- Average speedup: 1.30-1.33x
- Variance still >5% for some cases
- Need Session 14-15 for completion

---

## Risk Assessment

### High Risk
1. **Benchmark variance remains high** (⚠️)
   - May not achieve stable measurements
   - Mitigation: Increase iterations further, improve GC control
   - Fallback: Accept higher variance, focus on median improvements

2. **Per-parser tuning doesn't help enough** (⚠️)
   - Fixed thresholds may still not be optimal
   - Mitigation: Profile more thoroughly, consider dynamic thresholds
   - Fallback: Focus on other optimization avenues

### Medium Risk
3. **Flatten optimization breaks tests** (⚠️)
   - Marking atoms as flat may be incorrect
   - Mitigation: Careful testing, conservative marking
   - Fallback: Revert flatten optimization, focus on other areas

4. **Time overrun** (⚠️)
   - May not complete all phases in 6 hours
   - Mitigation: Prioritize high-impact items
   - Fallback: Complete partially, continue in Session 14

### Low Risk
5. **Test regressions** (✓)
   - Previous work had minimal test impact
   - Mitigation: Run tests continuously
   - Fallback: Fix or revert specific changes

---

## Deliverables

### Code Changes
1. [`benchmark/fair_comparison.rb`](../benchmark/fair_comparison.rb) - Stabilized benchmarking
2. [`lib/parslet/atoms/context.rb`](../lib/parslet/atoms/context.rb) - Per-parser cache thresholds
3. [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb) - flat? method
4. [`lib/parslet/atoms/can_flatten.rb`](../lib/parslet/atoms/can_flatten.rb) - Skip flatten for flat atoms
5. Individual atom files - Mark flat atoms

### Documentation
1. `docs/SESSION_13_PROFILING_ANALYSIS.md` - Per-parser profiling results
2. `docs/SESSION_13_OPTIMIZATION_DETAILS.md` - Implementation details
3. `docs/SESSION_13_COMPLETE.md` - Final results
4. Update `docs/_pages/optimizations.adoc` - Document new optimizations

### Testing
1. Updated benchmarks with stable methodology
2. Test suite validation (≥674/675 passing)
3. Regression testing for all cases

---

## Timeline

**Hour 1-1.5**: Phase 1 (Benchmark Stabilization)
- Improve iteration counts
- Better GC control
- Update fair_comparison.rb
- Verify variance reduction

**Hour 2-4**: Phase 2 (Per-Parser Tuning)
- Profile each parser at multiple sizes
- Analyze cache benefit
- Implement parser-specific thresholds
- Test and validate

**Hour 4.5-6**: Phase 3 (Flatten Optimization)
- Add flat? method
- Mark flat atoms
- Skip flatten optimization
- Test and validate

**Hour 6**: Phase 4 (Validation)
- Run stabilized benchmarks (3 runs)
- Check thresholds
- Test suite validation
- Document results

---

## Success Metrics

**Must Achieve**:
- [ ] 10+ cases (≥71%) meet ≥1.30x threshold
- [ ] Benchmark variance <3% for all cases
- [ ] Zero significant regressions (<5% loss)
- [ ] 674+ tests passing
- [ ] Average speedup ≥1.35x

**Nice to Have**:
- [ ] 12+ cases (≥86%) meet ≥1.30x threshold
- [ ] Average speedup ≥1.40x
- [ ] All cases with <2% variance
- [ ] 675/675 tests passing (fix remaining failure)
- [ ] Clear path to 100% in Session 14

---

## Contingency Plans

### If Variance Still High (>5%)
1. Longer warmup (100 iterations instead of 10)
2. Process isolation (run each benchmark in separate process)
3. More statistical runs (5 instead of 3)
4. Focus on median over mean
5. Accept some variance, document limitations

### If Per-Parser Tuning Insufficient
1. Try dynamic threshold based on runtime cache hit rate
2. Implement per-rule caching decisions
3. Profile and optimize next bottleneck (flatten, dispatch)
4. Consider disabling cache for specific parser types

### If Flatten Optimization Too Risky
1. Skip Phase 3
2. Focus on stabilization and per-parser tuning only
3. Plan flatten optimization for Session 14 with more time
4. Document as future work

### If Time Runs Short
**Priority Order**:
1. Phase 1 (Stabilization) - MUST DO
2. Phase 2 (Per-Parser) - HIGH PRIORITY
3. Phase 4 (Validation) - HIGH PRIORITY
4. Phase 3 (Flatten) - NICE TO HAVE

---

## Key Principles

1. **Measure carefully** - Variance reduction is critical for valid results
2. **Profile before optimizing** - Per-parser tuning needs data
3. **Test continuously** - Catch regressions early
4. **Document thoroughly** - Future sessions benefit
5. **Be pragmatic** - 71% success better than 0% perfection

---

**Session 13 ready to start. Focus: Stabilization → Per-Parser → Flatten → Validate**