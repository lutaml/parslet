# Continuation Prompt: Session 14 - Targeted Optimization for Calc/Sentence Parsers

**Session**: 14  
**Priority**: HIGH - Continue performance optimization  
**Goal**: Achieve ≥1.30x speedup in 10-12/14 cases (71-86%)  
**Duration**: 3-4 hours  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, a highly skilled software engineer tasked with achieving ≥1.30x performance improvement in 10-12 of 14 benchmark cases through targeted optimization of calc and sentence parsers. Session 13 achieved critical infrastructure (stable benchmarks, zero regressions) but only 5/14 cases (36%) meet the threshold. You must identify and fix calc/sentence-specific bottlenecks to reach the 71-86% target.

---

## Critical Context from Session 13

### What Was Achieved ✅

1. **Benchmark Stabilization**: Variance reduced from ±10-15% to <3%
2. **Zero Regressions**: 100% cases ≥1.0x (14/14)
3. **Critical Fix**: json/medium regression eliminated (0.62x → 1.50x)
4. **Per-Parser Thresholds**: Implemented based on profiling
5. **Stable Foundation**: Can now reliably measure optimization impact

### Current Challenge ⚠️

**Only 5/14 cases (35.7%) meet ≥1.30x threshold, need 10-12 (71-86%)**

**Key Insight**: Calc and sentence parsers show **consistent 1.12-1.19x** across ALL input sizes, suggesting a **parser-specific bottleneck** rather than cache/flatten issues.

### Performance Status

**Meeting ≥1.30x** (5/14):
- json/tiny: 1.59x ✅
- json/medium: 1.50x ✅
- json/small: 1.48x ✅
- erb/small: 1.42x ✅
- sentence/tiny: 1.33x ✅

**Close to Threshold** (need +5-16%):
- erb/large: 1.23x (need +5.7%)
- calc/large: 1.19x (need +9.2%)
- calc/small: 1.19x (need +9.2%)
- erb/tiny: 1.18x (need +10.2%)
- sentence/medium: 1.18x (need +10.2%)
- erb/medium: 1.15x (need +13%)
- calc/medium: 1.14x (need +14%)
- calc/tiny: 1.14x (need +14%)
- sentence/small: 1.12x (need +16%)

**Pattern**: All calc: 1.14-1.19x, All sentence: 1.12-1.33x (except tiny)

### Known Bottlenecks from Profiling

From json/medium profiling (Session 13):
1. **Cache overhead**: 17.78% (fixed via per-parser thresholds)
2. **Flatten**: 5.27%
3. **Position tracking**: 4.29% (Base#succ method)
4. **Source operations**: 4.10% (bytepos lookups)

**Hypothesis**: Calc/sentence have different bottlenecks than JSON

---

## Mission

**Profile calc/sentence parsers to identify specific bottlenecks, then implement targeted optimizations to achieve ≥1.30x in 10-12/14 benchmark cases while maintaining zero regressions.**

---

## Your Task

Follow the implementation plan in [`docs/CONTINUATION_PLAN_SESSION14.md`](CONTINUATION_PLAN_SESSION14.md) and track progress in [`docs/IMPLEMENTATION_STATUS_SESSION14.md`](IMPLEMENTATION_STATUS_SESSION14.md).

### Phase 1: Targeted Profiling (1 hour) 🔴 CRITICAL

**The Problem**: Calc/sentence consistently 1.12-1.19x, but we don't know why

**Your Task**: Profile to identify parser-specific bottlenecks

1. **Profile calc parsers** at multiple sizes:
   ```bash
   cd /Users/mulgogi/src/plurimath/parslet
   ruby -I lib benchmark/profile_case.rb calc tiny
   ruby -I lib benchmark/profile_case.rb calc small
   ruby -I lib benchmark/profile_case.rb calc medium
   ```

2. **Profile sentence parsers** at multiple sizes:
   ```bash
   ruby -I lib benchmark/profile_case.rb sentence tiny
   ruby -I lib benchmark/profile_case.rb sentence small
   ruby -I lib benchmark/profile_case.rb sentence medium
   ```

3. **Profile JSON for baseline** (working well at 1.48-1.59x):
   ```bash
   ruby -I lib benchmark/profile_case.rb json small
   ```

4. **Analyze differences**:
   - Look for hot methods unique to calc/sentence
   - Compare call counts (calc/sentence vs json)
   - Identify patterns:
     - Calc: Likely sequence/choice overhead (complex grammar)
     - Sentence: Likely repetition overhead (repetitive grammar)

5. **Document findings** in `docs/SESSION_14_PROFILING_ANALYSIS.md`:
   - Top 20 methods by self-time for each
   - Unique bottlenecks compared to JSON
   - Prioritized optimization targets

**Expected Outcome**: Clear identification of bottlenecks

---

### Phase 2: Position Tracking Optimization (1 hour) 🟡 HIGH PRIORITY

**The Problem**: Position#initialize 1.57%, Base#succ 4.29% (~6% total overhead)

**Your Task**: Reduce position tracking overhead to <3%

1. **Implement position caching** in [`lib/parslet/source.rb`](../lib/parslet/source.rb):
   ```ruby
   def initialize(str)
     # ... existing code ...
     @position_cache = Array.new(1000)  # Cache first 1000 positions
   end
   
   def pos
     bp = bytepos
     if bp < 1000
       @position_cache[bp] ||= Position.new(self, bp)
     else
       Position.new(self, bp)
     end
   end
   ```

2. **Test thoroughly**:
   ```bash
   bundle exec rspec
   ruby benchmark/fair_comparison.rb
   ```

3. **Verify improvement**:
   - Check position overhead in profiling
   - Ensure all cases improve or maintain
   - No test failures

**Expected Impact**: +2-4% across all cases, 2-3 more cases reach ≥1.30x

---

### Phase 3: Source Operation Optimization (1 hour) 🟡 HIGH PRIORITY

**The Problem**: Source#bytepos 4.10%, StringScanner#pos 2.22% (~6% total)

**Your Task**: Reduce source operation overhead to <3%

1. **Implement local bytepos caching** in hot methods:
   
   In [`lib/parslet/atoms/sequence.rb`](../lib/parslet/atoms/sequence.rb):
   ```ruby
   def try(source, context, consume_all)
     start_pos = source.bytepos  # Cache once
     # ... use start_pos instead of source.bytepos ...
   end
   ```
   
   In [`lib/parslet/atoms/alternative.rb`](../lib/parslet/atoms/alternative.rb):
   ```ruby
   def try(source, context, consume_all)
     start_pos = source.bytepos  # Cache once
     alternatives.each do |alt|
       # Use start_pos for position restoration
     end
   end
   ```

2. **Test and benchmark**:
   ```bash
   bundle exec rspec
   ruby benchmark/fair_comparison.rb
   ```

**Expected Impact**: +2-3% across all cases, 1-2 more cases reach ≥1.30x

---

### Phase 4: Parser-Specific Optimizations (1-1.5 hours) 🟢 MEDIUM PRIORITY

**The Problem**: Calc/sentence have unique bottlenecks (identified in Phase 1)

**Your Task**: Implement targeted optimization based on profiling

**Three possible scenarios**:

#### Scenario A: Calc shows sequence/choice overhead

**If profiling shows** high Alternative#try or Sequence#try in calc:

1. **Optimize sequence dispatch** in [`lib/parslet/atoms/sequence.rb`](../lib/parslet/atoms/sequence.rb):
   ```ruby
   # Fast path for 2-element sequences (very common)
   if parslets.size == 2
     return try_two_element_sequence(parslets[0], parslets[1], source, context, consume_all)
   end
   ```

2. **Optimize choice dispatch** in [`lib/parslet/atoms/alternative.rb`](../lib/parslet/atoms/alternative.rb):
   - Cache successful alternative per position
   - Skip failed alternatives on repeated access

3. **Test with calc parsers**

#### Scenario B: Sentence shows repetition overhead

**If profiling shows** high Repetition#try or flatten_repetition in sentence:

1. **Optimize repetition** in [`lib/parslet/atoms/repetition.rb`](../lib/parslet/atoms/repetition.rb):
   ```ruby
   # Batch results instead of appending one by one
   batch = []
   while condition
     batch << result
     # Concat all at once instead of result += [item]
   end
   results.concat(batch)
   ```

2. **Lazy flattening**: Mark repetition results as needs-flattening, defer until needed

3. **Test with sentence parsers**

#### Scenario C: Both show same bottleneck

**If profiling shows** common hot method across both:

1. Identify the common method
2. Optimize that specific code path
3. Test with both parser types

**Expected Impact**: +5-10% for calc/sentence parsers

---

### Phase 5: Validation & Iteration (30 minutes) 🔴 CRITICAL

**Your Task**: Verify we've reached the 71-86% target

1. **Run final benchmarks** (3 times for reliability):
   ```bash
   ruby benchmark/fair_comparison.rb > results1.txt
   ruby benchmark/fair_comparison.rb > results2.txt
   ruby benchmark/fair_comparison.rb > results3.txt
   ```

2. **Calculate statistics**:
   ```ruby
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

4. **If not meeting criteria**, iterate:
   - Profile remaining slow cases
   - Identify next bottleneck
   - One final targeted optimization
   - Re-validate

5. **Document results** in `docs/SESSION_14_COMPLETE.md`

---

## Quick Start Commands

```bash
# 1. Profile calc/sentence to identify bottlenecks (Phase 1)
cd /Users/mulgogi/src/plurimath/parslet
ruby -I lib benchmark/profile_case.rb calc small 2>&1 | tail -100
ruby -I lib benchmark/profile_case.rb sentence small 2>&1 | tail -100
ruby -I lib benchmark/profile_case.rb json small 2>&1 | tail -100

# 2. Compare hotspots
# Look for methods that appear in calc/sentence but not json
# Document findings in docs/SESSION_14_PROFILING_ANALYSIS.md

# 3. Implement position caching (Phase 2)
# Edit lib/parslet/source.rb

# 4. Test
bundle exec rspec

# 5. Benchmark
ruby benchmark/fair_comparison.rb

# 6. Implement source caching (Phase 3)
# Edit lib/parslet/atoms/sequence.rb, alternative.rb

# 7. Test and benchmark again
bundle exec rspec
ruby benchmark/fair_comparison.rb

# 8. Implement parser-specific optimization (Phase 4)
# Based on profiling findings

# 9. Final validation (Phase 5)
ruby benchmark/fair_comparison.rb  # Run 3 times
ruby -e "require 'json'; ..."  # Calculate statistics

# 10. Document in SESSION_14_COMPLETE.md
```

---

## Success Criteria

### Must Achieve (Release Blockers)
- [ ] **10+ cases (≥71%) meet ≥1.30x threshold**
- [ ] Average speedup ≥1.35x
- [ ] Zero significant regressions (<5% loss)
- [ ] 674+ tests passing
- [ ] All variance <3%

### Quality Gates
- [ ] Each optimization backed by profiling data
- [ ] Changes well-tested
- [ ] Documentation comprehensive
- [ ] Code remains maintainable
- [ ] Clear reasoning for each change

### Nice to Have
- [ ] 12+ cases (≥86%) meet ≥1.30x
- [ ] Average speedup ≥1.40x
- [ ] All calc cases ≥1.25x
- [ ] All sentence cases ≥1.25x
- [ ] 675/675 tests passing

---

## Expected Timeline

**Hour 0-1**: Phase 1 (Profiling)
- Profile calc at tiny/small/medium
- Profile sentence at tiny/small/medium
- Profile json/small baseline
- Analyze and document bottlenecks

**Hour 1-2**: Phase 2 (Position)
- Implement position caching
- Test and validate
- Benchmark improvement

**Hour 2-3**: Phase 3 (Source)
- Implement local bytepos caching
- Test and validate
- Benchmark improvement

**Hour 3-3.5**: Phase 4 (Parser-Specific)
- Implement targeted optimization
- Test and validate
- Benchmark improvement

**Hour 3.5-4**: Phase 5 (Validation)
- Run 3 benchmark passes
- Calculate statistics
- Document results

---

## Contingency Plans

### If Profiling Shows Architectural Issue
- Focus on erb cases instead (3 close cases: 1.15-1.23x)
- Get erb/large, erb/tiny, erb/medium to ≥1.30x
- With Session 13's 5 cases + 3 erb = 8 cases
- Need 2 more: target calc/large (1.19x) and sentence/medium (1.18x)
- **Result**: Still reach 10/14 (71%) target

### If Position Optimization Breaks Tests
- Revert position caching
- Keep source operation caching only
- Focus more on Phase 4 (parser-specific)

### If Time Runs Short
**Priority Order**:
1. Phase 1 (Profiling) - MUST DO
2. Phase 5 (Validation) - MUST DO
3. Phase 2 (Position) - HIGH PRIORITY
4. Phase 3 (Source) - HIGH PRIORITY
5. Phase 4 (Parser-specific) - SKIP IF NEEDED

### If Tests Fail
- Revert problematic changes immediately
- Analyze failure cause
- Fix logic or update tests if behavior is correct
- Never ship with failing tests

---

## Important Notes

### What We Have
- ✅ Stable benchmarks (variance <3%)
- ✅ Zero regressions (100% cases ≥1.0x)
- ✅ Per-parser cache thresholds working
- ✅ 5 cases meeting ≥1.30x (36%)

### What We Need
- 🎯 Identify calc/sentence bottlenecks
- 🎯 Optimize position tracking
- 🎯 Optimize source operations
- 🎯 10-12 cases meeting ≥1.30x (71-86%)

### Remember
**Profile first, optimize second** - Don't guess at the bottleneck. The profiling in Phase 1 is critical to success. Spend the full hour understanding what's different about calc/sentence compared to JSON.

---

**Let's profile, optimize, and achieve 71-86% success rate!**