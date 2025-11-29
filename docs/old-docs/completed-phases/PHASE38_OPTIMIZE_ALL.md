# Phase 38: Optimize All Convenience Method

**Date**: October 23, 2025
**Status**: ✅ COMPLETE

## Overview

Added a convenience method `Parslet::Optimizer.optimize_all` that applies all optimizer passes in the recommended order. This simplifies the usage of the optimizer module.

## Motivation

Previously, to get full optimization benefits, users needed to manually apply each optimizer:

```ruby
parslet = Parslet::Optimizer.simplify_quantifiers(parslet)
parslet = Parslet::Optimizer.simplify_sequences(parslet)
parslet = Parslet::Optimizer.simplify_choices(parslet)
parslet = Parslet::Optimizer.simplify_lookaheads(parslet)
```

This is verbose and error-prone. Users might apply them in the wrong order or forget one.

## Implementation

Added a single method that applies all optimizations in the recommended order:

```ruby
def self.optimize_all(parslet)
  # Apply optimizations in order of impact and safety
  result = simplify_quantifiers(parslet)
  result = simplify_sequences(result)
  result = simplify_choices(result)
  result = simplify_lookaheads(result)
  result
end
```

## Usage

```ruby
# Before - manual optimization
parser = MyParser.new
parslet = parser.root
parslet = Parslet::Optimizer.simplify_quantifiers(parslet)
parslet = Parslet::Optimizer.simplify_sequences(parslet)
parslet = Parslet::Optimizer.simplify_choices(parslet)
parslet = Parslet::Optimizer.simplify_lookaheads(parslet)

# After - single call
parser = MyParser.new
parslet = parser.root
optimized = Parslet::Optimizer.optimize_all(parslet)
```

Or with `optimize_rules!`:

```ruby
class MyParser < Parslet::Parser
  optimize_rules!  # Already uses optimize_all internally

  rule(:expr) { str('a').repeat(1,1) >> (str('b') | str('b')) }
end
```

## Optimization Order

The method applies optimizations in this specific order for maximum benefit:

1. **simplify_quantifiers** - Removes redundant repetitions first
2. **simplify_sequences** - Merges strings and flattens sequences
3. **simplify_choices** - Deduplicates and flattens alternatives
4. **simplify_lookaheads** - Simplifies nested lookaheads last

This order ensures that earlier optimizations create opportunities for later ones.

## Test Results

### Ruby Tests
- Before: 600/600 passing ✅
- After: 600/600 passing ✅
- Regressions: 0

### Opal Tests
- Before: 599/599 passing ✅
- After: 599/599 passing ✅
- Regressions: 0

## Benefits

1. **Simplicity**: Single method call vs 4 separate calls
2. **Correctness**: Guaranteed correct order of optimizations
3. **Maintainability**: If we add new optimizers, they can be integrated here
4. **Consistency**: All code uses the same optimization pipeline

## Impact

- **Code size**: +8 lines
- **Performance**: No change (same optimizations, just easier to use)
- **API**: Additive only (no breaking changes)
- **Documentation**: Clearer path for users

## Future Considerations

This method provides a stable interface for optimization. As we add more optimizer passes (e.g., character class merging, rule inlining), they can be integrated into `optimize_all` while maintaining backward compatibility.

Users who need fine-grained control can still call individual optimizer methods directly.

## Related Phases

- Phase 32: Quantifier Simplification
- Phase 34: Sequence Optimizer
- Phase 36: Choice Optimizer
- Phase 37: Lookahead Optimizer
- Phase 33: Auto-optimize (uses optimize_all internally)
