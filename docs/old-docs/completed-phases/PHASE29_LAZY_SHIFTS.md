# Phase 29: Lazy Position Shifts for O(1) Edit Costs

## Summary

Implemented GPeg-style edit tracking with lazy position shifts, enabling O(1) cost for input edits instead of O(n) cache rebuilds.

## Implementation

### EditTracker Class
Created `lib/parslet/edit_tracker.rb` with:
- Edit recording: insertions (+delta) and deletions (-delta) at positions
- Lazy interval shifting: O(1) to record edit, O(k) to shift interval where k = number of edits
- Smart invalidation: intervals overlapping with edits are invalidated

### Key Operations

#### Recording Edits
```ruby
tracker = Parslet::EditTracker.new
tracker.insert(10, 5)   # Insert 5 chars at position 10
tracker.delete(20, 3)   # Delete 3 chars at position 20
```

#### Shifting Intervals
```ruby
# Original interval [100, 200)
# After insert(50, 20): shifts to [120, 220)
# After delete(80, 10): shifts to [110, 210)
shifted = tracker.shift_interval(100, 200)
# => [110, 210]
```

#### Invalidation Rules
1. **Edit inside interval**: Invalidate (cached result no longer valid)
2. **Edit before interval**: Shift both boundaries by delta
3. **Edit after interval**: No shift needed
4. **Invalid result**: Return nil if shifted interval becomes invalid

### Integration with Context

Modified `lib/parslet/atoms/context.rb`:
- EditTracker created when interval_cache enabled
- Ready for incremental parsing scenarios
- Zero-length edits properly handled (no-op)

## Test Coverage

Created `spec/parslet/edit_tracker_spec.rb` with 28 comprehensive tests:
- Basic operations (insert, delete, shift_interval)
- Edit position cases (before, inside, after interval)
- Multiple edit sequences
- Invalidation conditions
- Edge cases (zero-length, negative positions)
- All tests passing ✓

## Key Features

### 1. O(1) Edit Recording
```ruby
# Record edit: O(1)
tracker.insert(position, length)

# No need to rebuild cache immediately!
```

### 2. Lazy Shifting
```ruby
# Shift only when needed: O(k) where k = edit count
shifted_interval = tracker.shift_interval(low, high)
```

### 3. Smart Invalidation
```ruby
# Automatically detect invalid intervals
if tracker.invalidates?(low, high)
  # Interval overlaps with edit - cannot reuse
  return nil
end
```

### 4. Zero-Length Handling
```ruby
# Zero-length edits are no-ops
tracker.insert(10, 0)  # Skipped during shift
tracker.delete(20, 0)  # Skipped during shift
```

## Architecture

### Edit Representation
```ruby
class Edit
  attr_reader :position  # Where edit occurred
  attr_reader :delta     # +N for insert, -N for delete
end
```

### Shift Algorithm
```
For each edit in chronological order:
  1. If delta == 0: skip (no-op)
  2. If position in [shifted_low, shifted_high): invalidate
  3. If position < shifted_low: shift both by delta
  4. If position >= shifted_high: no shift
  5. If result invalid (negative/inverted): invalidate
```

## Performance Analysis

### Time Complexity
- **Record edit**: O(1)
- **Shift interval**: O(k) where k = number of edits
- **Clear edits**: O(1)

### Space Complexity
- **Per edit**: O(1)
- **Total**: O(k) where k = number of edits

### Comparison with Naive Approach
| Operation | Naive (rebuild cache) | GPeg (lazy shift) |
|-----------|----------------------|-------------------|
| Edit input | O(n) cache rebuild | O(1) record edit |
| Query cache | O(1) lookup | O(k) shift + O(log n) query |
| Memory | O(n*m) full cache | O(k) edits + O(n*m) cache |

For incremental parsing:
- **Naive**: O(n) cost per edit where n = cache size
- **GPeg**: O(1) cost per edit, O(k) cost per query where k << n

## Integration Points

### Current Status
- ✓ EditTracker implemented and tested
- ✓ Integrated with Context
- ✓ All tests passing (486/486)
- ⏳ Not yet used in interval cache queries (Phase 30)

### Next Steps
The EditTracker is ready but not actively used yet. Full incremental parsing requires:

1. **Modify `try_with_interval_cache`** to:
   - Shift query intervals before lookup
   - Invalidate overlapping cached intervals
   - Update intervals after edits

2. **Add edit notification API**:
   ```ruby
   context.record_insert(position, length)
   context.record_delete(position, length)
   context.apply_edits  # Invalidate affected intervals
   ```

3. **Implement cache invalidation**:
   - Use interval tree's `query_overlapping`
   - Delete intervals that overlap with edits
   - Leverage lazy shifting for retained intervals

## Bug Fixes

### Zero-Length Edits
**Problem**: Zero-length edits were treated as overlapping
**Solution**: Skip edits with `delta == 0` in shift algorithm
**Tests**: Added specific tests for zero-length insertions/deletions

## File Changes

### New Files
- `lib/parslet/edit_tracker.rb` (110 lines)
- `spec/parslet/edit_tracker_spec.rb` (213 lines)

### Modified Files
- `lib/parslet/atoms/context.rb`
  - Added EditTracker initialization
  - +2 lines (require + instantiation)

## Conclusions

### Achievements
1. ✓ Edit tracking implemented with O(1) recording
2. ✓ Lazy position shifts implemented
3. ✓ Comprehensive test coverage (28 tests)
4. ✓ Zero breaking changes (486/486 tests pass)
5. ✓ Foundation ready for incremental parsing

### Lessons Learned
1. Zero-length edits need special handling
2. Invalidation logic must be precise for correctness
3. Chronological edit order critical for correct shifting
4. Test coverage prevents subtle edge case bugs

### Architecture Quality
- Clean separation of concerns
- Self-contained EditTracker class
- Easy to integrate with interval tree
- Minimal overhead when not in use

## GPeg Paper Alignment

Implementing sections from Yedidia (SLE 2021):
- ✓ **Section 3.1**: Interval tree data structure (Phase 27)
- ✓ **Section 3.2**: Interval-based memoization (Phase 28)
- ✓ **Section 3.3**: Lazy position shifts (Phase 29) ← **COMPLETE**
- ⏳ **Section 3.4**: Tree memoization (Phase 30)

Progress: 3/4 major GPeg techniques implemented.

## Usage Example (Future)

```ruby
# Create parser with interval cache
parser = MyParser.new
context = Parslet::Atoms::Context.new(reporter, interval_cache: true)

# Initial parse
result1 = parser.parse("hello world", context: context)

# Edit the input
context.record_insert(6, 5)  # Insert "there" at position 6
# Input now: "hello there world"

# Incremental re-parse (reuses unaffected cache entries)
result2 = parser.parse("hello there world", context: context)
# Only re-parses affected regions, reuses rest from cache
```

This completes Phase 29. The EditTracker is implemented, tested, and integrated. Phase 30 will activate it for actual incremental parsing scenarios.
