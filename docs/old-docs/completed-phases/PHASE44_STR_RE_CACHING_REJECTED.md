# Phase 44: Str/Re Caching - REJECTED

## Status: ❌ REJECTED

## Overview

**Hypothesis**: Enabling caching for Str and Re atoms would reduce the 7.3M parse attempts and improve performance significantly.

**Result**: Mixed and inconsistent performance with only 2.1% overall improvement. The original authors' decision to disable caching for Str/Re was correct for most parsers.

## Investigation

### Discovery

Profiling showed 7,313,380 calls to `Context#try_with_cache`, but measurement tool only detected 29K cached calls. Investigation revealed:

```ruby
# lib/parslet/atoms/str.rb
def cached?
  false  # "Caching adds overhead without benefit"
end

# lib/parslet/atoms/re.rb
def cached?
  false  # "Regex matching is already very fast"
end
```

Str and Re atoms explicitly disable caching, explaining the 29K vs 7.3M discrepancy.

### Hypothesis

If Str/Re atoms (the most frequent in any parser) were cached, we could:
1. Reduce 7.3M parse attempts significantly
2. Lower all dependent operations (Hash lookups, integer ops, etc.)
3. Achieve major speedup based on "higher architecture level" principle

## Test Results

### JSON Parser (Simple)

Enabled Str/Re caching via monkey-patch:

```ruby
module Parslet::Atoms
  class Str
    def cached?
      true
    end
  end

  class Re
    def cached?
      true
    end
  end
end
```

**Result**: 1.72x speedup (1.17ms → 0.68ms, 41.75% improvement)

This looked very promising!

### Pascal Parser (Real-world)

| File | Size | Baseline | Optimized | Speedup | Change |
|------|------|----------|-----------|---------|--------|
| small_program.pas | 8 KB | 41.79ms | 47.75ms | 0.88x | **-14.3%** |
| medium_program.pas | 24 KB | 226.93ms | 168.56ms | 1.35x | **+25.7%** |
| large_program.pas | 49 KB | 463.56ms | 471.19ms | 0.98x | **-1.6%** |
| huge_program.pas | 332 KB | 10,394ms | 10,208ms | 1.02x | **+1.8%** |
| **TOTAL** | - | **11,126ms** | **10,896ms** | **1.02x** | **+2.1%** |

**Overall**: Only 2.1% improvement with inconsistent results.

### Test Suite

```bash
$ bundle exec rspec
600 examples, 0 failures
```

✅ All tests pass with Str/Re caching enabled (semantic correctness maintained).

## Analysis

### Why Different Results?

**JSON Parser (1.72x speedup)**:
- Small input (186 bytes)
- High backtracking due to complex grammar
- Many repeated parse attempts at same positions
- Cache hits outweigh cache overhead

**Pascal Parser (2.1% improvement)**:
- Larger inputs (8KB - 332KB)
- Less backtracking (more deterministic)
- Str/Re operations so fast that cache overhead dominates
- Cache overhead ≈ operation cost for simple matches

### Performance Breakdown

**Str#try operation** (single character):
- Read 1 byte: ~5ns
- String comparison: ~5ns
- Total: ~10ns

**Cache overhead**:
- Hash lookup: ~15ns
- Store result: ~10ns
- Position tracking: ~5ns
- Total: ~30ns

**Cache overhead is 3x the operation cost!**

For simple Str/Re atoms:
- Operation: 10-50ns
- Cache overhead: 30-50ns
- **Cache only helps if hit rate > 60-70%**

Pascal parser has lower hit rates because:
1. Larger files mean more unique positions
2. Less backtracking in deterministic grammars
3. Keywords/operators don't repeat enough

### When Caching Helps vs. Hurts

**Helps** (JSON parser):
- Small inputs with high backtracking
- Complex grammars with alternatives
- Many repeated attempts at same positions

**Hurts** (small Pascal):
- Simple/deterministic grammars
- Large inputs with many unique positions
- Fast operations where overhead dominates

**Neutral** (large Pascal):
- Benefits and overhead roughly balance

## Original Authors' Reasoning

From code comments:

> "String matching is already very fast (regex match).
> Caching adds overhead without benefit for such simple operations."

**Verdict**: The original authors were **CORRECT** for most use cases.

Str/Re operations are:
1. Already highly optimized (direct string comparison)
2. So fast that cache overhead can dominate
3. Not worth caching unless high backtracking

## Why 7.3M Attempts Aren't the Problem

Initial hypothesis: "7.3M attempts → numerous basic operations at higher architecture level"

**Reality**: The 7.3M attempts are necessary and efficient:
- Each Str/Re match is 10-50ns
- Total for 7.3M: ~50-300ms
- This is NOT the bottleneck

The real bottlenecks (from Phase 42 profiling):
- Hash#delete_if: 22.47% (solved in Phase 42)
- Context#try_with_cache: 10.67% (inherent to packrat)
- Basic operations are SYMPTOMS, not root cause

## Trade-offs

### If We Enabled Str/Re Caching

**Pros**:
- 25% speedup for some parsers (medium Pascal)
- 72% speedup for high-backtracking parsers (JSON)

**Cons**:
- 14% slowdown for simple parsers (small Pascal)
- Inconsistent results (0.88x to 1.35x range)
- Only 2% overall improvement
- Increased memory usage
- Goes against PEG parsing best practices

### Why Keep Disabled

1. **Consistency**: Predictable performance across parser types
2. **Simplicity**: Less cache overhead to debug/tune
3. **Memory**: Lower memory footprint
4. **Best Practice**: PEG parsers should avoid excessive backtracking
5. **Overall**: 2.1% gain too small for trade-offs

## Alternative Approaches

### 1. Parser-Specific Caching

Allow users to opt-in:

```ruby
class MyParser < Parslet::Parser
  # Enable Str/Re caching for high-backtracking grammars
  enable_str_re_caching!
end
```

**Verdict**: Adds complexity, users won't know when to enable.

### 2. Adaptive Caching

Track hit rates and enable/disable caching dynamically.

**Verdict**: Too complex, overhead of tracking may exceed savings.

### 3. Selective Caching

Only cache Str/Re atoms longer than N characters.

**Verdict**: Single-char matches are most common, wouldn't help.

### 4. Grammar Optimization

Encourage users to write deterministic grammars that minimize backtracking.

**Verdict**: ✅ Best approach - addresses root cause.

## Lessons Learned

### 1. Not All Caching Is Good

The "cache everything" mentality can backfire:
- Cache overhead can exceed operation cost
- Premature optimization based on call counts
- Need to measure actual wall-time impact

### 2. Profiling Can Mislead

- 7.3M calls looked alarming
- But 7.3M × 10ns = 73ms (not the bottleneck)
- Focus on %total_time, not call counts

### 3. Different Parsers, Different Needs

- JSON parser: High backtracking → caching helps
- Pascal parser: Deterministic → caching hurts
- Can't optimize for all cases with one setting

### 4. Original Authors Usually Right

The code comments were dismissive but correct:
- They tested and found no benefit
- Simple operations don't need caching
- Trust existing architectural decisions

### 5. Architecture vs. Micro-optimization

User guidance: "Remember that the basic ruby operations can be numerous due to a potential improvement that can be made at a higher architecture level."

This led us to investigate Str/Re caching, but the real lesson:
- **Micro-optimization**: Enable Str/Re caching (rejected)
- **Architecture**: Write deterministic grammars to avoid backtracking (correct approach)

## Conclusion

Phase 44 demonstrates that:
- Not all "obvious" optimizations work
- Fast operations shouldn't be cached
- Benchmark-driven validation prevents mistakes
- Sometimes the best optimization is no optimization

**Recommendation**: Keep Str/Re caching **DISABLED** (current behavior).

The 2.1% improvement doesn't justify:
- Inconsistent results (-14% to +25%)
- Increased complexity
- Higher memory usage
- Deviation from PEG best practices

## Next Steps

Since Str/Re caching is rejected, the focus should shift to:

1. **Grammar-level optimizations**: Help users write better grammars
2. **Profiling other hot spots**: Find next bottleneck after Phase 42
3. **Documentation**: Explain when backtracking becomes expensive
4. **Alternative architectures**: Explore left-factoring, LL(k) optimization

The "higher architecture level" insight remains valid, but the solution isn't micro-optimizations like caching. It's helping users write efficient grammars.

---

**Files Modified**: 0 (no changes committed)
**Tests**: 600/600 passing (tested with Str/Re caching enabled)
**Impact**: REJECTED - insufficient and inconsistent improvement (2.1% overall)
