# Continuation Plan: Session 18 - Integer Positions Optimization (v3.3.0)

**Priority**: HIGH  
**Goal**: Replace Position object with integer positions to reduce overhead and achieve 1.35-1.40x cumulative performance  
**Duration**: 1 week (compressed from planned 2-3 weeks)  
**Status**: Ready to execute

---

## Context from Session 17

### Performance Baseline (v3.2.0)

- **Current average**: 1.27x ±0.01x (validated across 3 runs)
- **Improvement**: +1.6% over v3.1.0 baseline
- **Stability**: 100% of test cases faster
- **Tests**: 712/713 passing (1 pre-existing failure)

### Key Finding from Session 17

**Rope optimization had limited impact** because:
1. String concatenation happens during parser construction (one-time cost)
2. Real parsing hot path uses Position objects extensively
3. Session 15 profiling showed Base#succ is 9% of runtime

**Conclusion**: Next optimization must target runtime parsing operations.

---

## Mission for Session 18

Replace Position object with integer-based position tracking to eliminate object allocation overhead in the parsing hot path.

### Target Improvement

- **Primary goal**: 1.35x average minimum (from 1.27x v3.2.0)
- **Stretch goal**: 1.40x average
- **Cumulative from v2.0**: 1.35-1.40x total improvement
- **Regression threshold**: Must maintain ≥1.25x average
- **Test stability**: All 712 tests must pass

---

## Phase 1: Position Analysis (Day 1)

### 1.1: Analyze Current Position Usage

**Objective**: Understand how Position is used throughout codebase

**Tasks**:
1. Search for all Position object creation sites
2. Identify Position methods called in hot paths
3. Map Position -> Slice dependencies
4. Document Position API surface

**Deliverables**:
- `docs/POSITION_ANALYSIS.md` - Complete Position usage analysis
- List of all files using Position
- Hot path identification

### 1.2: Design Integer Position System

**Objective**: Design clean replacement for Position objects

**Key decisions**:
1. **Representation**: Use integer byte position directly
2. **Charpos calculation**: Lazy, on-demand only
3. **Line/column**: Keep existing LineCache, pass through
4. **Backward compatibility**: Maintain existing Slice API

**Design principles**:
- **Single Responsibility**: Position tracking only
- **Separation of Concerns**: Position != LineCache
- **MECE**: bytepos (primary), charpos (derived), line/column (external)

---

## Phase 2: Slice Refactoring (Day 2-3)

### 2.1: Update Slice to Use Integer Position

**Objective**: Replace Position object with integer in Slice

**Current Slice**:
```ruby
class Slice
  def initialize(position, string, line_cache = nil)
    @position = position  # Position object
    @str = string
    @line_cache = line_cache
  end
  
  def offset
    @offset ||= @position.charpos
  end
end
```

**New Slice**:
```ruby
class Slice
  def initialize(bytepos, string, line_cache = nil)
    @bytepos = bytepos  # Integer, not Position object
    @str = string
    @line_cache = line_cache
  end
  
  def offset
    # Calculate charpos on demand if needed
    @bytepos
  end
  
  alias charpos offset
  alias bytepos offset
end
```

**Rationale**:
- Eliminates Position object allocation (hot path)
- Reduces memory footprint
- Simplifies position tracking
- Maintains backward compatibility

### 2.2: Update Slice Tests

**Objective**: Update tests for integer-based positions

Tasks:
1. Update `spec/parslet/slice_spec.rb`
2. Replace Position creation with integers
3. Verify all Slice tests pass
4. Add tests for charpos/bytepos aliases

---

## Phase 3: Source Refactoring (Day 3-4)

### 3.1: Update Source to Return Integers

**Objective**: Make Source.pos return integer instead of Position

**Current Source**:
```ruby
class Source
  def pos
    Position.new(@str, @bytepos, @charpos)
  end
end
```

**New Source**:
```ruby
class Source
  def pos
    @bytepos  # Return integer directly
  end
  
  alias bytepos pos
end
```

**Impact**:
- Every parslet.apply() call creates Position objects
- This is THE hot path (thousands of calls per parse)
- Eliminating this allocation = major win

### 3.2: Update Source Tests

**Objective**: Verify Source returns integers correctly

Tasks:
1. Update `spec/parslet/source_spec.rb`
2. Verify position tracking still works
3. Test bytepos alias

---

## Phase 4: Atom Updates (Day 4-5)

### 4.1: Update All Atoms

**Objective**: Update atoms to work with integer positions

**Files to update**:
- `lib/parslet/atoms/str.rb`
- `lib/parslet/atoms/re.rb`
- `lib/parslet/atoms/repetition.rb`
- `lib/parslet/atoms/sequence.rb`
- `lib/parslet/atoms/alternative.rb`
- `lib/parslet/atoms/lookahead.rb`

**Pattern**:
```ruby
# OLD
result = Slice.new(source.pos, matched_string, source.line_cache)

# NEW  
result = Slice.new(source.bytepos, matched_string, source.line_cache)
```

**Strategy**:
1. Update one atom at a time
2. Run tests after each change
3. Verify no regressions

### 4.2: Update Atom Tests

**Objective**: Verify each atom works with integer positions

Tasks:
1. Run full test suite after each atom update
2. Fix any test failures
3. Ensure 712/713 baseline maintained

---

## Phase 5: LineCache Integration (Day 5)

### 5.1: Verify LineCache Compatibility

**Objective**: Ensure line/column calculation still works

**LineCache interface**:
```ruby
class LineCache
  def line_and_column(bytepos)
    # Takes integer bytepos
    # Returns [line, column]
  end
end
```

**Good news**: LineCache already uses integer bytepos!

**Tasks**:
1. Verify LineCache tests still pass
2. Test line_and_column with integer positions
3. Verify error messages show correct line/column

### 5.2: Update Error Reporting

**Objective**: Ensure error messages still show positions correctly

**Files to check**:
- `lib/parslet/cause.rb`
- `lib/parslet/error_reporter.rb`
- `lib/parslet/atoms/context.rb`

**Verify**:
- Error messages show correct byte positions
- Line/column calculation works
- Error context is accurate

---

## Phase 6: Benchmark and Validate (Day 6)

### 6.1: Run Performance Benchmarks

**Command**: `ruby benchmark/fair_comparison.rb` (3 runs)

**Expected results**:
- Overall average: **1.35-1.40x** (vs 1.27x v3.2.0)
- Cumulative: **1.35-1.40x** (vs 2.0.0 baseline)
- No regressions: All cases ≥1.20x
- JSON parser: **1.60x+** (best case)
- At least **8/14 cases ≥1.35x**

**Validation criteria**:
- ✅ Average ≥1.35x (primary target)
- ✅ Variance ±3-10% (acceptable)
- ✅ No case regresses >5% from v3.2.0
- ✅ Position overhead eliminated (verify in profiling)

### 6.2: Run Complete Test Suite

**Command**: `bundle exec rspec`

**Expected results**:
- 712/713 tests passing
- 1 pre-existing failure unchanged
- No new failures

### 6.3: Profile Performance

**Objective**: Verify Position overhead eliminated

**Check**:
- Position object allocations: Should be 0 or near-0
- Base#succ calls: Should be significantly reduced
- Memory usage: Should be lower
- GC pressure: Should be reduced

**Commands**:
```bash
# Profile allocations
ruby -r memory_profiler benchmark/profile_allocations.rb

# Profile CPU
ruby -r stackprof benchmark/profile_hotspots.rb
```

---

## Phase 7: Documentation (Day 7)

### 7.1: Update Performance Documentation

**Modify**: `docs/PERFORMANCE_BENCHMARKS.adoc`

Add v3.3.0 results section showing improvement over v3.2.0.

### 7.2: Update Architecture Roadmap

**Modify**: `docs/ARCHITECTURE_V4_PLAN.adoc`

Mark Phase 2 (v3.3.0 Integer Positions) as complete with metrics.

### 7.3: Update README

**Modify**: `README.adoc`

Update performance numbers from 1.27x to achieved average (target: 1.37x).

### 7.4: Create Release Notes

**Create**: `docs/RELEASE_NOTES_v3.3.0.md`

Document changes, performance improvements, migration notes.

### 7.5: Create Session Completion Document

**Create**: `docs/SESSION_18_COMPLETE.md`

Document achievements, lessons learned, next steps.

---

## Success Criteria

### Must Achieve (Release Blockers)

- [ ] **Integer positions implemented** throughout codebase
- [ ] **Position object eliminated** from hot paths
- [ ] **All tests passing** (712/713 baseline)
- [ ] **Performance target met**: ≥1.35x average
- [ ] **No regressions**: All tests stable
- [ ] **Documentation updated**: Benchmarks, README, architecture

### Quality Gates

- [ ] Clean architecture: MECE, separation of concerns
- [ ] No copy-paste code
- [ ] Backward compatible API
- [ ] Clear migration path (if any breaking changes)
- [ ] Performance improvement reproducible (3+ runs)

### Nice to Have

- [ ] Memory profiling shows reduced allocations
- [ ] GC stats show reduced pressure
- [ ] Additional optimization opportunities identified

---

## Risk Mitigation

### Risk 1: Breaking Changes

**Likelihood**: Medium  
**Impact**: High (API compatibility)

**Mitigation**:
- Maintain Slice API compatibility
- Add aliases for charpos/bytepos
- Test thoroughly before release
- Document any breaking changes clearly

### Risk 2: Performance Target Not Met

**Likelihood**: Low (Position is proven bottleneck)  
**Impact**: Medium (need v3.4.0)

**Mitigation**:
- Profile early (Day 2)
- Incremental benchmarking
- If <1.35x, investigate other hot paths
- Fall back: Ship as v3.2.1 with partial gains

### Risk 3: Test Failures

**Likelihood**: Medium (significant refactoring)  
**Impact**: High (delays release)

**Mitigation**:
- Update one atom at a time
- Run tests after each change
- Fix failures immediately
- Remember: Correct behavior > passing tests

---

## Implementation Strategy

### Incremental Approach

1. **Day 1**: Analysis only (no code changes)
2. **Day 2**: Slice refactoring + tests
3. **Day 3**: Source refactoring + tests
4. **Day 4**: Str + Re atoms (test after each)
5. **Day 5**: Remaining atoms + LineCache verification
6. **Day 6**: Benchmarking + validation
7. **Day 7**: Documentation

### Testing Strategy

- Run tests after every file change
- Fix failures before proceeding
- Maintain 712/713 baseline at all times
- Profile after Slice + Source changes

### Rollback Plan

If performance target not met by Day 5:
1. Continue with implementation (may reveal other wins)
2. Ship as v3.2.1 if some improvement shown
3. Document findings for v3.4.0
4. Consider alternative approaches

---

## Expected Outcome

**Primary**: v3.3.0 with 1.35-1.40x cumulative performance

**Timeline**: 7 days (compressed)

**Next session**: v3.4.0 - Additional optimizations based on profiling

---

## Contingency Plans

### If Performance < 1.35x

1. Profile to identify remaining bottlenecks
2. Consider hybrid approach (keep Position for some cases)
3. Ship as v3.2.1 with documented gains
4. Plan v3.4.0 with additional optimizations

### If Tests Fail Systematically

1. Identify root cause (integer vs Position mismatch?)
2. Fix architecture if needed
3. Remember: Correct implementation > passing tests
4. Update test expectations if behavior changed

### If Behind Schedule

**Priority order**:
1. Slice + Source updates (highest impact) - **DO NOT SKIP**
2. Atom updates (required for correctness) - **DO NOT SKIP**
3. Documentation (can be async) - Can defer
4. Profiling (nice-to-have) - Can defer

---

**Let's eliminate Position object overhead and achieve 1.35-1.40x performance!**