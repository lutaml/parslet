# Phase 46: Cut Operators Research - Grammar-Level Memory Optimization

## Status: 📚 RESEARCH & PLANNING

## Overview

After analyzing 5 PEG research papers, identified **Cut Operators** (Mizushima et al., 2010) as the most promising architectural optimization for Parslet. This aligns with the user's guidance about "higher architecture level" solutions.

## Research Summary

### Key Papers Analyzed

1. **GPeg (Yedidia & Chong, 2021)**: Fast Incremental PEG Parsing
   - ✅ Already implemented: Interval tree (Phase 27-28), Lazy shifts (Phase 29), Tree memoization (Phase 30)

2. **Mizushima et al. (2010)**: Packrat Parsers Can Handle Practical Grammars in Mostly Constant Space
   - ⭐ **HIGHLY RELEVANT** - Cut operators for O(1) space
   - Not yet implemented in Parslet
   - Compatible with our architecture

3. **Ford (2002)**: Packrat Parsing (Original)
   - ✅ Foundation already in place

4. **Warth et al. (2008)**: Left Recursion Support
   - ❌ Not needed (Parslet doesn't support left recursion, not required for our use cases)

5. **Umeda & Maeda (2021)**: Multiple Left-Recursive Calls
   - ❌ Not applicable (advanced left recursion, not needed)

## Cut Operators Concept

### The Problem

**Current State**: Packrat parsers require O(n) space for memoization
- Memory grows linearly with input size
- Phase 42 reduced this with eviction, but still O(n)
- For 332KB Pascal file: ~20MB heap just for cache

**The Architectural Solution**: Cut operators (↑)

### How Cut Operators Work

Cut operators instruct the parser to **discard backtrack information** at strategic points.

**Example Without Cuts**:
```
S ← "if" "(" E ")" S ("else" S)?
  / "while" "(" E ")" S
  / "print" "(" E ")" S
```

After matching "if", the parser saves backtrack information for "while" and "print" alternatives. But once "if" succeeds, we'll **never** need those alternatives.

**Example With Cuts**:
```
S ← "if" ↑ "(" E ")" S ("else" S)?
  / "while" ↑ "(" E ")" S
  / "print" ↑ "(" E ")" S
```

The ↑ operator says: "After 'if' succeeds, discard all backtrack info for other alternatives."

### Memory Impact

**Key Observation**: When backtrack stack is empty at position n, **all cache entries before n can be discarded**.

Cut operators help empty the backtrack stack, enabling aggressive cache pruning.

**Result**: Space usage drops from O(n) to **O(1)** (mostly constant space).

### Automatic Insertion

Mizushima presents two algorithms for automatic cut insertion:

**AC-FIRST**: Insert cuts in ordered choices
- Based on FIRST set analysis (like LL(1) parsing)
- If FIRST(e₁) ∩ FIRST(e₂) = ∅, can insert cut after e₁

**AC-Repetition**: Insert cuts in repetitions
- For patterns like e₁* e₂
- If FIRST(e₁) ∩ FIRST(e₂) = ∅, can optimize

**Empirical Results** (from paper):
- Java grammar: Constant ~4MB space (vs linear growth)
- JSON grammar: Constant ~2MB space (vs linear growth)
- XML grammar: 50% reduction in space

## Relevance to Parslet

### Why This Matters

1. **Architectural not Micro**: Exactly what user asked for
2. **Space Reduction**: Pascal parsing currently uses ~20MB cache, could drop to ~2-4MB
3. **Speed Improvement**: Less memory = better cache locality = faster parsing
4. **Grammar Analysis**: Uses FIRST sets, which we can compute

### Current Parslet Architecture Compatibility

**Compatible**:
- ✅ Backtrack stack exists (in Context via choice operators)
- ✅ Cache eviction mechanism exists (Phase 14, Phase 42)
- ✅ Position tracking exists
- ✅ Grammar structure analyzable

**Requires**:
- FIRST set computation for Parslet grammars
- Cut operator implementation
- Backtrack stack inspection
- Modified eviction strategy

## Implementation Strategy

### Phase 46a: FIRST Set Analysis

Implement FIRST set computation for Parslet atoms:

```ruby
module Parslet::Atoms
  class Base
    # Compute FIRST set - terminal atoms that can match first
    def first_set
      # Default: unknown
      Set.new
    end
  end

  class Str
    def first_set
      Set.new([self])
    end
  end

  class Sequence
    def first_set
      # FIRST of sequence is FIRST of first element
      # unless first can be empty, then include FIRST of second, etc.
      parslets.first.first_set
    end
  end

  class Alternative
    def first_set
      # FIRST of choice is union of all alternatives
      alternatives.map(&:first_set).reduce(&:union)
    end
  end
end
```

### Phase 46b: Cut Operator Implementation

Add cut operator to Parslet DSL:

```ruby
# In parser definition
rule(:statement) {
  str("if").cut >> str("(") >> expression >> str(")") >> statement |
  str("while").cut >> str("(") >> expression >> str(")") >> statement |
  str("print").cut >> str("(") >> expression >> str(")")
}
```

The `.cut` method marks a point where backtrack info can be discarded.

### Phase 46c: Automatic Cut Insertion

Analyze grammar and insert cuts automatically:

```ruby
class Parslet::Optimizer::CutInserter
  def optimize(grammar)
    # For each Alternative
    # - Compute FIRST sets
    # - If disjoint, insert cut
  end
end
```

### Phase 46d: Modified Cache Eviction

With cuts, we can be more aggressive about eviction:

```ruby
# In Context#try_with_cache
if @backtrack_stack.empty? && beg > @last_cut_position
  # Can safely discard ALL cache before beg
  @cache.delete_if { |pos, _| pos < beg }
  @last_cut_position = beg
end
```

## Expected Impact

### Conservative Estimate

Based on Mizushima's empirical results and our current profile:

**Space**:
- Current: ~20MB for 332KB Pascal file
- With cuts: ~2-4MB (5-10x reduction)

**Speed**:
- Better cache locality: 5-15% improvement
- Less GC pressure: 5-10% improvement
- **Total: 10-25% speedup** (conservative)

### Optimistic Estimate

If cuts enable more aggressive eviction:
- Space: <2MB (>10x reduction)
- Speed: 20-40% improvement from reduced memory operations

## Risks & Challenges

### Technical Challenges

1. **FIRST Set Computation**
   - Must handle all Parslet atom types
   - Must be conservative (over-approximate is safe)

2. **Cut Semantics**
   - Must not change parse results
   - Only affects performance, not semantics

3. **Automatic Insertion**
   - Complex analysis required
   - May not find all opportunities

### Implementation Risks

1. **Complexity**: More complex than Phase 42
2. **Test Coverage**: Must ensure no semantic changes
3. **Grammar Compatibility**: Some grammars may not benefit

## Alternative Approaches Considered

### 1. Pegof (C++ PEG Implementation)

Reviewed https://github.com/dolik-rce/pegof:
- C++ implementation, not Ruby
- Optimizations similar to what we've done
- No novel architectural insights for Parslet

**Verdict**: Not applicable (different language, similar optimizations)

### 2. Incremental Parsing (GPeg)

GPeg's incremental parsing (edit-aware):
- Requires tracking edits to input
- Parslet is not used for incremental parsing
- Complex to retrofit

**Verdict**: Not applicable (different use case)

### 3. Left Recursion Support

Warth/Umeda papers on left recursion:
- Parslet doesn't support left recursion
- Not needed for current use cases
- Would add complexity without benefit

**Verdict**: Not applicable (not needed)

## Recommendation

**PROCEED** with Cut Operators implementation:

1. ✅ Aligns with "higher architecture level" guidance
2. ✅ Proven technique (Mizushima's empirical results)
3. ✅ Compatible with current architecture
4. ✅ Significant potential impact (5-10x space, 10-25% speed)
5. ✅ Grammar-level solution (not micro-optimization)

## Implementation Plan

### Phase 46a: FIRST Set Analysis (1-2 days)
- Implement FIRST set computation
- Add tests for various atom types
- Validate against known grammars

### Phase 46b: Manual Cut Support (2-3 days)
- Add `.cut` method to DSL
- Implement backtrack stack tracking
- Implement cut-aware eviction
- Test with manual cuts in Pascal grammar

### Phase 46c: Automatic Cut Insertion (3-4 days)
- Implement AC-FIRST algorithm
- Implement AC-Repetition algorithm
- Add optimizer pass
- Benchmark improvements

### Phase 46d: Evaluation (1 day)
- Measure space reduction
- Measure speed improvement
- Compare with Phase 42 baseline
- Document results

**Total Estimate**: 7-10 days of implementation

## Next Steps

1. Read Mizushima paper in detail
2. Implement FIRST set computation
3. Create prototype with manual cuts
4. Benchmark and validate
5. If successful, implement automatic insertion

---

**Status**: Ready to begin implementation
**Risk Level**: Medium (new feature, but proven technique)
**Expected Impact**: High (5-10x space reduction, 10-25% speed improvement)
