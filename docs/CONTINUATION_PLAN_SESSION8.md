# Continuation Plan: Session 8 - Deep Performance Investigation

**Session**: 8 (Critical Performance Fix)
**Priority**: CRITICAL (Release Blocking)
**Duration**: 4-8 hours
**Est. Cost**: $10-$20
**Already Spent**: $12.39, 6+ hours

---

## Current Status

### What We Discovered
- Plurimath averages 1.23x vs vanilla (target: consistently faster)
- json/tiny: 0.16x (6x SLOWER - worst case)
- Charpos bottleneck fixed (37x improvement)
- optimize_rules! enabled by default
- Still have initialization overhead issues

### Release Blocker
Cannot release with performance regressions. Must be strictly faster in ALL cases.

---

## Investigation Plan

### Phase 1: Profile Initialization Overhead (1-2 hours)

JSON tiny shows 43% GC time and 13.7% in Source#initialize.

**Tasks:**
1. Profile Source#initialize to identify overhead
2. Measure cache initialization costs
3. Compare object allocation counts: vanilla vs plurimath
4. Identify unnecessary allocations

**Tools:**
- stackprof for CPU profiling
- memory_profiler for allocation tracking
- benchmark-ips for timing

### Phase 2: Lazy Initialization Strategy (2-3 hours)

**Hypothesis**: Caches add overhead on tiny inputs.

**Tasks:**
1. Make position cache lazy
2. Make charpos cache lazy (only on first pos call)
3. Defer regex cache population
4. Benchmark impact of each change

**Expected**: 2-3x improvement on tiny inputs

### Phase 3: Re-evaluate Optimization Overhead (1-2 hours)

**Hypothesis**: optimize_rules! transformations add parse-time overhead.

**Tasks:**
1. Measure optimization application time
2. Profile optimized vs unoptimized execution
3. Identify if optimizations cause runtime overhead
4. Consider caching optimized rules

### Phase 4: Alternative Approach - Revert to Opt-In (1 hour)

If initialization can't be fixed:

**Tasks:**
1. Revert to opt-in optimize_rules!
2. Update documentation clearly
3. Provide migration script for users
4. Release with honest performance claims

---

## Success Criteria

**Must Have:**
- [ ] ALL test cases faster than vanilla (speedup > 1.0x)
- [ ] json/tiny improved from 0.16x to > 1.0x
- [ ] Average speedup > 1.5x
- [ ] No initialization overhead on small inputs
- [ ] 675 tests still passing

**Should Have:**
- [ ] Average speedup > 2.0x
- [ ] Consistent performance across input sizes
- [ ] Validated with multiple parser types

---

## Key Files to Investigate

1. `lib/parslet/source.rb` - Source initialization
2. `lib/parslet/atoms/context.rb` - Context and caching
3. `lib/parslet.rb` - Rule optimization application
4. `lib/parslet/optimizer.rb` - Optimization transformations

---

## Diagnostic Scripts

Create these for investigation:

1. `benchmark/profile_initialization.rb` - Measure Source#initialize cost
2. `benchmark/profile_cache_overhead.rb` - Measure cache costs
3. `benchmark/compare_allocations.rb` - Vanilla vs plurimath allocations
4. `benchmark/profile_optimizer_overhead.rb` - Optimization application cost

---

## Timeline

| Phase | Task | Duration | Priority |
|-------|------|----------|----------|
| 1 | Profile initialization | 1-2h | HIGH |
| 2 | Implement lazy caching | 2-3h | HIGH |
| 3 | Re-evaluate optimizations | 1-2h | MEDIUM |
| 4 | Alternative (if needed) | 1h | LOW |
| **Total** | | **4-8h** | |

---

## Rollback Plan

If investigation shows fundamental architectural issues:

1. **Option A**: Release v3.0.1 maintenance with charpos fix only
2. **Option B**: Postpone to v3.2.0 with proper fixes
3. **Option C**: Make optimize_rules! opt-in and release v3.1.0

---

## References

- `docs/PERFORMANCE_REGRESSION_INVESTIGATION.md` - Current findings
- `benchmark/results/comprehensive_v3.1.0.json` - Latest benchmark data
- `docs/comparative_results.json` - Historical Session 3 data
- Old optimization phases: `docs/old-docs/completed-phases/PHASE*.md`

---

*Document Status: READY*
*Created: 2025-11-30*
*Session: 8 (Performance Investigation)*
*Dependency: Session 7 findings*