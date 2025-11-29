# Phase 20: Re Atom Fast Paths - REJECTED

## Reason for Rejection

Phase 20 attempted to optimize Re atom by adding fast-path character checking for common patterns like `\s`, `[0-9]`, `[a-z]`, etc. However, **benchmarking showed this actually degraded performance**.

## Benchmark Results

### Test Configuration
- 10,000 iterations per test
- Warmup: 3 iterations
- Ruby's optimized regex engine vs lambda-based character checks

### Performance Comparison

| Pattern | Regex (baseline) | Fast Paths | Speed Change | Memory Change |
|---------|------------------|------------|--------------|---------------|
| `\s` (whitespace) | 34,294 parses/sec, 177 obj/parse | 23,818 parses/sec, 188 obj/parse | **-30.5% slower** ❌ | **+6.2% more** ❌ |
| `[0-9]` (digits) | 33,044 parses/sec, 192 obj/parse | 32,582 parses/sec, 212 obj/parse | **-1.4% slower** ❌ | **+10.4% more** ❌ |
| `[a-zA-Z]` (letters) | 20,874 parses/sec, 320 obj/parse | 19,428 parses/sec, 372 obj/parse | **-6.9% slower** ❌ | **+16.3% more** ❌ |
| `[a-zA-Z][a-zA-Z0-9_]*` (identifier) | 26,690 parses/sec, 239 obj/parse | 25,233 parses/sec, 283 obj/parse | **-5.5% slower** ❌ | **+18.4% more** ❌ |

### Key Findings

**Performance Degradation:**
- Speed: 1.4% to 30.5% slower across all patterns
- Memory: 6% to 18% more object allocations
- Worst case: Whitespace matching (-30.5% speed)

**Why Fast Paths Failed:**

1. **Ruby's Regex Engine is Highly Optimized**
   - Single-character regex matching is a hot path in the Ruby VM
   - Optimized at the C level
   - JIT compilation benefits for repeated patterns

2. **Lambda Call Overhead**
   - Each fast-path check requires:
     * Lambda invocation overhead
     * Closure allocation/access
     * Method dispatch overhead

3. **Position Save/Restore Overhead**
   - Fast path requires explicit position save before consume
   - Position restore on failure
   - Regex path has this optimized internally

4. **Extra Conditional Logic**
   - `if @fast_matcher` check on every try
   - Additional branching in hot path
   - Pollutes instruction cache

### Raw Benchmark Output

#### With Fast Paths (Phase 20):
```
Testing: Whitespace (\s)
  Time: 0.42s for 10000 iterations
  Rate: 23818.1 parses/sec
  Per parse: 0.042ms

Testing: Digits ([0-9])
  Time: 0.307s for 10000 iterations
  Rate: 32582.0 parses/sec
  Per parse: 0.031ms

Testing: Letters ([a-zA-Z])
  Time: 0.515s for 10000 iterations
  Rate: 19428.0 parses/sec
  Per parse: 0.051ms

Testing: Identifier ([a-zA-Z][a-zA-Z0-9_]*)
  Time: 0.396s for 10000 iterations
  Rate: 25232.6 parses/sec
  Per parse: 0.04ms

Memory: 188/212/372/283 objects per parse
```

#### Without Fast Paths (Regex Only - Baseline):
```
Testing: Whitespace (\s)
  Time: 0.292s for 10000 iterations
  Rate: 34294.4 parses/sec
  Per parse: 0.029ms

Testing: Digits ([0-9])
  Time: 0.303s for 10000 iterations
  Rate: 33044.0 parses/sec
  Per parse: 0.03ms

Testing: Letters ([a-zA-Z])
  Time: 0.479s for 10000 iterations
  Rate: 20874.2 parses/sec
  Per parse: 0.048ms

Testing: Identifier ([a-zA-Z][a-zA-Z0-9_]*)
  Time: 0.375s for 10000 iterations
  Rate: 26689.7 parses/sec
  Per parse: 0.037ms

Memory: 177/192/320/239 objects per parse
```

## Lessons Learned

### When Not to "Optimize"

1. **Don't Assume High-Level Code is Faster**
   - Ruby's C-level implementations are often faster than pure Ruby
   - Regex for simple patterns is highly optimized
   - Lambda/closure overhead can negate theoretical gains

2. **Always Benchmark Before Committing**
   - Theoretical optimizations may degrade real performance
   - Measure both speed AND memory
   - Test with realistic workloads

3. **Trust the VM's Optimizations**
   - Modern VMs optimize common patterns
   - Regex engines have decades of optimization
   - Don't outsmart the compiler/VM without proof

### Successful Str Optimization vs Failed Re Optimization

**Why Str optimization (Phase 19) worked:**
- Eliminated regex compilation overhead
- Simple string equality (`==`) is primitive operation
- No pattern matching engine needed for literal strings
- Measured improvement before committing

**Why Re optimization (Phase 20) failed:**
- Regex already optimal for character classes
- Added lambda/closure overhead
- More complex code path
- Measured degradation, so rejected

## Conclusion

Phase 20 is **permanently rejected**. The regex engine in Ruby is already optimal for single-character pattern matching. Any "optimization" that adds overhead in the hot path will degrade performance.

**Final State:** Reverted to commit 133ca2a (Phase 19 - Str optimization only)

**Key Takeaway:** Always measure. Performance optimization without measurement is just guessing.
