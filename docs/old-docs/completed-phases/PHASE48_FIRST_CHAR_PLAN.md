# Phase 48: First-Character Optimization - Planning

## Overview

Implement first-character optimization to skip non-matching positions using fast string scanning.

## Concept

Instead of trying to match a pattern at every position, extract the deterministic first character and use `String#index` to jump directly to potential match positions.

**Example:**
```ruby
# Pattern: str('if')
# Input: "x = 1; if y > 0 then z = 2; if w < 3"
#
# Without optimization: Try match at positions 0,1,2,3,4,5,6,7...
# With optimization: Use 'i'.index to jump to positions 7 and 27 only
```

## Benefits

- **Sparse matches**: Dramatically faster on inputs where matches are rare
- **Keyword parsers**: Perfect for programming language keywords
- **Large inputs**: Scales better with input size
- **String scanning**: Ruby's C-level `String#index` is highly optimized

## Implementation Strategy

### Phase 48a: Extract First Character

Add `first_char` method to atoms that can provide it:

```ruby
class Str
  def first_char
    return nil if @str.empty?
    @str[0]  # First character
  end
end

class Sequence
  def first_char
    parslets.first&.first_char
  end
end
```

### Phase 48b: Fast Scanning in Source

Add scanning method to Source:

```ruby
class Source
  def scan_for(char)
    # Use String#index to find next occurrence
    idx = @str.index(char, @bytepos)
    return nil unless idx
    @bytepos = idx
    true
  end
end
```

### Phase 48c: Optimize Str Atom

Modify Str to use scanning when beneficial:

```ruby
class Str
  def try(source, context, consume_all)
    # Use scanning for longer strings in large inputs
    if @str.length > 1 && source.chars_left > 100
      first = @str[0]
      loop do
        # Scan to next potential match
        break unless source.scan_for(first)
        # Try full match
        success, value = try_match(source, context, consume_all)
        return [success, value] if success
        source.bytepos += 1
      end
      return error_result(source, context)
    end

    # Normal path for short strings or small inputs
    try_match(source, context, consume_all)
  end
end
```

## When to Apply

First-character optimization is most beneficial when:

1. **Pattern length > 1**: Single characters don't benefit
2. **Input size is large**: Overhead pays off on large inputs
3. **Matches are sparse**: More skipping = more benefit
4. **First char is unique**: Common first chars (space, 'a') provide less benefit

## Risks and Mitigation

### Risk 1: Overhead for dense matches
- **Mitigation**: Only use for inputs > threshold (e.g., 100 chars)
- **Mitigation**: Only use for patterns > threshold (e.g., 2 chars)

### Risk 2: Complexity in error reporting
- **Mitigation**: Keep error paths unchanged
- **Mitigation**: Comprehensive testing

### Risk 3: Edge cases (multibyte characters)
- **Mitigation**: Test with UTF-8 inputs
- **Mitigation**: Use bytepos correctly

## Testing Strategy

1. **Correctness**: Ensure same parse results
2. **Performance**: Benchmark on various input sizes
3. **Edge cases**: Empty strings, single chars, UTF-8
4. **Regression**: All existing tests must pass

## Benchmarking Scenarios

```ruby
# Scenario 1: Keyword in large file
input = "var x = 1;\n" * 1000 + "if y > 0"
pattern = str('if')

# Scenario 2: Sparse token
input = "a" * 10000 + "target" + "b" * 10000
pattern = str('target')

# Scenario 3: Dense matches
input = "the " * 1000
pattern = str('the')
```

## Decision

**Implement Phase 48a first**: Add `first_char` extraction infrastructure
- Low risk
- Foundation for optimization
- Can measure impact incrementally

Then proceed to 48b and 48c if 48a shows promise.

## Alternative: Boyer-Moore

For longer patterns, Boyer-Moore algorithm could be even faster, but adds significant complexity. Consider for future phase if first-char optimization proves valuable.

## Status

Planning complete. Ready for implementation.
