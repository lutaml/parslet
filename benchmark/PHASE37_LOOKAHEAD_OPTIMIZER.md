# Phase 37: Lookahead Optimization

## Overview

Implemented AST-level lookahead optimization that simplifies redundant lookahead patterns while maintaining semantic equivalence. This is the fourth optimizer integrated into the automatic optimization framework.

## Implementation

### File: `lib/parslet/optimizer.rb`

Added `simplify_lookaheads` method that applies the following transformations:

1. **Double Negation**: `!(!x) => &x`
   - Two consecutive negative lookaheads become a positive lookahead
   - Based on logical equivalence: ¬¬P ≡ P

2. **Idempotent Positive**: `&(&x) => &x`
   - Nested positive lookaheads are redundant
   - Based on idempotence: P ∧ P ≡ P

3. **Negative of Positive**: `!(&x) => !x`
   - Negative lookahead of positive lookahead simplifies to negative lookahead
   - Based on logical equivalence: ¬(P ∧ true) ≡ ¬P

4. **Positive of Negative**: `&(!x) => !x`
   - Positive lookahead of negative lookahead simplifies to negative lookahead
   - Based on logical equivalence: ¬P ∧ true ≡ ¬P

### Integration

Modified `lib/parslet.rb` to include lookahead optimization in the automatic optimization pipeline:

```ruby
if self.class.respond_to?(:optimize_rules?) && self.class.optimize_rules?
  result = Parslet::Optimizer.simplify_quantifiers(result)
  result = Parslet::Optimizer.simplify_sequences(result)
  result = Parslet::Optimizer.simplify_choices(result)
  result = Parslet::Optimizer.simplify_lookaheads(result)  # Added
end
```

## Testing

### File: `spec/parslet/lookahead_optimizer_spec.rb`

Created comprehensive test suite with 19 tests covering:

1. **Idempotent Positive Lookahead** (2 tests)
   - Simple case: `&(&x) => &x`
   - Nested case: `&(&(&x)) => &x`

2. **Negative of Positive Simplification** (1 test)
   - `!(&x) => !x`

3. **Double Negation Simplification** (2 tests)
   - Simple: `!(!x) => &x`
   - Triple: `!(!(!x)) => !x`

4. **Recursive Optimization** (4 tests)
   - Lookaheads nested in named atoms
   - Lookaheads nested in alternatives
   - Lookaheads nested in repetitions
   - Lookaheads nested in sequences

5. **Positive of Negative Simplification** (1 test)
   - `&(!x) => !x`

6. **Preserving Semantics** (3 tests)
   - Single lookahead unchanged
   - Leaf atoms unchanged
   - Negative single lookahead unchanged

7. **Complex Scenarios** (2 tests)
   - Multiple levels of optimization
   - Alternating positive/negative patterns

8. **Structural Verification** (4 tests)
   - Verifies optimized AST structure correctness

### Integration Tests

Updated `spec/parslet/auto_optimize_spec.rb` with 3 additional tests:
- Double negation simplification
- Idempotent positive simplification
- Negative of positive simplification

## Results

- **Lookahead optimizer tests**: 19/19 passing
- **Auto-optimize tests**: 21/21 passing
- **Full test suite**: 600/600 passing
- **No regressions**: All existing tests continue to pass

## Backward Compatibility

- Opt-in via `optimize_rules!` class method
- No changes to parsers without explicit optimization enabled
- Maintains 100% semantic equivalence
- All optimizations preserve parsing behavior

## Benefits

1. **Cleaner AST**: Removes redundant lookahead nesting
2. **Improved Performance**: Fewer lookahead operations during parsing
3. **Better Readability**: Simplified lookahead patterns in generated parsers
4. **Composability**: Works with quantifier, sequence, and choice optimizers

## Example Usage

```ruby
class MyParser < Parslet::Parser
  optimize_rules!

  # These patterns are automatically simplified:
  rule(:double_neg) { str('a').absent?.absent? }  # => str('a').present?
  rule(:nested_pos) { str('b').present?.present? }  # => str('b').present?
  rule(:neg_of_pos) { str('c').present?.absent? }  # => str('c').absent?
end
```

## Technical Notes

- Uses visitor pattern for AST traversal
- Recursively optimizes nested structures
- Preserves all atom metadata (labels, captures, etc.)
- Handles complex nesting patterns correctly
- Integration order: quantifiers → sequences → choices → lookaheads
