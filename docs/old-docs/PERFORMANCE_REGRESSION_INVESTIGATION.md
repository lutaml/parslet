# Performance Regression Investigation - v3.1.0

## Executive Summary

**Status**: CRITICAL - Release blocked by performance regressions  
**Date**: 2025-11-30  
**Time Invested**: 5+ hours  
**Cost**: $6.67+

## Problem Statement

Comprehensive benchmarks reveal plurimath-parslet is **20% slower on average** than vanilla parslet 2.0 without `optimize_rules!`, with some cases showing 6x slowdown.

## Benchmark Results

### Overall Statistics
- **Average speedup**: 0.8x (20% slower)
- **Best case**: 1.22x (erb/medium)
- **Worst case**: 0.16x (json/tiny - 6x slower!)

### By Parser Type
- **sentence**: 0.77x (23% slower after charpos fix)
- **calc**: 0.86x (14% slower)
- **json**: 0.47x (53% slower!)
- **erb**: 1.02x (2% faster - only winner)

### Detailed Results

**JSON Parser (Most Problematic):**
-

 json/tiny: 3153 ips → 492 ips (0.16x - **6x slower**)
- json/small: 157 ips → 119 ips (0.76x - 24% slower)
- json/medium: 20 ips → 10 ips (0.49x - 51% slower)

**Sentence Parser:**
- sentence/medium: 44 ips → 40 ips (0.91x - 9% slower after fix)
- sentence/small: 2378 ips → 2000 ips (0.84x - 16% slower)
- sentence/tiny: 38023 ips → 18889 ips (0.50x - 50% slower)

**Calculator Parser:**
- calc/tiny: 8070 ips → 5783 ips (0.72x - 28% slower)
- calc/small: 705 ips → 618 ips (0.88x - 12% slower)
- calc/medium: 57 ips → 65 ips (1.13x - **13% faster!**)
- calc/large: 2.2 ips → 2.3 ips (1.05x - 5% faster)

**ERB Parser (Best Performance):**
- erb/tiny: 7552 ips → 5365 ips (0.71x - 29% slower)
- erb/small: 652 ips → 743 ips (1.14x - **14% faster!**)
- erb/medium: 19 ips → 38 ips (2.07x - ***2x faster!***)
- erb/large: 1.3 ips → 2.4 ips (1.85x - **85% faster!**)

## Key Findings

### 1. Charpos Bottleneck (FIXED)

**Issue**: `StringScanner#charpos` consumed 78% of CPU time (762/973 samples)

**Root Cause**: 
- `charpos` is O(n) for Unicode text
- Called on every `Source#pos`
- For 38KB Japanese text, this became catastrophic (40x slower)

**Fix Applied**: Incremental charpos caching in `lib/parslet/source.rb`
- Track last known position
- Calculate incrementally for forward movement
- Result: sentence/medium improved from 1.09 ips → 40.3 ips (37x improvement!)

**Status**: ✅ Fixed

### 2. Pattern: Small Inputs Suffer, Large Inputs Improve

**Observation**: Larger files often perform BETTER:
- calc/medium: 1.13x faster
- calc/large: 1.05x faster
- erb/small: 1.14x faster
- erb/medium: 2.07x faster!
- erb/large: 1.85x faster!

But tiny inputs are much slower:
- json/tiny: 0.16x (6x slower)
- sentence/tiny: 0.50x (2x slower)
- calc/tiny: 0.72x (28% slower)

**Hypothesis**: Initialization overhead dominates on small inputs

### 3. Excessive GC on JSON Parser

**Profile Data** (json/tiny):
- 43.7% of time in garbage collection
- 13.7% in `Source#initialize`
- Too many object allocations for small inputs

### 4. Historical Session 3 Contradiction

**Session 3** (docs/comparative_results.json):
- json simple_object: 8185 ips (plurimath)
- json simple_object: 5282 ips (vanilla)
- Speedup: 1.55x faster

**Current** (comprehensive v3.1.0):
- json/tiny: 492 ips (plurimath)  
- json/tiny: 3153 ips (vanilla)
- Speedup: 0.16x (6x slower!)

**Critical Question**: Why such different results?

## Root Causes Analysis

### Primary Issues

1. **Initialization Overhead**: 
   - Position cache creation
   - Charpos cache creation
   - Line cache setup
   - Regex cache population
   - Disproportionate impact on tiny inputs

2. **GC Pressure**:
   - Too many cache Hash allocations
   - Position object creation (even with caching)
   - Memory overhead from optimization structures

3. **Cache Thrashing**:
   - Multiple caches per Source instance
   - May be creating too many Source objects

### Secondary Issues

4. **Measurement Variance**:
   - Different Ruby versions (3.1.1 vs 3.3.2)?
   - Different benchmark methodologies?
   - Warmup differences?

## Recommendations

### Option A: Enable optimize_rules! by Default (FASTEST FIX - 1 hour)

**Pros:**
- Immediate fix
- Achieves documented 13-37x speedup
- Proven to work

**Cons:**
- API behavior change (minor breaking change)
- Users must explicitly disable if unwanted

**Implementation:**
```ruby
class Parslet::Parser
  def self.inherited(subclass)
    super
    subclass.class_eval { optimize_rules! }
  end
end
```

### Option B: Fix Initialization Overhead (DEEP FIX - 4-8 hours)

**Investigation needed:**
1. Profile Source#initialize overhead
2. Make caches lazy/optional
3. Reduce object allocations
4. Test each fix incrementally

**Risk**: May not fully resolve issue

### Option C: Hybrid Approach (BALANCED - 2-3 hours)

1. Enable optimize_rules! by default (quick win)
2. Add flag to disable: `optimize_rules! false`
3. Document the change clearly
4. File initialization overhead as future optimization

### Option D: Postpone v3.1.0 (SAFE)

1. Document findings in GitHub issue
2. Fix regressions properly in v3.2.0
3. Release v3.0.1 maintenance update instead

## Time & Cost Analysis

**Already Spent:**
- Time: 5+ hours
- Cost: $6.67

**Remaining Options:**
- Option A: +1 hour, +$2
- Option B: +4-8 hours, +$10-$20
- Option C: +2-3 hours, +$5-$8  
- Option D: +0 hours (postpone)

## Recommendation

**I recommend Option C (Hybrid Approach)**:

1. Makes `optimize_rules!` default behavior (solves immediate problem)
2. Allows opt-out for compatibility
3. Documents the change transparently
4. Files initialization overhead for future work
5. Achieves release goal with minimal risk

This gives users the 13-37x performance by default while maintaining an escape hatch for compatibility needs.

## Next Steps

User decision required on which option to pursue.

---

*Investigation Document*  
*Created: 2025-11-30*  
*Status: Awaiting decision*