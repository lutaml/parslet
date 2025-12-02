# Session 12: Deep Profiling Analysis

**Date**: 2025-12-01  
**Objective**: Identify bottlenecks preventing ≥1.30x speedup in worst-performing cases  
**Cases Profiled**: calc/small (1.02x), calc/tiny (1.02x), erb/tiny (1.05x)

---

## Executive Summary

Profiling reveals that **memoization cache overhead is the #1 bottleneck** for small inputs, consuming 15-20% of execution time. For tiny inputs (17-273 bytes), the cache lookup/store overhead exceeds the benefit of avoiding re-parsing. This is the primary reason why small cases show minimal improvement (1.02-1.05x) despite our grammar optimizations.

**Key Finding**: Optimizations that improved large inputs (sentence/medium: 7.57x) are hurting small inputs due to fixed overhead.

---

## Profiling Results

### calc/small (273 bytes, 1.02x speedup)

**Top Methods by Self Time:**
1. `Parslet::Atoms::Context#try_with_cache` - **13.61%** (177,600 calls)
2. `Parslet::Atoms::Base#apply` - **8.31%** (177,600 calls)
3. `Parslet::Atoms::CanFlatten#flatten` - **7.39%** (100,300 calls)
4. `Parslet::Atoms::Base#succ` - **6.54%** (102,300 calls)
5. `Parslet::Source#bytepos` - **3.74%** (302,200 calls)
6. `Kernel#loop` - **2.94%** (26,000 calls)
7. `Parslet::Atoms::CanFlatten#foldl` - **2.93%** (43,800 calls)
8. `Hash#[]` - **2.79%** (382,500 calls)

**Cache Overhead**: 13.61% (try_with_cache) + 2.79% (Hash#[]) = **16.4%**

### calc/tiny (17 bytes, 1.02x speedup)

**Top Methods by Self Time:**
1. `Parslet::Atoms::Context#try_with_cache` - **15.27%** (12,000 calls)
2. `Parslet::Atoms::Base#apply` - **7.75%** (12,000 calls)
3. `Parslet::Atoms::CanFlatten#flatten` - **7.35%** (7,000 calls)
4. `Parslet::Atoms::Base#succ` - **6.01%** (6,700 calls)
5. `Parslet::Source#bytepos` - **3.56%** (21,700 calls)
6. `Kernel#loop` - **3.24%** (1,800 calls)
7. `Hash#[]` - **3.02%** (29,600 calls)
8. `Parslet::Atoms::CanFlatten#foldl` - **2.93%** (3,200 calls)

**Cache Overhead**: 15.27% (try_with_cache) + 3.02% (Hash#[]) = **18.3%**

### erb/tiny (25 bytes, 1.05x speedup)

**Top Methods by Self Time:**
1. `Parslet::Atoms::Context#try_with_cache` - **16.25%** (12,500 calls)
2. `Parslet::Atoms::Base#apply` - **6.86%** (12,500 calls)
3. `Parslet::Atoms::CanFlatten#flatten` - **6.54%** (7,400 calls)
4. `Parslet::Atoms::Base#succ` - **5.05%** (7,900 calls)
5. `Class#new` - **4.38%** (15,300 calls)
6. `Hash#[]` - **4.15%** (40,900 calls)
7. `Parslet::Source#bytepos` - **4.09%** (28,000 calls)
8. `Parslet::Atoms::Str#try` - **3.61%** (2,900 calls)

**Cache Overhead**: 16.25% (try_with_cache) + 4.15% (Hash#[]) = **20.4%**

---

## Bottleneck Analysis

### 1. Memoization Cache Overhead (15-20% of execution time) 🔴 CRITICAL

**Impact**: Highest across all cases  
**Root Cause**: For small inputs, cache lookup/store overhead > parsing cost savings

**Evidence**:
- `try_with_cache` is #1 by self-time in ALL cases (13.61%, 15.27%, 16.25%)
- Hash operations add 2-4% more overhead
- Cache effectiveness decreases with input size
- For 17-byte input: cache overhead is 18.3% of total time!

**Why it hurts small inputs**:
1. Few repeated patterns to cache
2. Cache key generation (position + rule) is expensive
3. Hash lookup/store has fixed cost
4. Memory allocation for cache entries
5. For tiny parses, total work is small, so cache overhead dominates

**Optimization Strategy**:
- Adaptive caching: disable for inputs <500-1000 bytes
- Or use simpler cache (array instead of hash)
- Or skip cache for leaf atoms (Str, Re, Match)

**Expected Impact**: 15-20% improvement → brings 1.02x to 1.22x

---

### 2. Flatten Overhead (6-7% of execution time) 🟡 HIGH

**Impact**: Consistent across all cases  
**Root Cause**: Result flattening happens even when not needed

**Evidence**:
- `flatten` is #3 by self-time (7.39%, 7.35%, 6.54%)
- Additional methods: `foldl` (2-3%), `flatten_repetition` (1.5-2.8%)
- Total flatten overhead: ~10-12%

**Why it's expensive**:
1. Array manipulations
2. Type checking (is_a?, instance_of?)
3. Recursive flattening
4. Called even when result is already flat

**Optimization Strategy**:
- Lazy flattening: mark atoms as "needs flatten" vs "already flat"
- Skip flattening for atoms that produce flat results by construction
- In-place flattening where possible

**Expected Impact**: 5-7% improvement

---

### 3. Method Dispatch Overhead (8% of execution time) 🟡 HIGH

**Impact**: Consistent overhead from small methods

**Evidence**:
- `apply` is #2 by self-time (8.31%, 7.75%, 6.86%)
- `succ` adds 5-6.5% more
- Total dispatch: ~13-15%

**Why it's expensive**:
1. Ruby method call overhead
2. Parameter passing
3. Frame setup/teardown
4. Called millions of times (177k-12k calls)

**Optimization Strategy**:
- Inline small hot methods (`succ`, simple `apply` cases)
- Use `define_method` for dynamic optimization
- Flatten call chains

**Expected Impact**: 3-5% improvement

---

### 4. Position Tracking Overhead (3-5% of execution time) 🟢 MEDIUM

**Impact**: Moderate but consistent

**Evidence**:
- `bytepos` is #5 (3.74%, 3.56%, 4.09%)
- `Position#initialize` in erb: 1.52%
- StringScanner ops: 1-2%

**Why it's expensive**:
1. Position object creation (Class#new: 1.77-4.38%)
2. Method calls for position access
3. Position tracking even when not needed

**Optimization Strategy**:
- Position object pooling
- Reuse immutable positions
- Cache position calculations
- Lazy position object creation

**Expected Impact**: 3-5% improvement

---

### 5. Object Allocation Overhead (4-6% of execution time) 🟢 MEDIUM

**Impact**: More pronounced in erb/tiny

**Evidence**:
- `Class#new` - 1.77% (calc/small), 1.49% (calc/tiny), 4.38% (erb/tiny)
- Position, Slice object creation
- erb has more object allocations (text/ruby nodes)

**Optimization Strategy**:
- Object pooling (Position, Slice)
- Reduce temporary allocations
- Reuse objects where possible

**Expected Impact**: 2-4% improvement

---

## Cumulative Optimization Impact

**Combined expected improvements**:
1. Adaptive caching: +15-20%
2. Flatten optimization: +5-7%
3. Method inlining: +3-5%
4. Position optimization: +3-5%
5. Allocation reduction: +2-4%

**Total Expected**: +28-41% improvement

**Current Performance**: 1.02x  
**With Optimizations**: 1.30-1.44x ✅

**This achieves our ≥1.30x target!**

---

## Optimization Priority

### Phase 2A: Quick Wins (Expected: +20-25%, 2 hours)

1. **Adaptive Caching** (Priority: CRITICAL)
   - Disable cache for inputs <500 bytes
   - Expected: +15-20%
   - Implementation: Simple size check in try_with_cache
   - Risk: Low (only affects small inputs)

2. **Flatten Optimization** (Priority: HIGH)
   - Skip flatten for flat-by-construction atoms
   - Expected: +5-7%
   - Implementation: Add `flat?` flag to atoms
   - Risk: Low

### Phase 2B: Follow-up (Expected: +8-13%, 2 hours)

3. **Method Inlining** (Priority: HIGH)
   - Inline `succ`, small `apply` cases
   - Expected: +3-5%
   - Implementation: Inline method bodies
   - Risk: Low-Medium (code duplication)

4. **Position Optimization** (Priority: MEDIUM)
   - Position object pooling
   - Expected: +3-5%
   - Implementation: Object pool for Position
   - Risk: Medium (state management)

5. **Allocation Reduction** (Priority: LOW)
   - Reduce temporary objects
   - Expected: +2-4%
   - Implementation: Reuse objects, avoid unnecessary allocations
   - Risk: Low

---

## Risk Assessment

### Low Risk (Safe to implement)
- Adaptive caching (only affects small inputs)
- Flatten optimization (localized change)
- Allocation reduction

### Medium Risk (Requires careful testing)
- Method inlining (code duplication, maintainability)
- Position optimization (state management)

### High Risk (Avoid unless necessary)
- Remove caching entirely (may hurt other cases)
- Major architectural changes

---

## Next Steps

1. **Implement adaptive caching** - disable cache for small inputs
2. **Run benchmarks** - verify 15-20% improvement
3. **Implement flatten optimization** - skip unnecessary flattening
4. **Run benchmarks** - verify additional 5-7% improvement
5. **Check if ≥1.30x achieved** - if yes, document and ship
6. **If not, continue** with method inlining and position optimization

---

## Key Insight

**The problem is not that our optimizations don't work—it's that they're optimized for large inputs.**

Our grammar optimizations (string merging, quantifier simplification) help all cases. But our runtime optimizations (caching, flattening) have fixed overhead that hurts small inputs.

**Solution**: Make optimizations adaptive to input size.

---

## Detailed Profiling Data

Full profiling reports available in:
- `benchmark/results/profiles/calc_small_flat.txt`
- `benchmark/results/profiles/calc_small_graph.txt`
- `benchmark/results/profiles/calc_small_stack.html`
- Similar files for calc/tiny and erb/tiny