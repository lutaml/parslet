# Phase 44: Architectural Analysis

## The Real Problem

Looking at the profiling data architecturally reveals a critical pattern:

```
Context#try_with_cache: 7,313,380 calls (15.25%, 10.6s)
Base#apply:             7,313,380 calls (7.31%, 5.1s)

Supporting methods driven by these calls:
Source#bytepos:        15,478,215 calls (4.11%, 2.9s)
Hash#[]:               21,655,085 calls (3.10%, 2.2s)
Hash#fetch:             4,490,075 calls (2.16%, 1.5s)
Source#pos:             4,490,075 calls (2.04%, 1.4s)
Integer operations:    ~40,000,000 calls (various %)
```

## Root Cause: 7.3 Million Parse Attempts

For a 186KB JSON file, we're making **7.3 million cache lookup attempts**. This drives:
- 15M+ position getter calls
- 21M+ hash lookups
- 40M+ integer comparisons
- Millions of object allocations

**The symptoms (Integer#<, Hash#[], etc.) are caused by the sheer volume of parsing attempts.**

## Why So Many Attempts?

### Current Parse Attempts by Atom Type
```
Str#try:        1,717,390 calls
Sequence#try:   1,709,910 calls
Alternative#try:  734,885 calls
Repetition#try:   685,380 calls
Lookahead#try:    634,825 calls
Re#try:           915,260 calls
---------------------------------
Total: ~6.4M direct try() calls
```

But we have 7.3M try_with_cache calls, suggesting recursive/nested parsing.

## Architectural Solutions

### 1. Reduce Redundant Parsing (Priority: HIGH)

**Problem**: Same parslets being tried at same positions multiple times despite caching.

**Potential causes**:
- Cache misses due to selective memoization threshold
- Backtracking in alternatives creating redundant work
- Repetitions re-parsing overlapping regions

**Solution approaches**:
- Analyze cache hit/miss rates per parslet type
- Identify parslets with poor cache benefit
- Consider more aggressive caching for certain patterns

### 2. Early Failure Detection (Priority: MEDIUM)

**Problem**: Continuing to try alternatives/sequences after certain failure.

**Current**: Alternatives try each option until success
**Opportunity**: Fast-fail on character mismatches

**Example**:
```ruby
str('a') | str('b') | str('c') | ...
```

Could check first character before trying each alternative.

### 3. Position Tracking Overhead (Priority: HIGH)

**Problem**: 15M+ position getter calls, 5M+ setter calls

**Why**: Every parse attempt:
1. Gets current position (try_with_cache)
2. Checks cache (Hash#fetch)
3. If miss: executes parslet
4. Gets position again (to calculate advance)
5. Sets position back if failure

**Opportunity**: Batch position operations, reduce setter calls

### 4. Grammar-Level Optimization (Priority: MEDIUM)

**Problem**: JSON grammar may have redundant patterns

**Opportunity**:
- Use optimizer to flatten/merge patterns
- Reduce total parslet count
- Fewer atoms = fewer try() calls

## Measurement Strategy

Before implementing, we need to understand:

1. **Cache effectiveness per atom type**
   - Which parslets benefit from caching?
   - Which have low hit rates despite high call counts?

2. **Backtracking patterns**
   - Where does the parser backtrack most?
   - Can we reduce it?

3. **Position tracking necessity**
   - Do we need all these position saves/restores?
   - Can we batch them?

## Next Steps

1. Add instrumentation to measure:
   - Cache hit/miss rates by atom type
   - Backtracking depth and frequency
   - Position save/restore patterns

2. Identify highest-impact architectural change

3. Implement and measure

## Hypothesis

**If we can reduce the 7.3M parse attempts by even 20%, we eliminate:**
- ~3M position tracking calls
- ~4M hash operations
- ~8M integer comparisons
- Potentially 10-15% total runtime

This is a much bigger win than optimizing individual operations.
