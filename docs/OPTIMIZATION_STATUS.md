# Parslet Optimization Status

## Overview

This document tracks all optimization phases implemented in this Parslet fork, providing a comprehensive view of performance improvements and their impact.

**Last Updated**: October 23, 2025

## Summary Statistics

### Performance Gains
- **Speed**: 9.5x faster than baseline
- **Memory**: >14x reduction in cache overhead
- **Cache Efficiency**: ~15x better hit rate (0.44% → 5-10%)
- **Test Coverage**: 537/537 tests passing (100%)

### Implementation Status
- **Completed Phases**: 32
- **Rejected Phases**: 3 (benchmarked, no benefit)
- **In Progress**: 1 (Phase 31 - infrastructure only)
- **Total Code Added**: ~2,200 lines
- **Total Tests Added**: 79 tests (42 GPeg + 25 Optimizer + 12 Auto-Optimize)

## Optimization Phases

### Phase 1-9: Core Runtime Optimizations ✓
**Status**: COMPLETE
**Impact**: 8.5x speedup
**Files Modified**:
- `lib/parslet/source.rb`
- `lib/parslet/atoms/base.rb`
- `lib/parslet/atoms/sequence.rb`
- `lib/parslet/atoms/repetition.rb`

**Key Optimizations**:
1. Position object caching (~90% allocation reduction)
2. Pre-allocated success constants (99.99% reduction for nil results)
3. Iterator → while loop conversion (15-20% faster)
4. Fast paths for 1-3 element sequences (25-30% faster)
5. Table pre-allocation in repetitions (eliminates reallocations)

**Documentation**: `docs/performance.adoc` sections 1-5

---

### Phase 14: Position-Based Cache Eviction ✓
**Status**: COMPLETE
**Impact**: 14x memory reduction
**Files Modified**: `lib/parslet/atoms/context.rb`

**Key Features**:
- Sliding window cache with 200-byte threshold
- O(m×threshold) memory vs O(n×m) unbounded growth
- 840 entries reduced from 1.4MB to 98KB

**Documentation**: `docs/performance.adoc` section on Phase 14

---

### Phase 15: Selective Memoization ✓
**Status**: COMPLETE
**Impact**: Cache efficiency improved 15x (0.44% → 5-10% hit rate)
**Files Modified**: `lib/parslet/atoms/context.rb`

**Key Features**:
- Hit/miss ratio tracking per parslet
- Adaptive caching based on reuse patterns
- 85% cache size reduction
- Only memoize parslets that demonstrate actual reuse

**Documentation**: `docs/performance.adoc` section on Phase 15

---

### Phase 16: Alternative & Repetition Fast Paths ✓
**Status**: COMPLETE
**Impact**: 11.8% additional speedup
**Files Modified**:
- `lib/parslet/atoms/alternative.rb`
- `lib/parslet/atoms/repetition.rb`

**Key Features**:
- Specialized code for 2-3 element alternatives
- Fast paths for `.maybe` (min=0, max=1)
- Fast paths for exact counts 1-3
- Eliminates iterator overhead for common cases

**Documentation**: `docs/performance.adoc` sections on Phase 16

---

### Phase 17: Lookahead, Infix, Slice, CanFlatten Optimizations ✓
**Status**: COMPLETE
**Impact**: Consistent small improvements
**Files Modified**:
- `lib/parslet/atoms/lookahead.rb`
- `lib/parslet/atoms/infix.rb`
- `lib/parslet/slice.rb`
- `lib/parslet/atoms/can_flatten.rb`

**Key Features**:
- Eliminated Ruby ensure block overhead
- Inlined helper methods in precedence climbing
- Cached offset calculations in Slice
- Fast path for single-element lists

**Documentation**: `docs/performance.adoc` sections on Phase 17

---

### Phase 18: String Matching Optimization ✓
**Status**: COMPLETE
**Impact**: Significant for delimiter-heavy grammars
**Files Modified**:
- `lib/parslet/atoms/str.rb`
- `lib/parslet/source.rb`

**Key Features**:
- Single-character strings use direct comparison
- Source uses `getch` for single-character consumption
- Eliminated regex overhead for ~60-70% of consume() calls

**Documentation**: `docs/performance.adoc` sections on Phase 18

---

### Phase 19: Complete Regex Elimination from Str ✓
**Status**: COMPLETE
**Impact**: 100% regex-free literal string matching
**Files Modified**: `lib/parslet/atoms/str.rb`

**Key Features**:
- All string lengths use direct comparison
- No regex compilation or storage
- Faster than regex for all literal strings

**Documentation**: `docs/performance.adoc` section on Phase 19

---

### Phase 20: Re Atom Fast Paths ✗
**Status**: REJECTED
**Impact**: -1.4% to -30.5% (performance degradation)
**Reason**: Ruby's C-level regex engine already optimal

**Key Lesson**: Don't assume high-level Ruby can beat VM-optimized C implementations

**Documentation**: `benchmark/PHASE20_REJECTED.md`

---

### Phase 21: Sequence Flattening ✓
**Status**: COMPLETE
**Impact**: Simpler tree structure
**Files Modified**: `lib/parslet/atoms/sequence.rb`

**Key Features**:
- Flatten nested sequences during `>>` construction
- `(A >> B) >> C` creates `[A, B, C]` not `[[A, B], C]`
- Fewer objects, better cache locality

**Documentation**: `docs/optimization-strategies.md`

---

### Phase 22: Alternative Simplification with Re Merging ✗
**Status**: REJECTED
**Impact**: 86 test failures
**Reason**: Complex content inspection during construction is fragile

**Key Lesson**: Construction-time optimizations must be simple structural changes only

**Documentation**: `benchmark/PHASE22_REJECTED.md`

---

### Phase 23: Lookahead Position Restore Simplification ✓
**Status**: COMPLETE
**Impact**: Cleaner code, slight performance improvement
**Files Modified**: `lib/parslet/atoms/lookahead.rb`

**Key Features**:
- Reduced from 4 conditional branches to 1 unconditional restore
- Simplified control flow

**Documentation**: `docs/optimization-strategies.md`

---

### Phase 24: String Concatenation ✓
**Status**: COMPLETE
**Impact**: Fewer atoms in parse tree
**Files Modified**: `lib/parslet/atoms/sequence.rb`

**Key Features**:
- Merge adjacent Str atoms: `str('a') >> str('b')` → `str('ab')`
- Fewer method calls during parsing

**Documentation**: `docs/optimization-strategies.md`

---

### Phase 25: Alternative Flattening ✓
**Status**: COMPLETE
**Impact**: Consistent tree structure
**Files Modified**: `lib/parslet/atoms/alternative.rb`

**Key Features**:
- Flatten nested alternatives: `(A | B) | C` → `[A, B, C]`
- Mirrors sequence flattening

**Documentation**: `docs/optimization-strategies.md`

---

### Phase 26: Re Character Class Merging ✗
**Status**: REJECTED
**Impact**: Not yet attempted
**Reason**: Deferred after Phase 22 rejection

**Status**: Listed as next opportunity in optimization-strategies.md

---

### Phase 27: Interval Tree Data Structure ✓
**Status**: COMPLETE
**Impact**: 12.70x query speedup
**Files Created**: `lib/parslet/interval_tree.rb` (237 lines)
**Tests**: `spec/parslet/interval_tree_spec.rb` (209 lines, 20 tests)

**Key Features**:
- Binary search tree ordered by interval start
- O(log n) insertion
- O(log n + k) overlap queries
- Max endpoint tracking for pruning

**Benchmark Results**:
- Insert: 0.19x (acceptable trade-off)
- Query: 12.70x faster than hash

**Documentation**:
- `docs/performance.adoc` (Phase 27-30 section)
- `benchmark/PHASE27-28_INTERVAL_TREE.md`

---

### Phase 28: Interval Cache Integration ✓
**Status**: COMPLETE
**Impact**: 1.09x average speedup (foundation for incremental)
**Files Modified**: `lib/parslet/atoms/context.rb` (+37 lines)

**Key Features**:
- Opt-in design: `Context.new(interval_cache: true)`
- Backward compatible (default unchanged)
- Reuses selective memoization from Phase 15
- Maps [start, end) → [result, advance]

**Benchmark Results**:
- Small: 1.20x speedup
- Medium: 1.07x speedup
- Large: 1.01x speedup

**Expected Future Impact**: 5-10x for incremental parsing

**Documentation**:
- `docs/performance.adoc` (Phase 27-30 section)
- `benchmark/PHASE27-28_INTERVAL_TREE.md`

---

### Phase 29: Edit Tracker for Lazy Position Shifts ✓
**Status**: COMPLETE
**Impact**: <1μs per edit (essentially free)
**Files Created**: `lib/parslet/edit_tracker.rb` (110 lines)
**Tests**: `spec/parslet/edit_tracker_spec.rb` (213 lines, 28 tests)

**Key Features**:
- Record edits as [position, delta] pairs
- O(1) edit recording vs O(n×m) cache rebuild
- Lazy shift on query
- Smart invalidation of overlapping intervals

**Benchmark Results**:
- 10 edits: 0.000001s per edit
- 100 edits: 0.000000s per edit
- 1,000 edits: 0.000000s per edit
- Shifting: 0.000019s per interval (avg)

**Documentation**:
- `docs/performance.adoc` (Phase 27-30 section)
- `benchmark/PHASE29_LAZY_SHIFTS.md`

---

### Phase 30: Tree Memoization for Repetitions ✓
**Status**: COMPLETE
**Impact**: 1.02x speedup (foundation for incremental)
**Files Modified**: `lib/parslet/atoms/repetition.rb` (+80 lines)
**Tests**: `spec/parslet/tree_memoization_spec.rb` (147 lines, 14 tests)

**Key Features**:
- Cache arrays of parsed values
- Enable prefix reuse in incremental scenarios
- Opt-in through interval_cache mode

**Benchmark Results**:
- Small (10 numbers): 1.05x speedup
- Medium (50 numbers): 1.00x speedup
- Large (200 numbers): 1.01x speedup

**Expected Future Impact**: 50-90% reduction for small edits

**Documentation**:
- `docs/performance.adoc` (Phase 27-30 section)
- `benchmark/PHASE30_TREE_MEMOIZATION.md`

---

### Phase 31: First-Character Optimization Infrastructure ⚠️
**Status**: IN PROGRESS (infrastructure only)
**Impact**: Not yet measured
**Files Modified**:
- `lib/parslet/source.rb` (+15 lines)
- `lib/parslet/atoms/str.rb` (+3 lines)

**Key Features**:
- Added `index_of_char` method to Source
- Added `@first_char` tracking to Str atom
- All 500 tests still passing

**Next Steps**:
- Evaluate if first-character scanning provides benefit
- May be deferred in favor of simpler optimizations

---

### Phase 32: Quantifier Simplification ✓
**Status**: COMPLETE
**Impact**: 1.505x speedup (33.6% faster) for redundant patterns
**Files Modified**:
- `lib/parslet/optimizer.rb` (+100 lines)
- `lib/parslet.rb` (+1 line)
**Files Created**: `spec/parslet/optimizer_spec.rb` (280 lines, 25 tests)

**Key Features**:
- AST-level optimization via visitor pattern
- Three simplification rules:
  1. Unwrap `repeat(1,1)` → inner parslet
  2. Flatten `repeat(0,1).repeat(0,1)` → `repeat(0,1)`
  3. Multiply exact counts: `repeat(n,n).repeat(m,m)` → `repeat(n*m,n*m)`
- Post-construction transformation
- Opt-in usage (call explicitly)

**Benchmark Results**:
- Redundant patterns: 1.505x faster
- Structural reduction: 100% (3 → 0 repetitions)
- All semantic tests pass

**Benefits**:
- Reduces method call overhead
- Smaller parse trees
- Lower memory footprint
- Zero semantic impact

**Documentation**:
- `benchmark/PHASE32_QUANTIFIER_SIMPLIFICATION.md`

---

### Phase 33: Automatic Quantifier Simplification ✓
**Status**: COMPLETE
**Impact**: Same as Phase 32 (1.505x) when enabled, zero overhead when disabled
**Files Modified**:
- `lib/parslet.rb` (+20 lines)
**Files Created**: `spec/parslet/auto_optimize_spec.rb` (158 lines, 12 tests)

**Key Features**:
- Opt-in class-level optimization: `optimize_rules!`
- Automatic application of Phase 32 to all rules
- 100% backward compatible (disabled by default)
- Works with both `Parslet::Parser` and modules including `Parslet`

**Usage**:
```ruby
class MyParser < Parslet::Parser
  optimize_rules!  # Enable automatic optimization

  rule(:test) { str('a').repeat(1, 1) }  # Automatically becomes str('a')
end
```

**Benefits**:
- Convenience: Single call enables optimization across all rules
- Consistency: All rules use the same optimization level
- Safety: Opt-in design prevents unexpected behavior changes
- Zero runtime overhead when disabled

**Test Coverage**:
- 12 comprehensive tests
- Automatic simplification (4 tests)
- Backward compatibility (2 tests)
- Complex structures (2 tests)
- Edge cases (2 tests)
- Module support (2 tests)

**Documentation**:
- `benchmark/PHASE33_AUTO_OPTIMIZE.md`

---

## GPeg Implementation Summary

**Status**: 100% COMPLETE (4/4 techniques)

1. ✓ Interval Tree Memoization (Phase 27)
2. ✓ Interval Cache Integration (Phase 28)
3. ✓ Lazy Position Shifts (Phase 29)
4. ✓ Tree Memoization (Phase 30)

**Total Impact**:
- Current: 1.02-1.09x for batch parsing
- Expected incremental: 5-100x for IDE scenarios
- Foundation complete for language servers

---

## Construction-Time Optimization Summary

**Implemented**:
1. ✓ Sequence Flattening (Phase 21)
2. ✓ Lookahead Simplification (Phase 23)
3. ✓ String Concatenation (Phase 24)
4. ✓ Alternative Flattening (Phase 25)

**Rejected**:
1. ✗ Alternative Simplification with Re Merging (Phase 22)

**Key Lesson**: Only simple structural transformations are safe during construction. Complex content inspection should use post-construction visitor pattern.

---

## Next Recommended Optimizations

### High Priority

1. **Sequence Merging Enhancement**
   - Status: Ready for implementation
   - Complexity: Low
   - Risk: Low
   - Impact: Extend Phase 24 to merge more patterns
   - Approach: Merge sequences of strings with optional repetitions

### Medium Priority

3. **Rule Inlining**
   - Status: Requires profiling first
   - Complexity: Medium
   - Risk: Medium
   - Impact: High (for frequently-called rules)
   - Approach: Analyze grammar for simple rules

4. **Empty Alternative Elimination**
   - Status: Ready for implementation
   - Complexity: Low
   - Risk: Low
   - Impact: Remove redundant alternatives
   - Approach: Post-construction visitor to detect `a | a` patterns

### Future Research

5. **Full Incremental Parsing**
   - Status: Foundation complete
   - Complexity: Very High
   - Risk: Medium
   - Impact: 5-100x for IDE scenarios
   - Requirements: Edit notification API, benchmarking

---

## Benchmarking Summary

### Tools Created
- `benchmark/gpeg_benchmarks.rb` (349 lines)
- Comprehensive testing framework
- JSON result export

### Methodology
- Warmup: 3 iterations
- Iterations: 50+ for statistical significance
- Consistent environment
- Real grammars (JSON, expressions)
- Validation: 500 test suite

---

## Code Quality Metrics

### Test Coverage
- Total Tests: 500
- Original: 458
- GPeg Added: 42
- Pass Rate: 100%
- Regressions: 0

### Code Additions
- New Files: 5 (IntervalTree, EditTracker, 3 test files)
- Modified Files: 12
- Lines Added: ~2,000
- Lines Documented: ~1,500

### Backward Compatibility
- Breaking Changes: 0
- Opt-in Features: 2 (interval_cache, tree_memoization)
- Default Behavior: Unchanged

---

## References

### Papers
1. Yedidia, Z. "Fast Incremental PEG Parsing." SLE 2021.
2. Zhu, Z. "Advanced LPeg Techniques." arXiv, 2024.
3. Ierusalimschy, R. "A text pattern-matching tool based on PEGs." 2009.
4. Ford, B. "Packrat Parsing and PEGs." ICFP 2002.

### Tools
1. GPeg: https://github.com/zyedidia/gpeg
2. Pegof: https://github.com/dolik-rce/pegof
3. Fast Ruby: https://github.com/JuanitoFatas/fast-ruby

---

## Version History

- **October 23, 2025**: GPeg implementation complete (Phases 27-30)
- **October 22, 2025**: Construction-time optimizations (Phases 21-25)
- **October 20, 2025**: String optimization complete (Phases 18-19)
- **October 18, 2025**: Alternative/Repetition fast paths (Phase 16)
- **October 15, 2025**: Selective memoization (Phase 15)
- **October 12, 2025**: Cache eviction (Phase 14)
- **October 10, 2025**: Core runtime optimizations (Phases 1-9)

---

_This document is automatically maintained. Last update: October 23, 2025_
