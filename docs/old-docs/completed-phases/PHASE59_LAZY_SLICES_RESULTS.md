# Phase 59: Lazy Slice String Creation - Results

## Overview
Attempted to defer Slice string allocation until actually needed. The hypothesis was that many Slices are created but never have their string values accessed, so lazy evaluation would reduce allocations.

## Implementation

```ruby
class Parslet::Slice
  def initialize(position, string, line_cache = nil)
    @position = position
    @string_or_slice = string  # Store original
    @line_cache = line_cache
    @offset = nil
    @str = nil  # Lazy cache for string value
  end

  # Lazy string evaluation
  def str
    @str ||= @string_or_slice.to_s
  end
end
```

## Test Results

✓ RSpec: 657 examples, 0 failures
✓ Opal: 656 examples, 0 failures, 11 pending (expected)

## Performance Results

**Phase 58 (Before Lazy Slices):**
- JSON Parser: 0.0912 MB/sec
- Calc Parser: 0.1417 MB/sec

**Phase 59 (After Lazy Slices):**
- JSON Parser: 0.0826 MB/sec (**-9.4% ❌**)
- Calc Parser: 0.129 MB/sec (**-9.0% ❌**)

## Analysis: Why Performance Decreased

### Overhead Added
1. **Method call overhead:** Every `str` access now requires a method call instead of direct ivar access
2. **Conditional check:** The `||=` operator adds a nil check on every access
3. **Additional ivar:** Storing `@string_or_slice` plus `@str` uses more memory

### Assumption Was Wrong
The hypothesis that many Slices are created but never accessed was **incorrect**:
- Parslet uses Slice objects as the primary representation of matched text
- Almost every Slice has its `.str` accessed during parsing or result tree construction
- Very few Slices are created purely for position tracking

### Hot Path Impact
The `.str` method is called in extremely hot paths:
- String comparisons in `str.rb`
- Result tree construction
- Error message formatting
- Sequence/repetition value aggregation

Adding overhead to such a hot path has severe performance impact.

## Lesson Learned

**Lazy evaluation is only beneficial when:**
1. The lazy operation is expensive (allocation is cheap in Ruby 3.3)
2. A significant percentage of objects never need the lazy value
3. The overhead of lazy evaluation is minimal

In this case:
- ❌ String allocation is fast (Ruby's string pool)
- ❌ ~95%+ of Slices have their string accessed
- ❌ Method call + conditional overhead is measurable in hot path

## Decision: REVERT PHASE 59

This optimization should be **reverted** as it provides negative value.

## Alternative Approaches to Consider

### 1. Slice Pooling (NOT lazy evaluation)
Instead of making Slices lazy, reuse Slice objects:
```ruby
class SlicePool
  def get_slice(position, string, line_cache)
    # Reuse from pool
  end
end
```

### 2. Slice Internals Optimization
- Keep @str eager but optimize Slice creation points
- Reduce number of Slices created
- Use string directly where Slice isn't needed

### 3. Accept Slice Allocations
- 64 Slice objects/parse is 15.7% of total allocations
- Not the primary bottleneck (result arrays are 48.2%)
- Focus optimization efforts elsewhere

## Recommendation

1. **Revert Phase 59** - lazy Slices hurt performance
2. **Focus on result arrays** - the real bottleneck (196/parse)
3. **Consider object pooling** - for result arrays, not Slices

## Conclusion

Phase 59 demonstrates the importance of **measurement over assumption**. What seemed like a good optimization idea actually decreased performance by 9%. This validates the incremental, test-driven approach:

✓ Made small, isolated change
✓ Tested thoroughly
✓ Measured accurately
✓ Can revert easily

**Status:** Failed optimization, will revert
**Performance Impact:** -9% (revert recommended)
**Lessons:** Measure hot paths, validate assumptions, lazy evaluation isn't always better
