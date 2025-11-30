# Continuation Prompt: Session 8 - Performance Regression Deep Fix

**Session**: 8 (CRITICAL - Performance Investigation)
**Priority**: CRITICAL (Release Blocking)
**Duration**: 4-8 hours
**Previous Cost**: $14.52 + 6+ hours
**Status**: Investigation required

---

## Your Role

You are Kilo Code, investigating and fixing critical performance regressions that block the plurimath-parslet v3.1.0 release.

---

## Critical Problem

Comprehensive benchmarks revealed plurimath-parslet is **slower** than vanilla parslet 2.0 in many cases:

**Benchmark Results:**
- Average: 1.23x (target: >1.5x all cases)
- Worst: 0.16x for json/tiny (**6x SLOWER**)
- Best: 2.81x for json/small
- Pattern: Small inputs suffer most

**Already Fixed:**
- ✅ Charpos bottleneck (37x improvement)
- ✅ optimize_rules! enabled by default
- ✅ 675 tests passing

**Still Broken:**
- ❌ json/tiny: 492 ips vs 3153 ips vanilla (6x slower!)
- ❌ sentence/tiny: 15k ips vs 38k ips (2.5x slower)
- ❌ Many test cases showing regressions

---

## Key Documents

Must Read:
- **Investigation**: `docs/PERFORMANCE_REGRESSION_INVESTIGATION.md` - Complete analysis
- **Plan**: `docs/CONTINUATION_PLAN_SESSION8.md` - Execution steps
- **Benchmarks**: `benchmark/results/comprehensive_v3.1.0.json` - Latest data

Reference:
- `docs/SESSION_7_COMPLETE.md` - Session 7 findings
- `docs/comparative_results.json` - Historical Session 3 data

---

## Root Causes Identified

### 1. Excessive Source#initialize (13.7% of JSON tiny parse time)
Creating too many Source objects or too much initialization overhead.

### 2. High GC Pressure (43.7% of JSON tiny parse time)
Too many object allocations for small inputs.

### 3. Initialization Overhead Pattern
Large files perform BETTER (erb/large: 1.85x faster!)
Small files perform WORSE (json/tiny: 0.16x)
= Initialization cost dominates small parses

---

## Your Mission

**Primary**: Eliminate initialization overhead causing small input regressions
**Secondary**: Achieve >1.5x speedup across ALL test cases
**Tertiary**: Document findings comprehensively

---

## Investigation Phases

### Phase 1: Profile Initialization (1-2h)

**Objective**: Identify what in Source#initialize causes overhead

**Tasks:**
```ruby
# Create benchmark/profile_init_overhead.rb
# 1. Profile Source.new for tiny inputs
# 2. Measure each initialization step
# 3. Compare vanilla vs plurimath Source creation
# 4. Identify unnecessary work
```

**Expected Findings**:
- Position cache allocation
- Charpos cache allocation  
- Regex cache population
- Line cache scanning

**Tools**: stackprof, memory_profiler, benchmark-ips

### Phase 2: Implement Lazy Initialization (2-3h)

**Strategy**: Defer work until actually needed

**Changes**:
1. `@pos_cache`: Create on first use, not in initialize
2. `@charpos_cache`: Create on first use
3. `@re_cache`: Defer regex compilation
4. `@line_cache`: Only scan when line_and_column called

**Target**: 2-3x improvement on tiny inputs

**Validation**: Re-run benchmarks after each change

### Phase 3: Reduce Object Allocations (1-2h)

**From Profile**: Too many Hash/Array allocations

**Strategies**:
1. Reuse Hash instances across calls
2. Use frozen empty hashes where possible
3. Pool Position objects
4. Consider struct-based Position (lighter weight)

**Target**: Reduce allocations by 50%

### Phase 4: Optimize Hot Paths (1-2h)

**Top Methods** (from stackprof):
- `Context#try_with_cache` (40.9%)
- `Sequence#try` (40.7%)
- `Repetition#try_repetition_general` (23%)

**Analysis**:
1. Profile each method independently
2. Identify unnecessary work
3. Apply micro-optimizations
4. Validate improvements

---

## Validation Strategy

### Micro-Benchmarks
After each fix, measure:
```bash
ruby benchmark/profile_json_regression.rb  # json/tiny
ruby benchmark/profile_sentence_regression.rb  # sentence/medium
```

### Full Validation
```bash
ruby -Ilib benchmark/comprehensive_suite.rb
# Target: ALL cases > 1.0x, average > 1.5x
```

### Test Suite
```bash
bundle exec rake spec  
# Must: 675 passing, 0 failures
```

---

## Success Criteria

### Must Have (Release Blockers)
- [ ] json/tiny: >1.0x (currently 0.16x - CRITICAL)
- [ ] sentence/tiny: >1.0x (currently 0.44x)
- [ ] calc/tiny: >1.0x (currently 0.72x)
- [ ] Average speedup: >1.2x across all cases
- [ ] No test failures

### Should Have (Quality Goals)
- [ ] json/tiny: >2.0x
- [ ] Average speedup: >1.5x
- [ ] Consistent performance across sizes
- [ ] < 30% variance between runs

### Nice to Have
- [ ] Some cases achieving 3-5x
- [ ] GC pressure reduced to <20%
- [ ] Memory allocations competitive with vanilla

---

## Diagnostic Tools to Create

### 1. Profile Initialization
```ruby
# benchmark/profile_init_overhead.rb
# Measures Source#initialize cost breakdown
```

### 2. Compare Allocations
```ruby
# benchmark/compare_allocations.rb  
# Vanilla vs plurimath allocation comparison
```

### 3. Cache Overhead
```ruby
# benchmark/measure_cache_cost.rb
# Cost of each cache structure
```

### 4. Micro-benchmark Tiny Inputs
```ruby
# benchmark/micro_bench_tiny.rb
# Focus on problematic cases
```

---

## Contingency Plans

### If Initialization Can't Be Fixed

**Option**: Make caches opt-in
```ruby
class Parslet::Source
  def initialize(str, enable_caches: true)
    # Only create caches if enabled
  end
end
```

### If Still Shows Regressions

**Options**:
1. Document as known limitation (small inputs have overhead)
2. Release v3.0.1 with only charpos fix
3. Postpone v3.1.0 to v3.2.0

### If Takes Too Long

**Decision Point at 4 hours**:
- If making progress: Continue
- If stuck: Switch to Option 4 (alternative approach)
- If hopeless: Postpone release

---

## Expected Outcomes

### Optimistic (Target)
- All cases > 1.5x faster
- json/tiny: 3-5x faster
- Validated performance claims
- Clean release

### Realistic (Acceptable)
- All cases > 1.0x faster
- Average: 1.5-2x faster
- Some small input overhead noted
- Release with caveats

### Pessimistic (Fallback)
- Can't fix all cases
- Release v3.0.1 maintenance instead
- Plan v3.2.0 with proper fixes
- Honest about limitations

---

## Quick Start Commands

```bash
# 1. Profile initialization
ruby benchmark/profile_init_overhead.rb

# 2. Measure allocations
ruby benchmark/compare_allocations.rb

# 3. Test fixes incrementally
bundle exec rake spec

# 4. Validate improvements
ruby -Ilib benchmark/comprehensive_suite.rb

# 5. Generate report
ruby -Ilib benchmark/generate_report.rb --comprehensive comprehensive_v3.1.0
```

---

## Key Insights to Remember

1. **Pattern**: Large files perform BETTER (erb/large: 1.85x)
2. **Pattern**: Tiny files perform WORSE (json/tiny: 0.16x)
3. **Root Cause**: Initialization overhead dominates small parses
4. **Already Fixed**: Charpos (was 78% CPU, now minimal)
5. **Remaining**: Source init, GC pressure, cache overhead

---

## Documentation Updates Needed

After fixes:
1. Update README.adoc with achieved performance
2. Update HISTORY.txt with fix details
3. Update PERFORMANCE_REGRESSION_INVESTIGATION.md with resolution
4. Generate final benchmark report
5. Create Session 8 completion document

---

*Critical Session - Release Depends on This*
*Deadline: Complete within 8 hours or abort release*
*Decision Point: 4 hours*