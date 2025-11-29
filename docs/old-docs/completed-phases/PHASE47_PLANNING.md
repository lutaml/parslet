# Phase 47: Position Save/Restore Optimization - Planning

## Overview

Audit and optimize position save/restore operations across all atoms to eliminate unnecessary overhead.

## Current State

Looking at the codebase, many atoms save and restore positions even when it may not be necessary. Position save/restore involves:
1. Cloning the Source object
2. Storing it on a stack
3. Restoring it on failure

This overhead multiplies in deeply nested grammars.

## Analysis Needed

### Atoms that MUST save position
- **Alternative**: Must restore on failure to try next alternative
- **Lookahead**: Must always restore (already optimized in Phase 23)
- **Repetition**: Must restore when min not met

### Atoms that may NOT need position save
- **Str**: Currently doesn't save (already optimal)
- **Re**: Currently doesn't save (already optimal)
- **Sequence**: Each element fails independently - no sequence-level save needed?
- **Named**: Delegates to wrapped parslet - no save needed?

### Current Implementation Review

Let me check each atom's `try` method to see what's saving position:

1. **Str** (`lib/parslet/atoms/str.rb`): No position save ✓
2. **Re** (`lib/parslet/atoms/re.rb`): No position save ✓
3. **Sequence** (`lib/parslet/atoms/sequence.rb`): Check needed
4. **Alternative** (`lib/parslet/atoms/alternative.rb`): Position save required
5. **Repetition** (`lib/parslet/atoms/repetition.rb`): Check needed
6. **Lookahead** (`lib/parslet/atoms/lookahead.rb`): Optimized in Phase 23 ✓
7. **Named** (`lib/parslet/atoms/named.rb`): Check needed

## Investigation Steps

1. **Map all position saves**: Identify which atoms save position and when
2. **Analyze necessity**: Determine if each save is actually needed
3. **Benchmark impact**: Measure performance with/without saves
4. **Selective optimization**: Remove unnecessary saves while preserving correctness

## Alternative: First-Character Optimization

Another promising strategy is first-character optimization:
- Extract first character from patterns
- Use String#index to skip to next match position
- Particularly valuable for:
  * Keyword parsers (`if`, `while`, `for`, etc.)
  * Token-based languages
  * Large inputs with sparse matches

## Recommendation

Based on complexity and potential impact:

**Option A: Position Save Audit** (Lower risk, proven value)
- Complexity: LOW
- Risk: MEDIUM (must preserve correctness)
- Benefit: Reduces overhead in nested grammars
- Timeline: 1-2 hours

**Option B: First-Character Optimization** (Higher value, more complex)
- Complexity: MEDIUM
- Risk: LOW (additive optimization)
- Benefit: Significant speedup for sparse matches
- Timeline: 3-4 hours

**Option C: Rule Inlining** (Highest value, requires profiling)
- Complexity: HIGH
- Risk: MEDIUM
- Benefit: Reduces method call overhead
- Timeline: 6-8 hours
- Prerequisite: Need profiling data to identify hot rules

## Decision

Start with **Position Save Audit** (Option A) because:
1. Lower complexity and risk
2. Can be completed quickly
3. Proven technique from PEG research
4. No infrastructure changes needed
5. Easy to benchmark and verify

Then move to **First-Character Optimization** (Option B) if audit shows promise.

## Next Steps

1. Read and analyze all atom `try` methods
2. Document current position save/restore patterns
3. Identify unnecessary saves
4. Create test cases
5. Implement optimizations
6. Benchmark results
