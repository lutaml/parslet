# Phase 48: First-Character Optimization - Critical Analysis

## Executive Summary

**RECOMMENDATION: REJECT**

After careful analysis, first-character optimization should be rejected for the following reasons:

1. **Str is already heavily optimized** (Phase 19 removed all regex overhead)
2. **Scanning overhead likely outweighs benefits** in common use cases
3. **Historical precedent**: Similar optimizations (Phase 20, Phase 44) were rejected
4. **Unused infrastructure exists** (@first_char stored but never used since Phase 31)

## Current State Analysis

### Existing Code

From `lib/parslet/atoms/str.rb` (lines 12-21):

```ruby
if @len == 1
  @char = @str
  @pat = nil
  @first_char = nil
else
  @pat = Regexp.new(Regexp.escape(str))
  @char = nil
  # Phase 31: Store first character for fast-scan optimization
  @first_char = @str[0]
end
```

**Observation**: `@first_char` has been stored since Phase 31 but never used in `try` method.

### Current Performance

Str atom performance (from Phase 19):

**Single-character strings**:
- Direct character comparison: `slice.str == @char`
- No regex, no scanning needed
- Already optimal

**Multi-character strings**:
- Direct string comparison: `slice.str == @str`
- Removed regex overhead in Phase 19
- Simple, fast, predictable

## Proposed Optimization Analysis

### The Idea

Use `String#index` to skip to potential match positions:

```ruby
# Instead of trying match at every position:
source.bytepos = 0, 1, 2, 3, 4, 5...

# Use scanning:
while idx = source.str.index(@first_char, source.bytepos)
  source.bytepos = idx
  # Try match
end
```

### When It Would Help

**Scenario 1: Keyword in large file**
```ruby
input = "var x = 1;\nvar y = 2;\n" * 1000 + "if z > 0"
pattern = str('if')
```

If searching for 'if' linearly, would try match at many positions.
With scanning, jump directly to 'i' characters.

**Scenario 2: Sparse token**
```ruby
input = "a" * 10000 + "target" + "b" * 10000
pattern = str('target')
```

Scanning would skip 10,000 'a' characters directly to 't'.

### Why It Won't Help in Parslet

#### Problem 1: PEG parsers aren't scanners

PEG parsers work sequentially:
- They parse from left to right
- Each position is tried according to grammar rules
- You can't just "skip ahead" to keywords

**Example**:
```ruby
grammar = (str('var') | str('if') | other_rules).repeat
```

Even if we could scan for 'if', we still need to try 'var' and other_rules at every position.

#### Problem 2: Scanning adds overhead

```ruby
# Current code (simple, fast):
slice = source.consume(@len)
return succ(slice) if slice.str == @str

# With scanning (more complex):
while idx = source.str.index(@first_char, source.bytepos)
  source.bytepos = idx
  slice = source.consume(@len)
  return succ(slice) if slice.str == @str
  source.bytepos += 1
end
```

**Overhead added**:
- `String#index` call (even if fast, it's an extra call)
- Loop management
- Extra position updates
- More complex error handling

**When overhead outweighs benefit**:
- Dense matches (common in structured formats)
- Short inputs (overhead dominates)
- Multi-character first chars that are common (e.g., space, 'a', 'e')

#### Problem 3: Grammar-level optimization needed

First-character optimization works best when applied at **grammar level**, not atom level.

**Example where it could work**:
```ruby
# Grammar that searches for specific keywords in free text
text_with_keywords = any.repeat >> str('IMPORTANT') >> any.repeat
```

Here, you could scan the entire input for 'IMPORTANT' first.

**But Parslet doesn't work this way**:
- Parslet grammars are compositional
- Atoms don't know larger context
- Would need optimizer to detect searchable patterns
- Very high complexity, uncertain benefit

### Historical Lessons

#### Phase 20: Re Fast Paths (REJECTED)

Attempted to add character checking before regex match.

**Result**: 1.4% to 30.5% SLOWER

**Lesson**: Don't second-guess Ruby's optimized C-level implementations.

#### Phase 44: Str/Re Caching (REJECTED)

Attempted to add memoization to Str and Re atoms.

**Result**: Overhead outweighed benefits in benchmarks.

**Lesson**: Simple operations should stay simple.

### Benchmark Predictions

Based on Phase 20 and 44 results, we predict:

**Dense matches scenario** (like JSON parsing):
- Overhead: +5-10% (extra method calls, loop management)
- Benefit: ~0% (matches are dense, scanning doesn't skip much)
- **Net: -5 to -10% performance**

**Sparse matches scenario** (searching for keyword):
- Overhead: +2-5% (method calls)
- Benefit: +10-50% (skipping positions)
- **Net: +5 to +45% performance**

**Overall assessment**:
- Real-world parsing is mostly dense
- Sparse scenarios are rare in typical PEG grammars
- **Average impact: -2 to +5%** (not worth complexity)

## Alternative Approaches

### 1. Grammar-Level Search Optimization

Instead of atom-level, detect search patterns in grammar:

```ruby
class SearchPattern < Base
  def initialize(target)
    @target = target
  end

  def try(source, context, consume_all)
    # Use String#index to find target
    # Then resume normal parsing
  end
end
```

**Pros**:
- Explicit opt-in for search scenarios
- Clear performance characteristics
- Doesn't complicate simple atoms

**Cons**:
- Requires new atom type
- User must identify search patterns
- Limited applicability

### 2. Post-Construction Analysis

Optimizer could detect patterns like:
```ruby
any.repeat >> str('keyword')
```

And transform to:
```ruby
SearchPattern.new('keyword')
```

**Pros**:
- Automatic optimization
- Clear separation of concerns

**Cons**:
- High complexity
- Uncertain benefit in real grammars

### 3. Documentation/Best Practices

Simply document that for search scenarios, users should structure grammars appropriately:

```ruby
# Instead of scanning entire input:
# any.repeat >> str('keyword') >> any.repeat

# Use bounded search:
# str('keyword') | (any >> rule(:search_for_keyword))
```

## Recommendation

**REJECT Phase 48** for the following reasons:

1. **Insufficient benefit**: Real-world parsing is mostly dense; sparse scenarios are rare
2. **Added complexity**: Increases code complexity in hot path (Str#try)
3. **Historical precedent**: Similar optimizations (Phase 20, 44) were rejected
4. **Architectural mismatch**: PEG parsing is sequential, not search-oriented
5. **Better alternatives exist**: Grammar-level solutions more appropriate

## Cleanup Required

Since `@first_char` has been stored but unused since Phase 31:

```ruby
# Remove from lib/parslet/atoms/str.rb:
- # Phase 31: Store first character for fast-scan optimization
- @first_char = @str[0]
```

This reduces memory footprint slightly and removes dead code.

## Lessons Learned

1. **Not all theoretical optimizations work in practice**
   - Scanning is fast, but PEG parsing isn't about scanning

2. **Keep hot paths simple**
   - Str is already optimized (Phase 19)
   - Adding complexity likely hurts more than helps

3. **Consider architecture before optimization**
   - Atom-level optimization wrong level for search patterns
   - Grammar-level or user-level solutions more appropriate

4. **Historical data guides decisions**
   - Phase 20 and 44 rejections showed overhead patterns
   - Similar patterns predicted here

## Conclusion

Phase 48 should be REJECTED. The optimization is theoretically sound but practically unsuitable for Parslet's architecture and typical use cases. The existing `@first_char` storage should be removed as dead code cleanup.

**Status**: REJECTED - First-character optimization inappropriate for PEG parser architecture
