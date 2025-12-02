# Continuation Plan: Session 9 - Eliminate ALL Performance Regressions

**Session**: 9 (CRITICAL - Release Blocking)
**Priority**: CRITICAL (Zero tolerance for regressions)
**Duration**: 6-8 hours
**Previous Sessions**: 1-8 ($16+ spent)
**Status**: Investigation & Fix Required

---

## Problem Statement

**RELEASE BLOCKER**: 5 out of 14 test cases show performance regressions.

We **CANNOT** ship plurimath-parslet v3.1.0 with ANY case slower than vanilla parslet 2.0.

---

## Current State

### Regression Cases (MUST FIX)
1. **calc/large**: 0.68x (32% slower) - WORST CASE
2. **sentence/medium**: 0.86x (14% slower)
3. **sentence/tiny**: 0.87x (13% slower)
4. **sentence/small**: 0.90x (10% slower)  
5. **calc/small**: 0.91x (9% slower)

### Working Cases (9/14)
- json/small: 4.32x ⭐
- json/medium: 1.33x
- json/tiny: 1.23x
- calc/tiny: 1.23x
- erb/tiny: 1.20x
- erb/large: 1.19x
- erb/small: 1.15x
- calc/medium: 1.07x
- erb/medium: 1.03x

### Key Observations
- **Sentence parser**: Consistently 10-14% slower across ALL sizes
- **Calc**: Mixed results - tiny/medium faster, small/large slower
- **Memory**: ALL cases have 27-52% fewer allocations (good!)
- **Tests**: All 675 passing

---

## Root Cause Hypotheses

### Hypothesis 1: Optimization Overhead for Simple Parsers
**Evidence:**
- Sentence parser is simplest (just word matching)
- Consistent slowdown across all sizes (not initialization)
- Memory is better but speed is worse
- Suggests optimization adds more overhead than benefit

**Test:** Compare sentence parser with/without optimize_rules!

### Hypothesis 2: Pathological Backtracking (calc/large)
**Evidence:**
- Only calc/large affected (tiny/medium work)
- 32% slowdown is severe
- Large input (50KB) suggests exponential behavior
- Memory is 45% better (not the issue)

**Test:** Profile calc/large for backtracking patterns

### Hypothesis 3: Cache Lookup Overhead
**Evidence:**
- Small inputs slower (91-90% of vanilla)
- Lazy caches still have lookup cost
- First-use initialization might hit repeatedly

**Test:** Measure cache hit/miss ratios

---

## Investigation Plan

### Phase 1: Disable Optimization Selectively (2 hours)

**Approach**: Test if optimization is the problem

**Task 1.1: Create Sentence Parser Without Optimization**
```ruby
# benchmark/parsers/sentence_parser_noopt.rb
class SentenceParserNoOpt < Parslet::Parser
  disable_optimization!
  # Copy rules from sentence parser
end
```

**Task 1.2: Benchmark Comparison**
```ruby
# Compare:
# - Vanilla parslet 2.0
# - Plurimath with optimization
# - Plurimath without optimization
```

**Expected Result:** If no-opt matches vanilla, optimization is the problem.

### Phase 2: Profile Optimization Overhead (2 hours)

**Task 2.1: Measure Optimization Cost Per Parser**
```ruby
# benchmark/measure_optimization_cost.rb
parsers = [SentenceParser, CalcParser, JsonParser, ErbParser]
parsers.each do |p|
  measure_parse_time(p.new) # with optimization
  measure_parse_time(p.new.disable_optimization!) # without
end
```

**Task 2.2: Identify Problem Optimizations**
- Test with only cut operators
- Test with only flattening
- Test with only repetition optimization
- Find which adds overhead

### Phase 3: Implement Smart Optimization (2-3 hours)

**Option A: Heuristic-Based Optimization**
```ruby
class Parslet::Parser
  def self.optimize_rules!
    return if simple_parser? # Skip for simple parsers
    # ... apply optimizations
  end
  
  private
  def self.simple_parser?
    # Heuristics:
    # - Few rules (<10)
    # - Shallow depth (<5)
    # - No complex patterns
    @rules.size < 10 && max_rule_depth < 5
  end
end
```

**Option B: Selective Optimization Strategy**
```ruby
class Parslet::Parser
  def self.optimize_rules!(strategies: :auto)
    strategies = detect_beneficial_strategies if strategies == :auto
    apply_optimizations(strategies)
  end
  
  private
  def self.detect_beneficial_strategies
    # Measure parser characteristics
    # Return list of beneficial optimizations
    # Example: [:flatten] for simple parsers
    #          [:cut, :flatten, :lookahead] for complex
  end
end
```

**Option C: Per-Parser Override**
```ruby
# Allow parsers to opt-out
class SentenceParser < Parslet::Parser
  disable_optimization!  # Explicit opt-out
end

# Or fine-tune
class CalcParser < Parslet::Parser
  optimize_rules! strategies: [:flatten], skip: [:cut]
end
```

### Phase 4: Fix Calc/Large Pathology (1-2 hours)

**Task 4.1: Profile calc/large**
```ruby
# benchmark/profile_calc_large.rb
# Compare calc/large vs calc/medium
# Identify exponential patterns
```

**Task 4.2: Add Strategic Cut Operators**
```ruby
# If backtracking is the issue, add cuts:
class CalcParser < Parslet::Parser
  rule(:expression) {
    term >> (cut >> operator >> term).repeat
  }
end
```

**Task 4.3: Test Cut Placement**
- Profile with different cut positions
- Measure improvement
- Ensure no parse failures

### Phase 5: Validate Zero Regressions (1 hour)

**Task 5.1: Create Regression Validator**
```ruby
# benchmark/validate_no_regressions.rb
def validate_release_ready
  results = BenchmarkSuite.run_comprehensive
  
  regressions = results.select { |r| r.speedup < 1.0 }
  
  if regressions.any?
    puts "❌ RELEASE BLOCKED"
    puts "Regressions: #{regressions.size}/#{results.size}"
    regressions.each do |r|
      puts "  #{r.name}: #{r.speedup}x (#{r.speedup_percent}%)"
    end
    exit 1
  else
    puts "✅ RELEASE READY"
    puts "All #{results.size} cases faster than vanilla"
    puts "Average: #{results.map(&:speedup).sum / results.size}x"
    exit 0
  end
end
```

**Task 5.2: Run Full Validation**
```bash
bundle exec rake spec                           # 675 tests
ruby benchmark/validate_no_regressions.rb       # All cases >1.0x
ruby -Ilib benchmark/comprehensive_suite.rb     # Final numbers
```

---

## Success Criteria (STRICT)

### Release Blockers (Must Have)
- [ ] **ALL 14 cases > 1.0x** (zero tolerance)
- [ ] **Minimum speedup: 1.02x** (2% faster minimum)
- [ ] **Average speedup: > 1.3x** (improved from 1.28x)
- [ ] **sentence/tiny**: >1.0x (currently 0.87x)
- [ ] **sentence/small**: >1.0x (currently 0.90x)
- [ ] **sentence/medium**: >1.0x (currently 0.86x)
- [ ] **calc/small**: >1.0x (currently 0.91x)
- [ ] **calc/large**: >1.0x (currently 0.68x)
- [ ] All 675 tests passing
- [ ] No memory regressions

### Quality Gates
- [ ] JSON parser still excellent (>2.0x average)
- [ ] ERB parser still good (>1.1x average)
- [ ] Consistent performance (no variance >20%)
- [ ] Memory efficiency maintained (>20% fewer allocations)

---

## Contingency Plans

### If Optimization Is The Problem

**Solution**: Smart optimization enabling

```ruby
# lib/parslet.rb
class Parslet::Parser
  def self.inherited(subclass)
    super
    # Smart optimization based on parser characteristics
    if should_optimize?(subclass)
      subclass.class_eval { optimize_rules! }
    end
  end
  
  private
  def self.should_optimize?(parser_class)
    # Don't optimize simple parsers
    return false if parser_class.simple_parser?
    true
  end
end
```

### If Calc/Large Can't Be Fixed

**Options:**
1. Document as known limitation (last resort)
2. Add better cut operators to calc parser specifically
3. Implement memoization for calc expressions
4. Optimize repetition handling for large inputs

### If Multiple Cases Can't Be Fixed

**DECISION TREE:**

**6-hour checkpoint:**
- If 3+ regressions remain: Switch to opt-in optimization
- If 1-2 remain: Continue fixing
- If 0 remain: Release!

**8-hour deadline:**
- If ANY regressions: Make optimization opt-in + document
- Release v3.1.0 with opt-in optimization
- Plan v3.2.0 with smarter defaults

---

## Expected Timeline

| Hour | Task | Checkpoint |
|------|------|------------|
| 0-2 | Phase 1: Test without optimization | Find root cause |
| 2-4 | Phase 2: Profile optimization overhead | Understand problem |
| 4-7 | Phase 3: Implement smart optimization | Fix regressions |
| 7-8 | Phases 4-5: Validate & finalize | Release ready |

**DECISION POINTS:**
- Hour 4: If >3 regressions remain, consider opt-in
- Hour 6: If >1 regression remains, prepare opt-in
- Hour 8: DEADLINE - Release with best solution

---

## Deliverables

### Code Changes
1. Smart optimization logic (auto-detect simple parsers)
2. Per-parser optimization control
3. Regression validation script
4. Calc parser improvements (if needed)

### Documentation
1. Optimization guide (when to optimize)
2. Parser characterization guide
3. Troubleshooting regressions
4. Session 9 completion document

### Benchmarks
1. All 14 cases >1.0x validated
2. Final comprehensive report
3. Optimization effectiveness analysis
4. Per-parser recommendations

---

## Risk Assessment

### Low Risk (Likely Fixable)
- Sentence parser regression (disable optimization)
- Calc/small regression (cache tuning)

### Medium Risk
- Calc/large regression (may need grammar fixes)

### High Risk
- Multiple regressions persist (would require opt-in)

---

## References

- Session 8: [`docs/SESSION_8_COMPLETE.md`](SESSION_8_COMPLETE.md)
- Current benchmarks: [`benchmark/results/comprehensive_v3.1.0.json`](../benchmark/results/comprehensive_v3.1.0.json)
- Investigation: [`docs/PERFORMANCE_REGRESSION_INVESTIGATION.md`](PERFORMANCE_REGRESSION_INVESTIGATION.md)

---

*Session 9: Zero Tolerance for Regressions*  
*Target: ALL cases >1.0x faster*  
*Deadline: 8 hours*