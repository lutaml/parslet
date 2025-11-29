# Parslet Profiling Findings

**Date**: 2025-10-21
**Parser**: MyJson::Parser (example/json.rb)
**Test Data**: 186,541 bytes (0.178 MB)
**Ruby Version**: 3.3.2

---

## Executive Summary

Performance profiling of the JSON parser reveals **catastrophic memory allocation issues** as the primary performance bottleneck. Parsing 186KB of JSON creates **9.6 million objects** and consumes **390 MB of memory**, resulting in throughput of only 0.0257 MB/sec (195x below the 5.0 MB/sec target).

**Critical Finding**: The parser creates approximately **51,500 objects per KB** of input data.

---

## Performance Metrics

### Throughput
- **Average**: 0.0257 MB/sec
- **Best**: 0.029 MB/sec
- **Gap to target**: 4.9743 MB/sec (99.5% below target)
- **Required improvement**: ~195x speedup

### Parse Time (10 iterations, 0.178 MB input)
- **Average**: 6,914 ms (6.9 seconds)
- **Min**: 6,140 ms
- **Max**: 7,561 ms
- **Std deviation**: 489 ms (7.1% variance)

### Memory Impact
- **Memory increase**: 389,984 KB (~390 MB)
- **Memory per KB of input**: 2,090 KB (2+ MB per KB!)
- **Memory amplification**: ~2,090x

---

## Object Allocation Analysis

### Total Allocations: 9,608,426 objects

| Object Type | Count | Percentage | Impact |
|-------------|-------|------------|--------|
| **T_ARRAY** | 6,885,542 | 71.7% | 🔴 CRITICAL |
| **T_STRING** | 1,617,575 | 16.8% | 🔴 CRITICAL |
| **T_OBJECT** | 1,563,492 | 16.3% | 🔴 CRITICAL |
| **T_HASH** | 246,079 | 2.6% | 🟡 HIGH |
| **T_REGEXP** | 3 | 0.0% | 🟢 Negligible |
| **T_CLASS** | 1 | 0.0% | 🟢 Negligible |
| **T_FILE** | 1 | 0.0% | 🟢 Negligible |
| **T_DATA** | 6 | 0.0% | 🟢 Negligible |

### Key Observations

1. **Array Allocation Dominance (71.7%)**
   - 6.9 million arrays created for 186KB input
   - ~37,000 arrays per KB of input
   - Likely from parser combinators building intermediate results

2. **String Allocation (16.8%)**
   - 1.6 million strings created
   - ~8,700 strings per KB of input
   - Probable causes:
     - String slicing in Source/Slice
     - Position tracking
     - Match results

3. **Object Allocation (16.3%)**
   - 1.5 million objects (likely Position, Slice instances)
   - ~8,400 objects per KB of input
   - Confirms excessive Position/Slice creation

4. **Hash Allocation (2.6%)**
   - 246K hashes
   - Parse tree nodes
   - Acceptable relative to other allocations

---

## Component Performance

Individual parser component timing (isolated testing):

| Component | Time | Iterations | Impact |
|-----------|------|------------|--------|
| **String parsing** | 1,457.9 ms | 1,000 | 🔴 Slowest |
| **Number parsing** | 40.36 ms | 1,000 | 🟢 Fast |
| **Array parsing** | 20.12 ms | 100 | 🟢 Fast |

**Finding**: String parsing is **36x slower** than number parsing per iteration, indicating inefficient string handling.

---

## Root Cause Analysis

### Primary Bottleneck: Excessive Object Creation

The profiling data clearly shows that Parslet creates an enormous number of temporary objects during parsing:

1. **Position Objects**
   - Created for every character position
   - ~1.5 million Position objects = ~1.5M positions tracked
   - Each position likely creates multiple objects (line, column tracking)

2. **Slice Objects**
   - Created for every match
   - Contains string data + position information
   - ~1.6 million string objects suggest similar number of Slices

3. **Array Accumulation**
   - Parser combinators build intermediate arrays
   - Repetition rules (.repeat) create arrays for each match
   - 6.9 million arrays suggest heavy array manipulation

### Secondary Issues

1. **String Operations**
   - Frequent string slicing
   - No string view/zero-copy optimization
   - String copying in Slice creation

2. **Parse Tree Construction**
   - Hash allocations for tree nodes
   - Multiple transformations of intermediate data

3. **Garbage Collection Pressure**
   - 9.6M objects created in ~7 seconds
   - ~1.4 million objects/second creation rate
   - Significant GC overhead (not measured but implied)

---

## Architecture Analysis

### Parslet's Current Architecture

```
Input String (186 KB)
    ↓
Source (wraps string, tracks position)
    ↓
Position (line/column for each char) ← 1.5M objects
    ↓
Slice (match result + position) ← 1.6M strings
    ↓
Parser Combinators (build arrays) ← 6.9M arrays
    ↓
Parse Tree (hashes) ← 246K hashes
```

**Problem**: Each layer creates massive numbers of objects.

### Memory Allocation Cascade

For a simple string match like `"hello"`:
1. Source creates Position objects (5+)
2. Match creates Slice object (1+)
3. Slice contains string copy (1+)
4. Result wrapped in array (1+)
5. Array added to parent array (1+)

**Per-character cost**: ~9+ objects

For 186KB input (186,000 chars): 186,000 × 9 = **1.67 million objects minimum**

Actual: 9.6 million objects = **51.5 objects per character** on average!

---

## Critical Performance Patterns

### Pattern 1: Position Tracking Overhead

Every character access creates Position objects:

```ruby
# Current (hypothetical simplified)
def match_char
  pos = source.pos  # Creates Position object
  char = source.consume(1)  # Creates Slice with Position
  # ... more allocations
end
```

**Impact**: 1.5M position objects × ~100 bytes = ~150 MB

### Pattern 2: String Slicing

```ruby
# Current
slice = source.str[pos..end_pos]  # String copy
result = Slice.new(slice, position)  # Wraps copy
```

**Impact**: 1.6M string objects × ~variable size = significant memory

### Pattern 3: Array Building

```ruby
# Repetition (simplified)
results = []
while matches
  results << match  # Creates arrays at each level
end
```

**Impact**: 6.9M arrays suggest deep nesting and frequent concatenation

---

## Optimization Opportunities

### 🔴 Critical Priority (Highest Impact)

1. **Eliminate Position Object Creation**
   - **Impact**: Remove 1.5M allocations (-16%)
   - **Approach**: Use integer offsets instead of Position objects
   - **Effort**: Medium (requires API changes)
   - **Risk**: Medium (affects error reporting)

2. **Implement String Views**
   - **Impact**: Remove 1.6M string allocations (-17%)
   - **Approach**: Use offset/length instead of string slicing
   - **Effort**: High (significant refactoring)
   - **Risk**: Medium (must maintain compatibility)

3. **Reduce Array Allocations**
   - **Impact**: Reduce 6.9M allocations (-72% if 50% reduction)
   - **Approach**:
     - Reuse arrays where possible
     - Use in-place mutations
     - Lazy evaluation
   - **Effort**: High
   - **Risk**: Medium-High

### 🟡 High Priority

4. **Memoization for Repeated Patterns**
   - **Impact**: Unknown, likely 20-30% improvement
   - **Approach**: Cache parse results for positions
   - **Effort**: Medium
   - **Risk**: Low (can be optional)

5. **Optimize String Matching**
   - **Impact**: String parsing is 36x slower than numbers
   - **Approach**:
     - Fast path for string literals
     - Reduce object creation in match logic
   - **Effort**: Low-Medium
   - **Risk**: Low

### 🟢 Medium Priority

6. **Reduce Parse Tree Allocations**
   - **Impact**: 246K hashes (~2.6%)
   - **Approach**: Lazy tree construction
   - **Effort**: Medium
   - **Risk**: Medium

7. **Object Pooling**
   - **Impact**: Reduce GC pressure, 10-20% improvement
   - **Approach**: Reuse Position, Slice objects
   - **Effort**: Medium
   - **Risk**: Medium (lifecycle management)

---

## Recommended Action Plan

### Phase 1: Quick Wins (1-2 weeks)
1. Profile with ruby-prof to identify specific hot methods
2. Optimize string matching with fast paths
3. Add memoization for common patterns
4. **Expected improvement**: 2-3x

### Phase 2: Structural Changes (2-4 weeks)
1. Implement string views (offset/length)
2. Reduce Position object creation
3. Optimize array building in combinators
4. **Expected improvement**: 5-10x total

### Phase 3: Advanced Optimizations (4-8 weeks)
1. Object pooling for hot paths
2. Lazy parse tree construction
3. Consider compiled parser option
4. **Expected improvement**: 20-50x total

### Phase 4: Architectural Redesign (if needed)
1. Evaluate zero-copy parsing approaches
2. Consider alternative parser architectures
3. Benchmark against other parser libraries
4. **Expected improvement**: 100-200x (potentially)

---

## Comparison with Target

| Metric | Current | Target | Gap |
|--------|---------|--------|-----|
| Throughput | 0.0257 MB/s | 5.0 MB/s | 195x |
| Objects/KB | 51,500 | <1,000 (est.) | 51x |
| Memory/KB | 2,090 KB | <10 KB (est.) | 209x |

**Conclusion**: Achieving the 5.0 MB/sec target requires **fundamental architectural changes**, not just incremental optimizations.

---

## Next Steps

1. ✅ **Complete**: Basic performance profiling
2. 🔄 **In Progress**: Document findings
3. ⏭️ **Next**: Install ruby-prof/stackprof for detailed method profiling
4. ⏭️ **Next**: Identify top 10 hot methods
5. ⏭️ **Next**: Implement quick wins (memoization, fast paths)
6. ⏭️ **Next**: Prototype string view optimization
7. ⏭️ **Next**: Measure improvement and iterate

---

## Conclusion

The profiling reveals that Parslet's current architecture creates an **unsustainable number of objects** during parsing. The 51,500 objects per KB metric is approximately **50-100x higher than efficient parsers**.

**Key Insight**: This is not a "slow algorithm" problem, but an **object allocation problem**. The parser spends most of its time:
1. Allocating objects (Position, Slice, Arrays)
2. Copying strings
3. Triggering garbage collection

**Reality Check**: Achieving 195x improvement is extremely challenging and likely requires:
- Rewriting core Parslet internals
- Breaking API compatibility
- Considering alternative parsing approaches

**Recommended Path**: Focus on achievable 10-20x improvements through targeted optimizations, then evaluate if further architectural changes are warranted based on actual use case requirements.
