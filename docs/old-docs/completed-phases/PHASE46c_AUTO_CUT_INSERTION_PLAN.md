# Phase 46c: Automatic Cut Insertion (AC-FIRST Algorithm)

**Status**: 🚧 PLANNING
**Date**: October 24, 2025

## Overview

Implement automatic cut insertion using the AC-FIRST algorithm from Mizushima et al. (2010). This will enable O(1) space complexity for well-formed PEG grammars without requiring manual cut placement.

## Goals

1. Automatically detect when alternatives have disjoint FIRST sets
2. Insert cuts after deterministic prefixes when safe
3. Enhance Alternative atom to prevent backtracking after cuts
4. Maintain conservative approach - only optimize when provably safe

## AC-FIRST Algorithm

### Core Concept

When alternatives in a choice have **disjoint FIRST sets**, we can safely insert a cut after matching the deterministic prefix, because no backtracking will be needed.

Example:
```ruby
# Original grammar
str('if') >> condition >> then_clause |
str('while') >> condition >> body |
str('print') >> expression

# FIRST sets:
# Alternative 1: {'if'}
# Alternative 2: {'while'}
# Alternative 3: {'print'}
# These are disjoint!

# Transformed with automatic cuts:
str('if').cut >> condition >> then_clause |
str('while').cut >> condition >> body |
str('print').cut >> expression
```

### Safety Condition

A cut can be safely inserted after parslet P if:
1. P is the prefix of an alternative
2. FIRST(P) is disjoint from FIRST sets of all other alternatives
3. P doesn't contain EPSILON (always consumes input)

## Implementation Plan

### Step 1: Disjoint FIRST Set Detection

**File**: `lib/parslet/first_set.rb`

Add helper methods:

```ruby
module Parslet::FirstSet
  # Check if two FIRST sets are disjoint
  def self.disjoint?(set1, set2)
    # Ignore EPSILON when checking disjointness
    real_set1 = set1.reject { |x| x == EPSILON }
    real_set2 = set2.reject { |x| x == EPSILON }
    (real_set1 & real_set2).empty?
  end

  # Check if all FIRST sets in a collection are mutually disjoint
  def self.all_disjoint?(sets)
    sets.combination(2).all? { |s1, s2| disjoint?(s1, s2) }
  end
end
```

**Tests**: Add to `spec/parslet/first_set_spec.rb`

### Step 2: Cut Insertion Transformer

**File**: `lib/parslet/optimizers/cut_inserter.rb`

New optimizer that analyzes alternatives and inserts cuts:

```ruby
class Parslet::Optimizers::CutInserter
  def optimize(parslet)
    # Use visitor pattern to traverse AST
    visitor = Parslet::AstVisitor.new do |atom|
      case atom
      when Parslet::Atoms::Alternative
        optimize_alternative(atom)
      else
        atom
      end
    end

    visitor.visit(parslet)
  end

  private

  def optimize_alternative(alt)
    alternatives = alt.alternatives
    first_sets = alternatives.map(&:first_set)

    # Only optimize if all FIRST sets are disjoint
    return alt unless Parslet::FirstSet.all_disjoint?(first_sets)

    # Insert cuts after deterministic prefixes
    optimized = alternatives.map do |alternative|
      insert_cut_if_safe(alternative)
    end

    Parslet::Atoms::Alternative.new(*optimized)
  end

  def insert_cut_if_safe(parslet)
    # For sequences, find the longest safe prefix
    if parslet.is_a?(Parslet::Atoms::Sequence)
      prefix = find_deterministic_prefix(parslet)
      if prefix && safe_to_cut?(prefix)
        # Wrap prefix with cut, keep rest of sequence
        return build_cut_sequence(parslet, prefix)
      end
    end

    # For other atoms, cut the whole thing if safe
    if safe_to_cut?(parslet)
      return parslet.cut
    end

    parslet
  end

  def find_deterministic_prefix(sequence)
    # Find longest prefix that doesn't include EPSILON
    parslets = sequence.parslets
    prefix_length = 0

    parslets.each do |p|
      break if p.first_set.include?(Parslet::FirstSet::EPSILON)
      prefix_length += 1
    end

    prefix_length > 0 ? parslets[0...prefix_length] : nil
  end

  def safe_to_cut?(parslet)
    first = parslet.first_set
    # Don't cut if EPSILON is in FIRST set (might not consume)
    !first.include?(Parslet::FirstSet::EPSILON)
  end

  def build_cut_sequence(sequence, prefix_parslets)
    prefix = if prefix_parslets.length == 1
      prefix_parslets.first
    else
      Parslet::Atoms::Sequence.new(*prefix_parslets)
    end

    remaining = sequence.parslets[prefix_parslets.length..-1]

    if remaining.empty?
      prefix.cut
    else
      Parslet::Atoms::Sequence.new(prefix.cut, *remaining)
    end
  end
end
```

**Tests**: `spec/parslet/cut_inserter_spec.rb`

### Step 3: Enhanced Alternative with Cut Awareness

**File**: `lib/parslet/atoms/alternative.rb`

Modify to track and respect cuts:

```ruby
def try(source, context, consume_all)
  # Track if we've encountered a cut
  cut_occurred = false
  cut_position = nil

  alternatives.each do |alt|
    # Save position before trying alternative
    pos = source.bytepos

    # Try the alternative
    success, value = alt.apply(source, context, consume_all)

    if success
      # Success - check if this branch had a cut
      if context.last_cut_position && context.last_cut_position > pos
        # Cut occurred in this branch - commit to this alternative
        # (Already handled by context.cut! cache eviction)
      end
      return [success, value]
    end

    # Failure - check if a cut occurred
    if context.last_cut_position && context.last_cut_position > pos
      # Cut occurred, so we can't backtrack to other alternatives
      # Return the failure immediately
      return [success, value]
    end

    # No cut - reset position and try next alternative
    source.bytepos = pos
  end

  # All alternatives failed
  context.err_at(
    "Failed to match #{alternatives.map { |a| a.to_s }.join(' / ')}",
    source
  )
end
```

**Challenge**: Need to access `last_cut_position` from context. Should enhance Context API.

### Step 4: Context API Enhancement

**File**: `lib/parslet/atoms/context.rb`

Make cut position queryable:

```ruby
attr_reader :last_cut_position

def cut_occurred_at?(position)
  @last_cut_position && @last_cut_position >= position
end

def clear_cut_marker
  @last_cut_position = 0
end
```

### Step 5: Integration with Optimizer

**File**: `lib/parslet/optimizer.rb`

Add cut insertion to optimization pipeline:

```ruby
def optimize(parslet)
  result = parslet

  # Existing optimizers
  result = @quantifier_optimizer.optimize(result)
  result = @sequence_optimizer.optimize(result)
  result = @choice_optimizer.optimize(result)
  result = @lookahead_optimizer.optimize(result)

  # NEW: Automatic cut insertion
  if @options[:auto_cut]
    result = Parslet::Optimizers::CutInserter.new.optimize(result)
  end

  result
end
```

## Testing Strategy

### Unit Tests

1. **Disjoint detection** (`spec/parslet/first_set_spec.rb`)
   - Test disjoint? helper
   - Test all_disjoint? helper
   - Edge cases: empty sets, EPSILON handling

2. **Cut insertion** (`spec/parslet/cut_inserter_spec.rb`)
   - Simple alternatives with disjoint FIRST sets
   - Sequences with deterministic prefixes
   - Alternatives with overlapping FIRST sets (no cuts)
   - Edge cases: EPSILON in FIRST, single alternative, etc.

3. **Alternative behavior** (`spec/parslet/atoms/alternative_spec.rb`)
   - Add tests for cut-aware backtracking
   - Verify cuts prevent trying other alternatives
   - Ensure normal backtracking still works without cuts

### Integration Tests

1. **Real grammars**
   - Test with statement grammar (if/while/print)
   - Test with JSON grammar
   - Test with expression grammars

2. **Performance**
   - Measure memory usage with auto-cuts
   - Compare with manual cuts
   - Verify O(1) space behavior

## Challenges & Solutions

### Challenge 1: Preserving Semantics

**Problem**: Automatic cuts must not change parse results

**Solution**:
- Only insert when FIRST sets are provably disjoint
- Conservative approach: when in doubt, don't insert
- Comprehensive tests comparing with/without auto-cuts

### Challenge 2: Nested Alternatives

**Problem**: Alternatives can be nested, cuts in inner alternatives affect outer ones

**Solution**:
- Visitor pattern handles recursion naturally
- Process bottom-up (inner alternatives first)
- Each alternative independently decides on cuts

### Challenge 3: Context State Management

**Problem**: Cut markers in context persist across alternatives

**Solution**:
- Clear cut marker at appropriate times
- Track cut position per alternative attempt
- Careful design of cut_occurred_at? API

### Challenge 4: Testing Complexity

**Problem**: Many edge cases and grammar structures to test

**Solution**:
- Start with simple cases (flat alternatives)
- Add complexity incrementally
- Use property-based testing if needed

## Success Criteria

1. ✅ Disjoint FIRST set detection works correctly
2. ✅ Cuts inserted only when safe (no semantic changes)
3. ✅ All existing tests still pass (no regressions)
4. ✅ New tests comprehensively cover cut insertion logic
5. ✅ Memory usage reduced for grammars with disjoint alternatives
6. ✅ Performance not degraded (cut insertion is optimization pass)

## Implementation Order

1. **Disjoint helpers** (easiest, foundation for rest)
2. **Cut inserter transformer** (core logic)
3. **Tests for inserter** (verify logic before integration)
4. **Alternative enhancement** (most delicate change)
5. **Tests for alternative** (ensure correctness)
6. **Integration** (add to optimizer)
7. **Full suite** (verify no regressions)
8. **Documentation** (usage guide)

## Timeline Estimate

- Step 1 (Disjoint helpers): 30 min
- Step 2 (Cut inserter): 2 hours
- Step 3 (Alternative enhancement): 2 hours
- Step 4 (Context API): 30 min
- Step 5 (Integration): 30 min
- Testing: 2 hours
- Documentation: 1 hour

**Total**: ~8-9 hours of focused work

## References

1. Mizushima et al. (2010) "Packrat Parsers Can Handle Practical Grammars in Mostly Constant Space"
   - Section 4: AC-FIRST algorithm
   - Section 5: Implementation details

2. Phase 46a: FIRST Set Analysis (completed)
   - Foundation for disjoint detection

3. Phase 46b: Manual Cut Support (completed)
   - Foundation for automatic insertion
