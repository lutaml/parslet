# Phase 22: Alternative Simplification - REJECTED

## Date
2025-10-23

## Objective
Implement character class merging for adjacent Re atoms in alternatives, as suggested by the pegof optimizer research.

## Approach Attempted
Modified the `|` operator in `Alternative` class to:
1. Flatten nested alternatives (similar to Sequence)
2. Detect adjacent Re atoms with simple character classes
3. Merge them into a single Re with combined character class

Example:
```ruby
match('[a-c]') | match('[d-f]')  # => match('[a-f]')
```

## Implementation
Added logic to the `|` method to:
- Check if consecutive alternatives are Re atoms
- Use regex to detect simple character classes `[abc]` or `[a-z]`
- Merge character sets by combining and deduplicating characters

## Why It Failed
**Root cause**: The `|` operator is called during grammar construction, not just at runtime. At construction time, parslets may not be fully initialized or may be in intermediate states.

**Specific failure**: Test suite showed 86 failures with error:
```
NoMethodError: private method `try' called for an instance of Parslet::Atoms::Alternative
```

This indicates the optimization created invalid Alternative structures that couldn't be properly executed.

## Key Lessons

### 1. Construction-Time vs Runtime Optimizations
- **Safe**: Simple structural changes (flattening nested structures) during construction
- **Unsafe**: Complex logic that inspects or transforms parslet internals during construction

### 2. Grammar Construction is Fragile
The `|` and `>>` operators are called many times during grammar construction. Any complex logic here risks breaking the construction process.

### 3. Alternative Approach Needed
Character class merging would need to be implemented as a **post-construction optimization pass**, similar to how the `Accelerator` works:
1. Let grammar construct normally
2. Walk the parslet tree after construction
3. Find and merge adjacent Re atoms
4. Return optimized tree

This is significantly more complex and requires:
- Tree walking infrastructure
- Understanding of all parslet atom types
- Careful preservation of semantics
- Comprehensive testing

## Comparison to Successful Phases

### Phase 21 (Sequence Flattening) - SUCCESS
```ruby
def >>(parslet)
  if parslet.is_a?(Parslet::Atoms::Sequence)
    self.class.new(* @parslets + parslet.parslets)
  else
    self.class.new(* @parslets + [parslet])
  end
end
```
**Why it worked**: Simple structural change, no complex logic, doesn't inspect internals.

### Phase 22 (Alternative Simplification) - FAILURE
```ruby
def |(parslet)
  # Complex logic here
  new_alts = ...
  simplified = []
  # Iterate, check types, merge patterns
  while i < new_alts.size
    if curr.is_a?(Parslet::Atoms::Re) && can_merge_re?(curr)
      # More complex logic
    end
  end
  self.class.new(*simplified)
end
```
**Why it failed**: Too complex, inspects internals, modifies structure in non-trivial ways.

## Conclusion
**Verdict**: REJECTED

Alternative simplification, while theoretically beneficial, requires a post-construction optimization infrastructure that doesn't currently exist in Parslet. The inline approach breaks grammar construction.

## Recommendations

### Short-term
Focus on simpler optimizations that don't require complex construction-time logic:
- Position caching (already done in Source)
- Simple structural optimizations (like sequence flattening)
- Runtime optimizations in `try` methods

### Long-term
If character class merging is still desired, implement it as part of a comprehensive optimization framework:
1. Create a `Parslet::Optimizer` class
2. Implement tree walking
3. Add pattern-specific optimizations
4. Provide opt-in optimization pass

This is a significant undertaking that goes beyond incremental optimization.

## Impact
No performance impact - changes were reverted before commit.
