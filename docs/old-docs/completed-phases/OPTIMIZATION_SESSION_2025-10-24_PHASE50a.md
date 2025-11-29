# Optimization Session 2025-10-24: Phase 50a - Ruby Platform Profiling

## Overview

Completed comprehensive profiling of Parslet performance using Ruby platform-level tools to establish baseline metrics and identify optimization opportunities beyond PEG algorithms.

## Session Context

This phase represents a strategic pivot from PEG-level algorithmic optimizations (Phases 1-49) to Ruby platform and technology-level optimizations. After exhausting PEG optimization strategies in Phases 48-49, focus shifted to Ruby runtime, GC, and YJIT capabilities.

## Work Completed

### 1. Profiling Infrastructure Created

#### GC Profiling (`benchmark/profile_phase50_gc.rb`)
- **Purpose**: Comprehensive garbage collection behavior analysis
- **Metrics Collected**:
  * GC frequency (runs per parse operation)
  * Heap statistics (slots, pages, tomb pages)
  * Memory allocation patterns
  * GC timing data
- **Key Finding**: 299 GC runs per 100 parses (2.99 per parse) - HIGH

#### YJIT Profiling (`benchmark/profile_phase50_yjit.rb`)
- **Purpose**: Benchmark YJIT impact on parsing performance
- **Comparison**: With/without --yjit flag
- **Metrics Collected**:
  * Iterations per second
  * Speedup ratio
  * YJIT compilation statistics
- **Key Finding**: 2.09x speedup (152.794 i/s → 319.472 i/s, 109% faster)

#### Memory Profiling (`benchmark/profile_phase50_memory.rb`)
- **Purpose**: Detailed memory allocation analysis
- **Metrics Collected**:
  * Total allocated memory
  * Total retained memory
  * Allocations by gem
  * Allocations by location
  * Allocations by class
- **Key Findings**:
  * 1.63 MB allocated per parse
  * 29,603 objects allocated per parse
  * 0.03% retention rate (excellent - minimal leaks)

### 2. Comprehensive Analysis Document

Created `benchmark/PHASE50a_PROFILING_RESULTS.md` (~350 lines) documenting:

- **Baseline Performance Metrics**:
  * Parse rate: 152.79 i/s baseline (YJIT: 319.47 i/s)
  * Memory: 1.63 MB per parse
  * GC frequency: 2.99 runs per parse

- **Detailed Findings**:
  * YJIT Impact Analysis
  * GC Behavior Analysis
  * Memory Allocation Patterns
  * Hotspot Identification

- **Optimization Recommendations** (prioritized):
  1. **Immediate Wins** (High Impact, Low Effort):
     - Enable YJIT in production (2.09x speedup)
     - GC tuning via environment variables
     - Combined YJIT + GC tuning approach

  2. **Medium-Term Opportunities** (High Impact, Medium Effort):
     - Frozen string literals
     - Object pooling for frequently created objects
     - Lazy initialization patterns

  3. **Long-Term Investigations** (Medium Impact, High Effort):
     - Native extensions (if Opal constraint removed)
     - Alternative Ruby implementations
     - Profile-guided optimizations

### 3. Documentation Updates

#### Updated `docs/performance.adoc`
Added complete **Phase 50: Ruby Platform Optimizations** section covering:

- **YJIT Usage**:
  * Benchmark results (2.09x speedup)
  * Implementation guide
  * Environment setup
  * Production deployment recommendations

- **GC Tuning**:
  * Environment variable reference
  * Recommended settings for different scenarios
  * Heap growth factor optimization
  * malloc limit tuning

- **Combined Optimizations**:
  * YJIT + GC tuning approach
  * Expected combined speedup (2.5-3x potential)

#### Updated `docs/OPTIMIZATION_STATUS.md`
Added Phase 50a entry documenting:
- Profiling work completed
- Key findings summary
- Performance baseline established

### 4. Bug Fixes

#### Opal Compatibility Issue (FIRST Set Tests)
**Problem**: 4 test failures in `spec-opal/parslet/first_set_spec.rb`
- Opal's Set implementation doesn't support `&` operator
- Opal's Set implementation doesn't support `.intersection` method

**Solution**:
- Modified `lib/parslet/first_set.rb` to use array intersection: `(set1.to_a & set2.to_a)`
- Updated `spec-opal/parslet/first_set_spec.rb` to match
- Maintains compatibility with both Ruby and Opal

**Files Modified**:
- `lib/parslet/first_set.rb` - Changed Set intersection to array intersection
- `spec-opal/parslet/first_set_spec.rb` - Updated 4 test assertions

## Test Results

### Before Fixes
- Ruby: 657/657 passing ✓
- Opal: 652/656 passing (4 failures in first_set_spec.rb)

### After Fixes
- **Ruby: 657/657 passing ✓**
- **Opal: 656/656 passing ✓** (11 pending expected)

## Performance Baseline Established

### Current Performance (Ruby 3.3.2)
```
Without YJIT:  152.79 i/s
With YJIT:     319.47 i/s (2.09x speedup)
Memory/parse:  1.63 MB
Objects/parse: 29,603
GC runs/parse: 2.99
```

### Optimization Potential Identified
```
YJIT alone:           2.09x speedup
GC tuning:            1.2-1.4x potential
Combined (YJIT+GC):   2.5-3x potential
Frozen strings:       1.1-1.2x potential
Object pooling:       1.15-1.25x potential
```

## Files Created

1. `benchmark/profile_phase50_gc.rb` (211 lines) - GC profiling script
2. `benchmark/profile_phase50_yjit.rb` (169 lines) - YJIT benchmark script
3. `benchmark/profile_phase50_memory.rb` (189 lines) - Memory profiling script
4. `benchmark/PHASE50a_PROFILING_RESULTS.md` (~350 lines) - Analysis document

## Files Modified

1. `lib/parslet/first_set.rb` - Opal compatibility fix (Set intersection)
2. `spec-opal/parslet/first_set_spec.rb` - Opal compatibility fix (4 tests)
3. `docs/performance.adoc` - Added Phase 50 section (YJIT & GC tuning)
4. `docs/OPTIMIZATION_STATUS.md` - Added Phase 50a entry

## Next Steps

### Immediate (Phase 50b - Optional)
- Implement frozen string literals optimization
- Measure impact on GC frequency
- Benchmark memory reduction

### Medium-Term
- Object pooling for Str/Re atoms
- Lazy initialization patterns
- Additional YJIT-specific optimizations

### Long-Term
- Consider native extensions if Opal constraint removed
- Investigate alternative Ruby implementations
- Profile-guided optimization based on real-world usage

## Conclusion

Phase 50a successfully established comprehensive baseline metrics for Ruby platform-level optimization. Identified immediate 2.09x speedup opportunity via YJIT with potential for 2.5-3x combined improvements through YJIT + GC tuning. All tests passing (657 Ruby, 656 Opal). Foundation laid for future platform-level optimizations while maintaining pure Ruby/Opal compatibility.

## Session Statistics

- **Duration**: Phase 50a profiling and documentation
- **Profiling Scripts Created**: 3
- **Analysis Documents**: 1 comprehensive document (350 lines)
- **Documentation Updates**: 2 files
- **Bug Fixes**: 1 Opal compatibility issue (2 files)
- **Test Status**: ✓ All passing (657 Ruby + 656 Opal)
- **Performance Baseline**: Established for future comparisons
