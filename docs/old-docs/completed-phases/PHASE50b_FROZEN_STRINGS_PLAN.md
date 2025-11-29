# Phase 50b: Frozen String Literals Optimization

## Overview

Implement frozen string literals across the Parslet codebase to reduce memory allocation and GC pressure. This optimization leverages Ruby's frozen string literal feature to reuse string objects instead of creating new ones.

## Background

From Phase 50a profiling:
- **Current**: 29,603 objects allocated per parse
- **Current**: 2.99 GC runs per parse (HIGH)
- **Potential**: 1.1-1.2x speedup + reduced GC frequency

## Strategy

### 1. Add Magic Comment to Core Files

Add `# frozen_string_literal: true` to the top of all Ruby source files in:
- `lib/parslet/*.rb`
- `lib/parslet/atoms/*.rb`
- `lib/parslet/optimizers/*.rb`
- `lib/parslet/error_reporter/*.rb`
- `lib/parslet/expression/*.rb`
- `lib/parslet/pattern/*.rb`
- `lib/parslet/source/*.rb`

### 2. Fix String Mutation Issues

Identify and fix any code that mutates strings:
- Use `String#+` instead of `String#<<` for building strings
- Use `.dup` or `.clone` when mutation is necessary
- Convert in-place operations to return new strings

### 3. Benchmark Impact

Create benchmark to measure:
- Object allocation reduction
- GC frequency reduction
- Performance impact (iterations/second)
- Memory usage reduction

## Implementation Plan

### Phase 1: Core Library Files (High Impact)
Priority order based on usage frequency:
1. `lib/parslet/atoms/base.rb` - Base class for all atoms
2. `lib/parslet/atoms/str.rb` - String matching (heavily used)
3. `lib/parslet/atoms/re.rb` - Regex matching (heavily used)
4. `lib/parslet/atoms/sequence.rb` - Sequence composition
5. `lib/parslet/atoms/alternative.rb` - Choice composition
6. `lib/parslet/slice.rb` - Slice objects (created frequently)
7. `lib/parslet/source.rb` - Source management

### Phase 2: Supporting Files (Medium Impact)
8. `lib/parslet/atoms/repetition.rb`
9. `lib/parslet/atoms/lookahead.rb`
10. `lib/parslet/atoms/named.rb`
11. `lib/parslet/context.rb`
12. `lib/parslet/error_reporter/*.rb`

### Phase 3: Optimization & Pattern Files (Lower Impact)
13. `lib/parslet/optimizer.rb`
14. `lib/parslet/optimizers/*.rb`
15. `lib/parslet/pattern/*.rb`

### Phase 4: Remaining Files
16. All other `lib/parslet/**/*.rb` files

## Expected Challenges

### 1. String Mutation Patterns
Common patterns that need fixing:
```ruby
# Before (mutates string)
str = ""
str << "hello"
str << "world"

# After (frozen string safe)
str = "hello" + "world"
# or
str = ["hello", "world"].join
```

### 2. Error Messages
Dynamic error message construction may need adjustment:
```ruby
# Before
msg = "Error at "
msg << position.to_s

# After
msg = "Error at #{position}"
# or
msg = "Error at " + position.to_s
```

### 3. Testing
- All 657 Ruby tests must pass
- All 656 Opal tests must pass
- No performance regressions

## Success Criteria

1. **Functionality**: All tests pass (Ruby + Opal)
2. **Performance**:
   - Object allocation reduced by 5-10%
   - GC frequency reduced by 10-15%
   - Parse speed improved by 5-10% (1.1-1.2x)
3. **No Regressions**: No slowdowns in any benchmark

## Rollback Plan

If issues arise:
1. Remove `# frozen_string_literal: true` from affected files
2. Revert code changes
3. Run tests to confirm stability
4. Document why frozen strings caused issues

## Next Steps

1. Create baseline benchmark (before frozen strings)
2. Implement Phase 1 (high-impact files)
3. Run tests after each file
4. Measure incremental impact
5. Continue with Phases 2-4 if Phase 1 succeeds
6. Create comprehensive benchmark comparing before/after
7. Document results in PHASE50b_RESULTS.md
