# Parslet Performance Optimization - Final Summary

## Overall Achievement
- **Starting JSON Performance**: 0.021 MB/sec
- **Final JSON Performance**: 0.0996 MB/sec  
- **Total Improvement**: ~4.7x (374% faster)
- **Total Commits**: 6 successful optimization commits
- **Test Status**: All 438 specs passing throughout

## Optimization Phases

### Phase 1: Foundation (2 commits)
**Commit c12c5fd**: Regex cache and Position charpos optimization
- Pre-populate regex cache for common patterns (1-10 chars)
- Avoid repeated regex compilation
- Optimize Position#charpos calculation

**Commit e720cbd**: StringScanner#charpos integration
- Use native StringScanner#charpos instead of manual calculation
- Eliminate calls to String#byteslice and String#size

### Phase 2: Smart Caching (2 commits) - **Biggest Win**
**Commit c9cdbfd**: Context caching strategy (+137% improvement!)
- Skip caching for uncacheable atoms (Str, Re)
- Use Hash#fetch for single operation instead of separate check+set
- Added `cached?` method to Base class (default true)
- Str and Re override with `cached? false`
- Reduced Context#try_with_cache from 19.18% to 6.55% (65% reduction)

**Commit 9bf5828**: Position object caching
- Cache Position objects by byte position in Source
- Eliminated repeated Position allocation (1,039 → cached)
- Use Hash#fetch for cache lookup

### Phase 3: Error & Wrapper Optimization (1 commit)
**Commit 5132e41**: Alternative and wrapper atoms
- Lazy error array allocation in Alternative (only when all alternatives fail)
- Skip caching for Named and Entity (wrappers that delegate)
- Reduced unnecessary object allocation

### Phase 4: Iterator Optimization (1 commit)
**Commit dd05907**: Sequence and Repetition
- Replace each_with_index with integer while loops
- Pre-allocate arrays when size is known (Repetition with max)
- Reduced iterator overhead

### Phase 7: CanFlatten Optimization (1 commit)
**Commit 7268754**: Post-processing optimization (+40-60% improvement!)
- Replace list[1..-1].inject with while loop in foldl (avoid array slicing)
- Replace .map with pre-allocated array + while loop in flatten
- Cache l.class and r.class in merge_fold
- Replace respond_to? checks with direct class comparisons

## What Works: Key Lessons Learned

### ✅ Successful Patterns
1. **Cache hits on fast operations**: Skip caching for Str/Re matching
2. **Object pooling**: Cache Position objects by byte position  
3. **Lazy allocation**: Don't allocate error arrays until needed
4. **each_with_index → while loops**: Reduces iterator overhead
5. **Array slicing elimination**: Avoid list[1..-1] in hot paths
6. **Class caching**: Cache `obj.class` in variables for repeated use
7. **Direct class comparisons**: Faster than respond_to? checks

### ❌ What Caused Regressions
1. **Micro-optimizations of simple delegations** (Phase 5, reverted)
   - Caching local variables like `old_pos = source.bytepos`
   - Array destructuring `success, value = result`
   - These caused 10-12% slowdown
   - Ruby VM already optimizes these patterns well

2. **Replacing .each with while loops** (Phase 6, reverted)  
   - In Alternative, .each with early return is VM-optimized
   - While loop version caused ~15% regression
   - .each is special-cased by Ruby VM for performance

### 🎯 Key Insight
**The Ruby VM is surprisingly good at optimizing certain patterns:**
- Simple attribute reads and delegations
- `.each` with early returns
- Array destructuring

**Human optimizations that help:**
- Structural changes (caching strategy, lazy allocation)
- Avoiding expensive operations (array slicing, repeated regex compilation)
- Iterator type changes (each_with_index → while)

## Current Hotspot Analysis

After all optimizations, remaining hotspots are:
1. Array#new (9.57%) - Fundamental array allocation
2. Base#apply (7.08%) - Core dispatch method  
3. Hash#fetch (6.11%) - Cache lookups (already optimized)
4. Context#try_with_cache (6.04%) - Already optimized
5. Sequence#try (5.86%) - Already optimized
6. CanFlatten operations (~7.92%) - Just optimized

**These are mostly fundamental operations that can't be further optimized without:**
- Risking regressions (learned from Phases 5-6)
- Major architectural changes
- Changing the PEG algorithm itself

## Performance Metrics

### Before All Optimizations
- JSON: 0.021 MB/sec
- Calc: 0.067 MB/sec (estimated)

### After All Optimizations  
- JSON: 0.0996 MB/sec (4.7x improvement)
- Calc: ~0.09-0.11 MB/sec (1.4x improvement)

## Recommendations for Future Work

1. **Profile-driven development**: Always measure before and after
2. **Test thoroughly**: Run full test suite after each change
3. **Be skeptical of micro-optimizations**: The VM is smarter than you think
4. **Focus on structural changes**: Caching strategies, lazy allocation
5. **Benchmark real-world usage**: Small examples may not reflect actual gains

## Files Modified

### Core Library Changes
- lib/parslet/atoms/base.rb - Added cached? method
- lib/parslet/atoms/str.rb - Skip caching
- lib/parslet/atoms/re.rb - Skip caching  
- lib/parslet/atoms/context.rb - Optimized caching strategy
- lib/parslet/atoms/named.rb - Skip caching (wrapper)
- lib/parslet/atoms/entity.rb - Skip caching (wrapper)
- lib/parslet/atoms/alternative.rb - Lazy error allocation
- lib/parslet/atoms/sequence.rb - While loop iteration
- lib/parslet/atoms/repetition.rb - While loop + pre-allocation
- lib/parslet/atoms/can_flatten.rb - While loops + class caching
- lib/parslet/source.rb - Position caching, regex cache
- lib/parslet/position.rb - Use StringScanner#charpos

### Infrastructure Added
- benchmark/profile_with_rubyprof.rb - Comprehensive profiling
- benchmark/measure_throughput.rb - MB/sec measurement
- benchmark/PROFILING_ANALYSIS.md - Detailed hotspot analysis
- Various benchmark scripts and documentation

## Conclusion

Through systematic profiling and optimization, we achieved a **4.7x performance improvement** 
while maintaining **100% test compatibility**. The key success factors were:

1. **Data-driven decisions**: Always profil before optimizing
2. **Incremental approach**: One optimization at a time, test, commit
3. **Learning from failures**: Reverted Phase 5 and 6 taught us what NOT to do
4. **Respecting the VM**: Don't fight Ruby's built-in optimizations

The remaining optimization headroom is limited without major architectural changes 
or algorithmic improvements to the PEG parsing approach itself.
