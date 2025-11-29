# Phase 58: Deep Allocation Analysis and Recommendations

## Executive Summary

After completing frozen constants optimization (Phases 57a-c), we've hit diminishing returns. The allocation profiling reveals the **real bottleneck** and suggests fundamentally different approaches are needed.

## Current State (Post Phase 57c)

### Allocation Profile
```
Total: 406 objects/parse

Breakdown:
- Arrays:   196/parse (48.2%) ← PRIMARY TARGET
- Strings:  100/parse (24.6%) ← SECONDARY TARGET
- Objects:   64/parse (15.7%)
- Hashes:    27/parse (6.6%)
- Other:     19/parse (4.7%)
```

### Performance
- JSON Parser: 0.086 MB/sec (target: 5.0 MB/sec)
- Calc Parser: 0.1308 MB/sec
- Gap to target: 97.4%

### What We've Tried
- **Frozen Constants (Phases 57a-c):** Reduced ~2-7 arrays/parse (1-3.5%)
- **Result:** Within measurement variance, diminishing returns

## Deep Dive: Where Do Allocations Come From?

### 1. Result Arrays (196 arrays/parse)

**Source:** Every atom operation returns `[success, value]` or `[false, cause]`

**Breakdown:**
- Success results: ~150/parse (76%)
- Failure results: ~46/parse (24%)

**Why This Happens:**
```ruby
# Every single atom does this:
def try(source, context, consume_all)
  # ... parsing logic ...
  return [true, value]   # or [false, cause]
end
```

**Critical Insight:** With 406 total objects and 196 result arrays, we're creating **1 result array per 2 total objects**. This is the dominant allocation pattern.

### 2. String Allocations (100 strings/parse)

**Sources:**
1. **Slice objects** (~60 strings): Every matched text creates a Parslet::Slice
2. **Error messages** (~30 strings): Generated during failed parse attempts
3. **Tag symbols to strings** (~10 strings): Symbol conversions

**Example:**
```ruby
str('hello').parse('hello')  # Creates Slice with @str = 'hello'
```

### 3. Object Allocations (64 objects/parse)

**Sources:**
1. **Slice objects** (~50 objects): Parslet::Slice wraps matched text
2. **Position objects** (~10 objects): Source position tracking
3. **Cause objects** (~4 objects): Error tracking

## Why Previous Approaches Have Limits

### Result Objects (Phase 58 - ABANDONED)
**Idea:** Replace `[success, value]` with `Result.new(success, value)`

**Why It Won't Work:**
- Replaces 196 arrays with 196 objects
- Same allocation count, just different object type
- No GC benefit
- Added method call overhead

**Verdict:** ❌ Abandoned

### More Frozen Constants (Phase 57d - DIMINISHING RETURNS)
**Idea:** Add constants for every common pattern

**Why It Won't Work:**
- Only helps with exact matches (empty arrays, nil, etc.)
- Adds conditional overhead in hot path
- Most arrays contain unique values (Slices, parsed data)
- Phase 57c already showed negative performance impact

**Verdict:** ❌ Reached practical limit

## Promising Optimization Strategies

### Strategy 1: Object Pooling for Result Arrays ⭐⭐⭐

**Concept:** Reuse result arrays instead of allocating new ones

**Implementation:**
```ruby
class Parslet::Atoms::Context
  def initialize(error_reporter)
    @result_pool = Array.new(200) { [nil, nil] }
    @pool_index = 0
  end

  def get_result(success, value)
    result = @result_pool[@pool_index]
    @pool_index = (@pool_index + 1) % 200
    result[0] = success
    result[1] = value
    result
  end
end
```

**Benefits:**
- Eliminate 180+ array allocations per parse (92% reduction)
- Reuse same 200 arrays across all parses
- Minimal code changes

**Risks:**
- Array lifetime management
- Thread safety (need per-thread pools)
- Subtle bugs if arrays escape pool

**Estimated Impact:** 30-40% performance improvement
**Estimated Effort:** 4-6 hours
**Risk Level:** Medium-High

### Strategy 2: Reduce Slice Allocations ⭐⭐

**Concept:** Slice objects create both object and string allocations

**Current:**
```ruby
class Parslet::Slice
  def initialize(string, offset, str)
    @string = string  # Original source
    @offset = offset  # Position
    @str = str        # Matched substring ← ALLOCATION
  end
end
```

**Optimization:**
- Delay @str creation until actually needed (lazy evaluation)
- Most Slices are only used for position tracking
- Only create string when #to_s or #str is called

**Benefits:**
- Eliminate 40-50 string allocations per parse
- Reduce 40-50 Slice object allocations

**Risks:**
- Changed Slice behavior
- Need careful testing

**Estimated Impact:** 10-15% performance improvement
**Estimated Effort:** 2-3 hours
**Risk Level:** Medium

### Strategy 3: Memoize Error Messages ⭐

**Concept:** Error messages are repeatedly constructed

**Current:**
```ruby
def error_msgs
  @error_msgs ||= {
    failed: "Expected #{str.inspect}, but got"
  }
end
```

**Optimization:**
- Pre-generate all error messages at atom creation
- Freeze error message strings
- Avoid string interpolation in hot path

**Benefits:**
- Eliminate 20-30 string allocations
- Faster error reporting

**Risks:**
- Low - isolated change

**Estimated Impact:** 5-8% performance improvement
**Estimated Effort:** 1-2 hours
**Risk Level:** Low

### Strategy 4: Result Array Rewrite (Risky but High Impact) ⭐⭐⭐⭐

**Concept:** Change internal API to pass result via context instead of return value

**Current:**
```ruby
def try(source, context, consume_all)
  # ...
  return [true, value]
end

success, value = atom.try(source, context, false)
```

**New:**
```ruby
def try(source, context, consume_all)
  # ...
  context.success(value)  # Stores in context
  return true
end

if atom.try(source, context, false)
  value = context.result_value
end
```

**Benefits:**
- Eliminate ALL result array allocations (196/parse)
- Context can use single mutable result slot
- No allocations at all

**Risks:**
- Major API change
- Requires changing ALL atoms
- Complex migration
- High bug potential

**Estimated Impact:** 40-50% performance improvement
**Estimated Effort:** 10-15 hours
**Risk Level:** High

## Recommended Optimization Roadmap

### Phase 58: Low-Hanging Fruit (Low Risk, Quick Wins)
1. **Memoize error messages** (1-2 hours, 5-8% gain)
2. **Test and measure**

### Phase 59: Medium Impact (Medium Risk, Good ROI)
1. **Lazy Slice string creation** (2-3 hours, 10-15% gain)
2. **Test thoroughly**
3. **Measure impact**

### Phase 60: High Impact (High Risk, Major Refactor)
1. **Object pooling for result arrays** (4-6 hours, 30-40% gain)
2. **Extensive testing**
3. **Performance validation**

### Phase 61: Maximum Impact (Highest Risk)
1. **Result-via-context API** (10-15 hours, 40-50% gain)
2. **Only if previous phases insufficient**

## Alternative: Profile-Guided Optimization

Instead of speculating, profile a REAL parser to see actual hotspots:

```bash
ruby -r stackprof benchmark/profile_with_stackprof.rb
```

This would show:
- Which atoms allocate most
- Which methods are called most frequently
- Where actual time is spent

**Recommendation:** Do this BEFORE attempting high-risk optimizations.

## Conclusion

**For immediate next step:**
1. Run detailed profiling to confirm allocation sources
2. Implement Phase 58 (error message memoization) - safe, quick win
3. Based on results, decide between lazy Slices or object pooling

**Current frozen constants work (Phases 57a-c) has value:**
- Established safe optimization pattern
- Proved we can make changes without breaking tests
- Identified that incremental constant additions hit limits
- Data shows we need architectural changes for real impact

**The 70% GC overhead can only be addressed by:**
- Reducing allocations by 60%+ (need ~244 fewer objects/parse)
- This requires eliminating result arrays (196/parse) or
- Combination of result arrays (196) + strings (100) reduction

Ready to proceed with profiling-guided approach?
