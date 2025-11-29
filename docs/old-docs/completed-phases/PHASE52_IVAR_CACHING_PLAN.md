# Phase 52: Instance Variable Caching in Hot Loops

## Objective

Test whether caching frequently-accessed instance variables in local variables within hot loops provides measurable performance benefit.

## Rationale

While modern Ruby (3.3) has optimized ivar access, local variable access is still slightly faster. In tight loops where the same ivars are accessed thousands of times, caching them in locals could provide 1-3% improvement.

## Target Areas

### 1. Sequence#try (lib/parslet/atoms/sequence.rb)
**Current Code**:
```ruby
def try(source, context, consume_all)
  result = nil
  start = source.pos

  @parslets.each do |parslet|  # @parslets accessed once, but in loop context
    success, value = result = parslet.apply(source, context, consume_all)
    return result unless success
  end

  succ(flatten(result.last, true))
end
```

**Proposed**:
```ruby
def try(source, context, consume_all)
  result = nil
  start = source.pos
  parslets = @parslets  # Cache ivar

  parslets.each do |parslet|
    success, value = result = parslet.apply(source, context, consume_all)
    return result unless success
  end

  succ(flatten(result.last, true))
end
```

### 2. Repetition#try (lib/parslet/atoms/repetition.rb)
**Current Code**:
```ruby
def try(source, context, consume_all)
  ...
  min = @min
  max = @max
  ...
```

**Status**: Already caches @min and @max! ✅

### 3. Alternative#try (lib/parslet/atoms/alternative.rb)
**Current Code**:
```ruby
def try(source, context, consume_all)
  ...
  @alternatives.each do |alternative|  # @alternatives accessed in loop
    ...
  end
end
```

**Proposed**:
```ruby
def try(source, context, consume_all)
  ...
  alternatives = @alternatives  # Cache ivar
  alternatives.each do |alternative|
    ...
  end
end
```

### 4. Named#try (lib/parslet/atoms/named.rb)
**Current Code**:
```ruby
def try(source, context, consume_all)
  source.pos(start)
  success, value = @bound.apply(source, context, consume_all)  # @bound accessed
  ...
end
```

**Proposed**:
```ruby
def try(source, context, consume_all)
  bound = @bound  # Cache ivar
  source.pos(start)
  success, value = bound.apply(source, context, consume_all)
  ...
end
```

## Expected Impact

- **Best Case**: 2-3% improvement if ivar access is frequent bottleneck
- **Likely Case**: 0.5-1.5% improvement
- **Worst Case**: No measurable change or slight regression

## Risk Assessment

- **Risk**: VERY LOW
- **Complexity**: Minimal (1-2 lines per method)
- **Reversibility**: Easy to revert
- **Test Impact**: Should be zero (pure optimization)

## Implementation Plan

1. Create baseline benchmark
2. Implement caching in Sequence
3. Benchmark - if improvement, continue; if not, revert and stop
4. Implement caching in Alternative (if Step 3 succeeded)
5. Benchmark - keep only if improvement
6. Implement caching in Named (if Step 5 succeeded)
7. Final benchmark and analysis
8. Run full test suite

## Success Criteria

- At least 1% measurable improvement in benchmarks
- Zero test regressions
- Code remains readable and maintainable

## Benchmark Methodology

Use the existing JSON parser benchmark:
- Warmup: 3 iterations
- Test: 100 iterations
- Measure: iterations/second
- Variance threshold: Must be >1% outside noise margin

---

**Status**: Ready for implementation
**Created**: October 24, 2025
**Estimated Effort**: 1 hour
**Estimated Impact**: 0.5-3%
