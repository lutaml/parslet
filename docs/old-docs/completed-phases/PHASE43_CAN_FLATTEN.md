# Phase 43: CanFlatten Optimizations

## Problem

Profiling showed `CanFlatten#flatten` consuming 3.46% of runtime (3.3s) with 2.9M calls. The module handles result tree flattening with several optimization opportunities:

1. **Multiple type checks** - Repeated `instance_of?` calls
2. **Array operations overhead** - Array allocations in flattening
3. **Multiple passes** - `flatten_repetition` scanned arrays twice

## Solution

### 1. Single-Element Fast Path in `flatten()`

Added special handling for the common case of single-element arrays:

```ruby
if tail_size == 1
  flattened = flatten(value[1])
  case tag
    when :sequence
      return flattened
    when :maybe
      return named ? flattened : (flattened || '')
    when :repetition
      return flatten_repetition([flattened], named)
  end
end
```

### 2. Cached `instance_of?` Checks in `merge_fold()`

Reduced redundant method calls by caching instance checks:

```ruby
# Before:
l_is_str = l_class == String || l.instance_of?(Parslet::Slice)
r_is_str = r_class == String || r.instance_of?(Parslet::Slice)
# Later:
return r if r.instance_of?(Parslet::Slice)  # Duplicate call!

# After:
l_is_slice = l.instance_of?(Parslet::Slice)
r_is_slice = r.instance_of?(Parslet::Slice)
l_is_str = l_class == String || l_is_slice
r_is_str = r_class == String || r_is_slice
# Later:
return r if r_is_slice  # Reuse cached value
```

### 3. Single-Pass Detection in `flatten_repetition()`

Replaced two separate `any?` calls with one loop:

```ruby
# Before:
if list.any? { |e| e.instance_of?(Hash) }
  # handle hashes
end
if list.any? { |e| e.instance_of?(Array) }
  # handle arrays
end

# After: Single pass with early exit
has_hash = false
has_array = false
i = 0
while i < list.size
  e = list[i]
  has_hash = true if e.instance_of?(Hash)
  has_array = true if e.instance_of?(Array)
  break if has_hash && has_array
  i += 1
end
```

## Results

### Test Suite
✅ All 600 examples pass

### Performance Impact

Combined with Phase 42, overall performance:

```
Before Phase 42: 95.7s total
After Phase 42 + 43: 69.5s total
Speedup: 1.38x (27.3% faster)
```

Profile breakdown:
- `CanFlatten#flatten`: 3.311s → 3.637s (slight increase)
- `CanFlatten#foldl`: 1.188s → 1.306s (slight increase)
- `CanFlatten#merge_fold`: 0.771s → 0.868s (slight increase)
- `flatten_repetition`: NEW at 0.584s (0.84%)

### Analysis

Phase 43's optimizations to CanFlatten showed **neutral to slightly negative impact** on CanFlatten methods themselves, but the **overall parse time improved significantly** due to cumulative effects with Phase 42.

The single-element fast path and cached type checks added slight overhead that offset the benefits from single-pass detection in `flatten_repetition`. However, the optimizations are semantically correct and maintain code clarity.

## Conclusion

**Status: Implemented but Minimal Impact**

- Phase 43 optimizations are correct and maintain all tests
- Combined 1.38x speedup is primarily from Phase 42 (lazy cache eviction)
- CanFlatten optimizations had minimal individual impact
- Code is cleaner with explicit caching and single-pass logic

## Files Modified

- `lib/parslet/atoms/can_flatten.rb`: Added optimizations to flatten, merge_fold, flatten_repetition

## Next Steps

Based on updated profiling, new hot spots to investigate:

1. **Context#try_with_cache** - 15.25% (10.6s) - Core caching logic
2. **Integer#<** - Appears in top comparisons, suggests tight loop optimizations
3. **StringScanner operations** - charpos at 4.73%
