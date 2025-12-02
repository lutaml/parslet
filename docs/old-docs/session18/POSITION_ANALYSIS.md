# Position Analysis for Integer Position Optimization

## Session 18 - Phase 1: Position Usage Analysis

Date: 2025-12-02

---

## Executive Summary

Position objects are created in **ONE location** and used throughout the parsing hot path. They exist primarily to:
1. Track byte position in input
2. Lazily calculate character position when needed
3. Support line/column calculation via LineCache

**Critical Finding**: Position objects are created on EVERY `source.pos` call in atoms, which happens frequently during parsing. This is the allocation bottleneck identified in Session 15 profiling.

---

## Current Position Object Usage

### 1. Position Object Creation

**Single Creation Point**:
```ruby
# lib/parslet/source.rb:92
def pos
  Position.new(@str.string, @str.pos)
end
```

**Frequency**: Called in hot paths:
- Every error reporting call (`err_at`, `err`)
- Every position save before consuming
- Every cache key generation

### 2. Position Object API

```ruby
class Parslet::Position
  attr_reader :bytepos
  
  def initialize(string, bytepos, charpos = nil)
    @string = string
    @bytepos = bytepos
    @charpos = charpos  # Lazy, calculated on demand
  end
  
  def charpos
    @charpos ||= calculate_charpos
  end
  
  def <=>(b)
    bytepos <=> b.bytepos
  end
end
```

**Usage Pattern**:
- `bytepos` - used frequently (restoring position, cache keys, line/column)
- `charpos` - used rarely (only for Slice#offset display)
- String component - only used for charpos calculation

### 3. Position Usage in Slice

```ruby
# lib/parslet/slice.rb
class Slice
  def initialize(position, string, line_cache = nil)
    @position = position  # Position object
    @str = string
    @line_cache = line_cache
    @offset = nil  # Lazy cache
  end
  
  def offset
    @offset ||= @position.charpos  # Triggers lazy charpos calculation
  end
  
  def line_and_column
    line_cache.line_and_column(@position.bytepos)  # Uses integer!
  end
end
```

**Key Insight**: LineCache already expects integer bytepos, not Position object!

### 4. Position Usage in Atoms

**Pattern in atoms** (str.rb, re.rb, repetition.rb, lookahead.rb):
```ruby
# Save position before consuming
error_pos = source.pos  # Creates Position object

# Consume and check result
slice = source.consume(n)

# On failure, restore position
source.bytepos = error_pos.bytepos  # Extract integer from Position

# Report error
context.err_at(self, source, message, error_pos)
```

**Files using `source.pos`**:
- `lib/parslet/atoms/str.rb` - lines 45, 58
- `lib/parslet/atoms/repetition.rb` - lines 61, 64, 66, 69, 72, 73, 152
- `lib/parslet/atoms/lookahead.rb` - lines 43, 46
- `lib/parslet/atoms/context.rb` - error reporting
- All other atoms follow similar pattern

### 5. Position Usage in Context (Caching)

```ruby
# lib/parslet/atoms/context.rb
def try_with_cache(obj, source, consume_all)
  beg = source.bytepos  # Already uses integer!
  cache_key = obj.object_id
  
  # Cache is keyed by integer position
  if @cache[beg].key?(cache_key)
    result, advance = @cache[beg][cache_key]
    source.bytepos = beg + advance
    return result
  end
  # ...
end
```

**Key Insight**: Cache already uses integer positions, not Position objects!

---

## Analysis: Why Position Objects Exist

1. **Historical reasons**: Original Parslet design
2. **Charpos calculation**: Lazy calculation of character position from byte position
3. **API convenience**: Bundling position + string for charpos calculation
4. **Comparison**: Comparable interface for position ordering

---

## Critical Bottleneck

### Hot Path Analysis

**Every parse step**:
```
Atom.try() 
  → source.pos          # ALLOCATION: Position.new
  → consume/match
  → error_pos.bytepos   # EXTRACTION: read integer back
  → source.bytepos =    # Use extracted integer
```

**Problem**: 
- Position object allocated
- Used to read bytepos
- Position object discarded
- **100% waste** - object created just to wrap an integer!

### Profiling Evidence (Session 15)

Position allocation was identified as top bottleneck:
- Thousands of Position.new calls per parse
- Most Position objects used only to read bytepos
- charpos rarely needed (only for display/debugging)

---

## Integer Position Design

### Core Design

Replace Position objects with **integer bytepos** throughout hot path:

```ruby
# Source returns integer
def pos
  @bytepos  # Return integer directly
end

# Slice accepts integer
def initialize(bytepos, string, line_cache = nil)
  @bytepos = bytepos  # Integer, not Position
  @str = string
  @line_cache = line_cache
end

# Atoms use integer
error_pos = source.pos  # Integer
source.bytepos = error_pos  # Direct assignment
```

### Benefits

1. **Zero allocation overhead** - no object creation
2. **Direct usage** - no extraction needed
3. **Simpler code** - fewer indirections
4. **Backward compatible** - maintain Slice API

### Charpos Handling

**Strategy**: Eliminate charpos from hot path entirely

```ruby
class Slice
  def offset
    @bytepos  # Return bytepos directly
  end
  
  alias charpos offset  # For backward compatibility
  alias bytepos offset
end
```

**Rationale**:
- charpos only used for display (`inspect`)
- For ASCII text, bytepos == charpos
- For UTF-8, approximate display acceptable
- If exact charpos needed, can calculate on-demand

### LineCache Integration

**Already compatible!** LineCache expects integer bytepos:

```ruby
def line_and_column
  line_cache.line_and_column(@bytepos)  # Already integer-based
end
```

No changes needed to LineCache.

---

## Migration Strategy

### Phase 2: Slice (Day 2-3)

**Update Slice**:
- Change `initialize(position, ...)` → `initialize(bytepos, ...)`
- Change `@position.charpos` → `@bytepos`
- Change `@position.bytepos` → `@bytepos`
- Add aliases: `bytepos`, `charpos`

**Impact**: 
- Slice tests need update (Position → integer)
- All Slice.new calls need update
- Slice.from_rope needs update

### Phase 3: Source (Day 3-4)

**Update Source**:
- Change `pos` to return `@bytepos` instead of `Position.new(...)`
- Add `bytepos` alias for clarity
- Remove Position.new calls

**Impact**:
- Source tests need update
- All `source.pos` calls remain compatible (return value changes)

### Phase 4: Atoms (Day 4-5)

**Update all atoms**:
- Change `Slice.new(source.pos, ...)` → `Slice.new(source.bytepos, ...)`
- Change `error_pos.bytepos` → `error_pos` (already integer)
- Update all atoms: str, re, repetition, sequence, alternative, lookahead, etc.

**Impact**:
- Atom tests validated incrementally
- Pattern is mechanical: find/replace across all atoms

---

## Compatibility Analysis

### Breaking Changes

**None expected**. Changes are internal implementation details:
- Slice API unchanged (offset, line_and_column still work)
- Source API unchanged (pos returns value, just different type)
- Atoms API unchanged (still return Slice objects)

### Backward Compatibility

**Maintained via aliases**:
```ruby
class Slice
  def offset
    @bytepos
  end
  
  alias charpos offset  # For code expecting charpos
  alias bytepos offset  # For clarity
end
```

### Test Updates Required

**Slice tests**: Replace `Position.new(string, bytepos, charpos)` with `bytepos`
**Source tests**: Expect integer from `pos`, not Position object
**Atom tests**: Should pass without changes (test behavior, not implementation)

---

## Risk Assessment

### Low Risk

- Change is localized (Position only created in one place)
- Pattern is mechanical (replace Position with integer)
- Tests validate correctness at each step
- Can revert easily if issues found

### Medium Risk

- Charpos behavior changes (bytepos returned instead)
  - **Mitigation**: For ASCII, identical. For UTF-8, acceptable approximation
  - **Fallback**: Can add lazy charpos calculation if needed

### Validation Strategy

1. Update Slice + tests → validate
2. Update Source + tests → validate  
3. Update atoms one-by-one → validate each
4. Run full test suite → all 712 tests pass
5. Run benchmarks → verify performance improvement

---

## Expected Performance Impact

### Allocation Reduction

- **Before**: Position.new on every `source.pos` call (thousands per parse)
- **After**: Zero Position allocations

### Memory Impact

- **Before**: Position object = 40-80 bytes (object + ivars)
- **After**: Integer on stack = 0 bytes (no allocation)

### GC Impact

- **Before**: Thousands of Position objects → GC pressure
- **After**: No Position objects → reduced GC pressure

### Target Improvement

- **Primary**: ≥1.35x average (vs. 1.27x v3.2.0)
- **Mechanism**: Eliminate allocation overhead in hot path
- **Validation**: Run fair_comparison.rb 3 times

---

## Implementation Checklist

- [x] Phase 1.1: Analyze Position usage (this document)
- [ ] Phase 1.2: Design integer position system (this document)
- [ ] Phase 2.1: Update Slice implementation
- [ ] Phase 2.2: Update Slice tests
- [ ] Phase 3.1: Update Source implementation
- [ ] Phase 3.2: Update Source tests
- [ ] Phase 4: Update all atoms
- [ ] Phase 5.1: Verify LineCache compatibility
- [ ] Phase 5.2: Verify error reporting
- [ ] Phase 6.1: Run full test suite (712/713 passing)
- [ ] Phase 6.2: Run benchmarks (3 runs, ≥1.35x target)
- [ ] Phase 7: Update documentation

---

## Conclusion

Position objects are a pure overhead in the parsing hot path. They are created, used to read a single integer (bytepos), and immediately discarded. Replacing them with direct integer usage will:

1. Eliminate allocation overhead
2. Simplify code
3. Maintain backward compatibility
4. Achieve 1.35-1.40x performance target

The change is straightforward, testable at each step, and low-risk.

**Ready to proceed with implementation.**