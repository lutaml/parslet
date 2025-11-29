# Phase 26: Alternative Single-Element Fast Path - REJECTED

## Date
October 23, 2025

## Optimization Attempted
Add a fast path for single-element alternatives to avoid Alternative overhead.

## Implementation
```ruby
def try(source, context, consume_all)
  case alternatives.size
  when 1
    # Single alternative - just delegate directly to the parslet
    alternatives[0].apply(source, context, consume_all)
  when 2
    # ... existing code
```

## Rationale
When an Alternative has only one element, we should be able to bypass the Alternative logic entirely and just delegate to that single parslet.

## Test Results
- **Total Tests**: 438
- **Failures**: 24 (all in Parslet::Expression::Treetop module)
- **Success Rate**: 94.5%

## Failing Tests
All failures were in `spec/parslet/expression/treetop_spec.rb`:
- `exp("'abc'")` failing to parse "abc"
- `exp("'a' 'b'")` failing to parse "ab"
- `exp("[1-4]")` failing to parse "3"
- `exp("'a'+")` failing to parse "a"
- And 20 more similar failures

## Root Cause
The Treetop expression parser creates single-element Alternative instances as part of its parsing strategy. These Alternative wrappers serve a purpose in the Treetop expression system - they're not just redundant containers.

By unwrapping single-element alternatives, we break the expected behavior of the Treetop expression system which relies on the Alternative wrapper being present.

## Key Insight
This is similar to Phase 22's failure: **seeming redundancies in the parse tree often serve important purposes**.

Single-element alternatives are not bugs to be optimized away - they're intentional structures in certain parsing contexts (like Treetop expression parsing).

## Lessons Learned

### 1. Test Suite Coverage Matters
The main parslet tests passed, but the Treetop expression tests caught the issue. Comprehensive test coverage across all modules is critical.

### 2. Wrapper Objects May Not Be Redundant
Just because an Alternative has one element doesn't mean the Alternative wrapper is unnecessary. The wrapper itself may be semantically important.

### 3. Edge Cases in Parsers
Parser construction systems (like Treetop expressions) may create structures that look inefficient but are actually part of their design.

### 4. Performance vs Correctness
The performance gain from this optimization would be minimal (avoiding one case statement branch), but the correctness cost is high (breaking an entire parsing subsystem).

## Recommendation
**REJECT** this optimization.

Instead, if single-element alternatives are a performance concern, they should be avoided at construction time by the code creating the parsers, not optimized away at runtime.

## Alternative Approaches Considered

1. **Construction-Time Unwrapping**: Modify the `|` operator to return the parslet itself when creating a single-element alternative
   - **Risk**: May break code expecting Alternative type
   - **Benefit**: Avoids creating unnecessary wrappers

2. **Conditional Unwrapping**: Only unwrap in certain contexts
   - **Risk**: Complex conditional logic, hard to maintain
   - **Benefit**: Targeted optimization

3. **Do Nothing**: Accept that single-element alternatives are rare and the overhead is minimal
   - **Risk**: None
   - **Benefit**: Keep code simple and correct

**Decision**: Accept alternative #3 - do nothing.

## Performance Impact
N/A - optimization was rejected before benchmarking due to test failures.

## Related Rejections
- **Phase 20**: Re atom fast paths - Ruby's C-level regex already optimal
- **Phase 22**: Alternative simplification with Re merging - Complex construction-time inspection breaks invariants
- **Phase 26**: Alternative single-element fast path - Wrapper serves semantic purpose

## Pattern Emerging
Runtime fast paths based on counting elements work well (sequences of 1-3, alternatives of 2-3).
But unwrapping/simplifying based on content or element count at boundaries (0 or 1 elements) tends to break edge cases.

**Safe pattern**: Fast paths for common sizes (2-3 elements)
**Unsafe pattern**: Special handling for edge cases (0-1 elements)
