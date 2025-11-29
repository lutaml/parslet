# Phase 51: Ruby Platform Optimizations - Planning

## Context

After completing Phase 50 series (YJIT, frozen strings, GC tuning), we continue exploring Ruby platform-level optimizations.

**Current Status**:
- Phase 50a: YJIT profiling (2.09x speedup identified)
- Phase 50b Phase 1: Frozen strings in 7 core files (13.9% improvement)
- Phase 50b Phase 2: Tested 15 more files, found no benefit, reverted
- Phase 50c: GC tuning documentation already exists

## Remaining Ruby Optimization Opportunities

### 1. Method Inlining (HIGH PRIORITY)
**Status**: Requires profiling to identify hot methods
**Complexity**: Medium
**Risk**: Low (code duplication)
**Estimated Impact**: 3-8% for frequently-called simple methods

**Approach**:
- Profile with ruby-prof to identify method call overhead
- Look for simple methods called millions of times
- Inline getters/setters if beneficial
- Focus on hot paths in atoms/base.rb, atoms/context.rb

**Examples**:
```ruby
# Before
def error(source, str, pos)
  @error_msgs ||= {}
  @error_msgs[pos] ||= UnexpectedString.new(source, str, pos)
end

# After (if profiling shows benefit)
@error_msgs ||= {}
@error_msgs[pos] ||= UnexpectedString.new(source, str, pos)
```

### 2. Instance Variable Caching (MEDIUM PRIORITY)
**Status**: Ready to test
**Complexity**: Low
**Risk**: Low
**Estimated Impact**: 1-3%

**Rationale**:
Ruby has to traverse the instance variable table on each access. Caching frequently-accessed ivars in local variables can help.

**Candidates**:
- `@parslets` in Sequence (accessed in loop)
- `@min, @max` in Repetition (accessed in loop)
- `@bound` in Named (accessed on every parse)

### 3. Pre-computed Constants (LOW PRIORITY)
**Status**: Ready to implement
**Complexity**: Low
**Risk**: Very Low
**Estimated Impact**: <1%

**Examples**:
```ruby
# Before
def success(result)
  result.nil? ? nil : result
end

# After
NIL_SUCCESS = nil.freeze
def success(result)
  result.nil? ? NIL_SUCCESS : result
end
```

### 4. Reduce Hash Allocations (MEDIUM PRIORITY)
**Status**: Requires analysis
**Complexity**: Medium
**Risk**: Medium
**Estimated Impact**: 2-5%

**Approach**:
- Identify temporary hash allocations
- Replace with objects or arrays where appropriate
- Focus on error tracking, position management

### 5. String Interpolation Optimization (LOW PRIORITY)
**Status**: Ready to implement
**Complexity**: Low
**Risk**: Very Low
**Estimated Impact**: <1%

**Examples**:
```ruby
# Before
"Expected #{str} at position #{pos}"

# After
"Expected " + str + " at position " + pos.to_s
```

## Recommended Phase 51: Method Inlining

**Plan**:
1. Profile with ruby-prof to identify method call hotspots
2. Measure baseline performance
3. Inline top 3-5 simple methods with highest call counts
4. Benchmark after each change
5. Keep only beneficial inlines
6. Run full test suite

**Expected Files to Modify**:
- `lib/parslet/atoms/base.rb`
- `lib/parslet/atoms/context.rb`
- `lib/parslet/atoms/sequence.rb`
- `lib/parslet/atoms/repetition.rb`

**Success Criteria**:
- 3-8% performance improvement
- Zero test regressions
- Minimal code duplication
- Clear comments explaining inlining decisions

## Alternative: Phase 51 Instance Variable Caching

If profiling shows method calls are not the bottleneck, we can try instance variable caching instead.

**Plan**:
1. Identify frequently-accessed instance variables in hot loops
2. Cache in local variables at loop start
3. Benchmark changes
4. Keep only beneficial caching

**Expected Impact**: 1-3% improvement with minimal code changes

## Decision Point

**Recommendation**: Start with profiling-based method inlining (Phase 51a), as it has the highest potential impact (3-8%) and builds on our Phase 50a profiling infrastructure.

If method inlining shows limited benefit, pivot to instance variable caching (Phase 51b).

## Next Steps

1. Create profiling script targeting method call overhead
2. Run baseline benchmarks
3. Identify top 5 inline candidates
4. Implement and test incrementally
5. Document results

---
**Created**: October 24, 2025
**Status**: Planning Complete - Ready for Phase 51a Implementation
