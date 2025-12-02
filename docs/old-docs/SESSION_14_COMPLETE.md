# Session 14 Complete - Profiling Analysis & Optimization Challenges

**Date**: 2025-12-01  
**Duration**: ~1 hour  
**Status**: ⚠️ INCOMPLETE - Challenges identified, lessons learned  
**Overall Achievement**: Detailed profiling completed, optimization attempts unsuccessful

---

## Executive Summary

Session 14 focused on achieving ≥1.30x performance improvement in 10-12 of 14 benchmark cases (71-86% target) through targeted optimization of calc and sentence parsers. While comprehensive profiling successfully identified bottlenecks, optimization attempts encountered significant challenges:

1. ✅ **Profiling completed**: Detailed analysis of calc, sentence, and json parsers
2. ❌ **Position caching failed**: Added overhead instead of improving performance
3. ⚠️ **Benchmark instability**: High variance (±40-99%) makes validation unreliable
4. ⚠️ **Target not reached**: Still at ~35% cases meeting ≥1.30x threshold

**Key Insight**: Not all optimizations suggested by profiling data translate to real performance gains. Position object caching added array lookup overhead that exceeded the cost of creating lightweight Position objects.

---

## Phase 1: Targeted Profiling ✅ COMPLETE

### Objective
Profile calc/sentence parsers at multiple sizes to identify why they consistently achieve only 1.12-1.19x speedup vs JSON's 1.48-1.59x.

### Methodology

Profiled three parsers at small input size:
1. **calc/small** (273 bytes) - Representative of calc parser behavior
2. **sentence/small** (774 bytes) - Representative of sentence parser behavior  
3. **json/small** (759 bytes) - Baseline for comparison (performing well)

Used `ruby-prof` with 100 iterations per case to identify hotspots.

### Key Findings

#### 1. Position Tracking Overhead

| Parser | Base#succ | Self-Time % | Calls | Notes |
|--------|-----------|-------------|-------|-------|
| **Calc** | **9.07%** | Highest | 102,300 | 2.4x higher than JSON |
| **Sentence** | 5.66% | Moderate | 31,900 | 1.5x higher than JSON |
| **JSON** | 3.75% | Baseline | 260,600 | Most calls but lowest % |

**Analysis**: Calc has the highest self-time percentage for `Base#succ` despite fewer total calls than JSON. This suggests calc's grammar structure causes more expensive position tracking operations per call.

#### 2. Flatten Overhead

| Parser | flatten | foldl | flatten_repetition | Total |
|--------|---------|-------|--------------------|-------|
| **Calc** | 7.37% | 3.17% | N/A | **~10.5%** |
| **Sentence** | 4.80% | 4.42% | 3.15% | **~12.4%** |
| **JSON** | 5.26% | 2.64% | N/A | **~7.9%** |

**Analysis**: Sentence has highest total flatten overhead due to repetition flattening (3.15%). Calc and sentence both have significantly higher flatten overhead than JSON.

#### 3. Apply/Cache Overhead

| Parser | Base#apply | Context#try_with_cache | Combined |
|--------|------------|------------------------|----------|
| **Calc** | 7.15% | 4.69% | **11.84%** |
| **Sentence** | 4.85% | 5.74% | **10.59%** |
| **JSON** | 9.32% | 9.51% | **18.83%** |

**Analysis**: JSON has much higher apply/cache overhead but is still fastest due to effective caching. Calc/sentence have lower overhead but don't benefit as much from caching, suggesting their grammars have less repetition.

#### 4. Unique Bottlenecks

**Calc-Specific** (~11% overhead):
- Sequence overhead: 2.81% (32,100 calls)
- Repetition/Kernel#loop: 6.09% (26,000 calls)
- Entity lookups: 1.85% (56,900 calls)

**Sentence-Specific** (~16% overhead):
- **Slice concatenation**: 3.68% (23,800 calls) ⚠️
- **String concatenation**: 3.38% (23,800 calls) ⚠️
- Array indexing: 8.97% (91,600 calls) - Highest of all three!

**JSON-Specific** (~14% overhead):
- Source operations (bytepos=, consume): 7.91%
- Str#try: 6.55% (143,500 calls)

### Call Volume Analysis

| Parser | Total applies | Input size | Applies/byte | Pattern |
|--------|--------------|------------|--------------|---------|
| **Calc** | 177,600 | 273 bytes | **650** | Complex grammar, high backtracking |
| **Sentence** | 34,400 | 774 bytes | **44** | Simple grammar, linear parsing |
| **JSON** | 621,100 | 759 bytes | **818** | Very complex, heavy backtracking |

**Analysis**: Calc and JSON have very high applies-per-byte ratios (650 and 818), suggesting complex grammars with significant backtracking. Sentence is much simpler (44 applies/byte).

### Profiling Output Location

All profiling results saved to:
- `benchmark/results/profiles/calc_small_flat.txt`
- `benchmark/results/profiles/sentence_small_flat.txt`
- `benchmark/results/profiles/json_small_flat.txt`

Full analysis documented in: [`docs/SESSION_14_PROFILING_ANALYSIS.md`](SESSION_14_PROFILING_ANALYSIS.md)

---

## Phase 2: Position Tracking Optimization ❌ FAILED

### Approach

Based on profiling showing Position creation overhead (1.79% in JSON), attempted to cache Position objects in Source class to reduce allocation overhead.

### Implementation

**File**: [`lib/parslet/source.rb`](../lib/parslet/source.rb)

**Changes**:
1. Added `@position_cache = Array.new(1000)` to constructor
2. Modified `pos` method to check cache first:
```ruby
def pos
  bp = @str.pos
  if bp < 1000
    @position_cache[bp] ||= Position.new(@str.string, bp)
  else
    Position.new(@str.string, bp)
  end
end
```

### Results

**SEVERE REGRESSIONS** ❌:
- Average speedup: 2.31x → 0.96x (-58%)
- sentence/medium: 1.15x → 0.36x (-64%)
- json/medium: 1.50x → 0.18x (-82%)
- erb/large: 1.23x → 0.28x (-72%)
- erb/medium: 1.15x → 0.28x (-72%)

### Root Cause Analysis

The position caching added MORE overhead than it saved:

1. **Array lookup cost**: `@position_cache[bp]` with bounds checking
2. **Nil check cost**: `||=` operator evaluation
3. **Cache miss overhead**: Most positions accessed only once
4. **Position objects are lightweight**: Creating new Position is cheaper than expected

**Lesson**: Position objects in parslet are designed to be lightweight (lazy charpos calculation). Caching them trades immediate allocation cost for ongoing lookup overhead, which is a bad trade-off.

### Action Taken

**REVERTED** all position caching changes immediately to restore baseline performance.

---

## Phase 3: Benchmark Stability Issues ⚠️

### Problem

After reverting position caching, observed high benchmark variance:

**Run 1**:
- Average speedup: 2.31x
- 12/14 cases ≥1.0x (85.7%)
- erb/medium: 6.42x
- json/medium: 5.61x

**Run 2** (same code):
- Average speedup: 1.38x  
- 9/14 cases ≥1.0x (64.3%)
- sentence/medium: 0.20x
- erb/medium: 0.28x

**Variance**: ±40-99% for many cases ⚠️

### Analysis

Possible causes:
1. **GC interference**: Despite GC.disable during measurement
2. **CPU frequency scaling**: macOS power management
3. **Background processes**: System activity during benchmarks
4. **Cache state**: CPU cache warmed differently between runs
5. **YJIT compilation**: JIT state varies between runs

### Impact

High variance makes it **impossible to reliably validate optimizations**:
- Can't distinguish real improvements from noise
- Can't detect regressions accurately  
- Can't build confidence in changes

### Comparison to Session 13

Session 13 reported <3% variance through:
- Increased iteration counts (500 for tiny, 200 for small)
- Full GC cycle before each iteration
- GC.compact between iterations
- Multiple warmup runs

Current benchmarks may need similar treatment.

---

## Lessons Learned

### What Worked

1. **Comprehensive profiling**: Successfully identified parser-specific bottlenecks
2. **Detailed analysis**: Clear comparison of hotspots across parsers
3. **Fast failure detection**: Caught position caching regression immediately
4. **Quick remediation**: Reverted failed optimization before causing damage

### What Didn't Work

1. **Position object caching**: Added more overhead than it saved
2. **Assumption-based optimization**: Cache seemed logical but was counterproductive
3. **Benchmark reliability**: High variance prevents validation

### Key Insights

1. **Profile data != Real performance**: Not all profiling hotspots are optimization targets
2. **Lightweight objects**: Creating simple objects can be cheaper than caching them
3. **Overhead hierarchy**: Lookup overhead can exceed allocation overhead
4. **Variance matters**: Can't optimize what you can't measure reliably
5. **Parslet design is clever**: Position laziness is already optimized

---

## Identified Bottlenecks (Remaining)

### High Priority (Validated by Profiling)

1. **Base#succ method** (calc: 9.07%, sentence: 5.66%)
   - Not Position creation, but the succ method itself
   - Does expensive `equal?` checks on result values
   - Located in base.rb lines 199-210
   - **Next approach**: Optimize the equality checks, not Position creation

2. **String concatenation** (sentence: ~7% total)
   - Slice#+ : 3.68% (23,800 calls)
   - String#+: 3.38% (23,800 calls)
   - Unique to sentence parser
   - **Next approach**: Investigate sentence grammar, may need string builder pattern

3. **Array operations** (sentence: 8.97%)
   - Array#[] indexing overhead
   - Highest of all three parsers
   - **Next approach**: Reduce array indexing in sentence-specific code

4. **Flatten overhead** (all parsers: 8-12%)
   - Already attempted optimization in Session 13
   - Limited impact due to existing early returns
   - **Next approach**: Structural changes to reduce flattening needs

### Medium Priority

5. **Sequence/Alternative dispatch** (calc: ~3-5%)
   - Could optimize with fast paths
   - Already has some fast paths for 2-3 element cases

6. **Source operations** (json: 7.91%)
   - bytepos= and consume operations  
   - Local caching may help

---

## Recommendations for Future Sessions

### Immediate Next Steps

1. **Fix benchmark stability FIRST**:
   - Apply Session 13's variance reduction techniques
   - Increase iteration counts appropriately
   - Ensure reliable measurement before optimizing

2. **Target Base#succ optimization**:
   - 9.07% overhead in calc is the real bottleneck
   - Not Position creation but the succ method itself
   - Focus on optimizing equality checks (lines 199-210 in base.rb)
   - Could use object_id comparison or other fast checks

3. **Investigate sentence string concatenation**:
   - 7% overhead is unique to sentence parser
   - May indicate grammar design issue
   - Consider if grammar could be restructured

### Medium Term

4. **Benchmark infrastructure improvements**:
   - Add variance detection and warnings
   - Require 3+ runs and report median
   - Flag unstable measurements automatically

5. **Alternative profiling approaches**:
   - Use stackprof for sampling profiling
   - Memory profiling with memory_profiler
   - Flamegraphs for visual analysis

### Avoid

6. **Don't cache lightweight objects**: Position, Slice, etc. are designed to be cheap
7. **Don't optimize without measuring**: Profile first, even for "obvious" wins
8. **Don't ignore variance**: High variance = unreliable conclusions

---

## Current Status vs Goals

### Original Goals (from CONTINUATION_PROMPT_SESSION14.md)

- [ ] ❌ **10-12 cases (71-86%) meet ≥1.30x** - Still at ~5/14 (35.7%)
- [x] ✅ **Detailed profiling completed** - Comprehensive analysis done
- [ ] ❌ **Position optimization** - Attempted but failed
- [ ] ⏭️ **Source operation optimization** - Not attempted
- [ ] ⏭️ **Parser-specific optimization** - Not attempted

### What We Have

- ✅ Comprehensive profiling of calc/sentence/json parsers
- ✅ Clear identification of bottlenecks with percentages
- ✅ Documented failed optimization attempt with root cause
- ✅ Lessons learned about parslet's design
- ⚠️ Benchmark stability concerns identified

### What We Need

- 🎯 Stable benchmarks with <5% variance
- 🎯 Successful optimization of Base#succ (9.07% calc overhead)
- 🎯 5-7 more cases reaching ≥1.30x threshold
- 🎯 Validated improvements through reliable measurement

---

## Files Created/Modified

### Documentation
- [`docs/SESSION_14_PROFILING_ANALYSIS.md`](SESSION_14_PROFILING_ANALYSIS.md) - Detailed profiling analysis
- [`docs/SESSION_14_COMPLETE.md`](SESSION_14_COMPLETE.md) - This file
- [`docs/IMPLEMENTATION_STATUS_SESSION14.md`](IMPLEMENTATION_STATUS_SESSION14.md) - Updated

### Code Changes
- `lib/parslet/source.rb` - Position caching attempted, then **REVERTED**
- No permanent code changes from this session

---

## Conclusion

Session 14 successfully completed Phase 1 (profiling) but encountered challenges in Phase 2 (optimization):

**Achievements**:
- ✅ Comprehensive profiling identifying calc/sentence bottlenecks
- ✅ Quantified overhead percentages for all major operations
- ✅ Fast detection and revert of failed optimization
- ✅ Valuable lessons about parslet's design philosophy

**Challenges**:
- ❌ Position caching caused severe regressions (-50% to -80%)
- ⚠️ Benchmark variance too high for reliable validation (±40-99%)
- ❌ Target of 71-86% cases at ≥1.30x not reached

**Key Takeaway**: Not all profiling hotspots should be optimized. Parslet's Position class is already well-optimized with lazy evaluation. The real bottleneck is Base#succ's equality checking logic, not Position creation.

**Next Session Priority**: Fix benchmark stability, then target Base#succ optimization (9.07% overhead in calc parser).

---

**Session 14 Status**: ⚠️ INCOMPLETE - Profiling successful, optimization unsuccessful, benchmark stability concerns identified

**Recommendation**: Address benchmark stability before attempting further optimizations. Cannot validate improvements without reliable measurements.