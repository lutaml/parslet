# Parslet Performance Profiling Analysis

## Executive Summary

Ruby-prof profiling has identified the performance hotspots in Parslet. The analysis shows that **context management and caching overhead** accounts for the majority of execution time, not the actual parsing logic.

## Profiling Method

- Tool: ruby-prof 1.7.2
- Parsers tested: JSON parser, Calc parser
- Input size: 17KB JSON (200 repetitions), 2.4KB Calc expressions
- Iterations: 3x per parser

## Key Findings

### Top 10 Performance Hotspots (JSON Parser)

| Rank | Method | %Self Time | Calls | Location |
|------|--------|-----------|-------|----------|
| 1 | `Parslet::Atoms::Context#try_with_cache` | 19.18% | 1,552 | lib/parslet/atoms/context.rb:26 |
| 2 | `Parslet::Atoms::Base#apply` | 5.98% | 1,552 | lib/parslet/atoms/base.rb:83 |
| 3 | `Parslet::Source#pos` | 3.89% | 1,039 | lib/parslet/source.rb:76 |
| 4 | `Parslet::Atoms::Context#lookup` | 3.88% | 1,552 | lib/parslet/atoms/context.rb:96 |
| 5 | `Parslet::Source#bytepos` | 3.55% | 4,692 | lib/parslet/source.rb:86 |
| 6 | `Parslet::Atoms::Context#set` | 3.05% | 1,544 | lib/parslet/atoms/context.rb:99 |
| 7 | `Array#each` | 2.98% | 466 | (core) |
| 8 | `Parslet::Atoms::Base#cached?` | 2.91% | 1,544 | lib/parslet/atoms/base.rb:129 |
| 9 | `Parslet::Position#initialize` | 2.88% | 1,039 | lib/parslet/position.rb:9 |
| 10 | `Hash#[]` | 2.27% | 5,642 | (core) |

### Performance Breakdown by Category

1. **Context Management (35.9% of total time)**
   - `try_with_cache`: 19.18%
   - `lookup`: 3.88%
   - `set`: 3.05%
   - `cached?`: 2.91%
   - `Context#err`: Additional overhead
   - **Impact**: Context operations create massive overhead through hash lookups and cache management

2. **Position/Source Operations (10.32% of total time)**
   - `Source#pos`: 3.89%
   - `Source#bytepos`: 3.55%
   - `Position#initialize`: 2.88%
   - **Impact**: Frequent position tracking creates significant object allocation

3. **Base Atom Operations (5.98%)**
   - `Base#apply`: 5.98%
   - **Impact**: Core parsing dispatch mechanism

4. **Core Ruby Operations (5.25%)**
   - `Hash#[]`: 2.27%
   - `Array#each`: 2.98%
   - **Impact**: Fundamental operations called frequently

## Critical Insights

### 1. Context Cache Overhead is Massive

The `try_with_cache` method alone accounts for **19% of execution time**. This is the memoization mechanism that's supposed to speed things up, but it's actually creating significant overhead:

- 1,552 calls for 17KB of input
- Each call involves hash lookups (`lookup`, `set`, `cached?`)
- Creates a cache entry even for failed parses

### 2. Position Object Allocation

Position objects are created 1,039 times for 17KB input:
- Each creates a new object
- Triggers `initialize` which calculates character position
- Despite our optimization, still significant overhead

### 3. Hash Operations Dominate

Hash operations (`Hash#[]`, `Hash#[]=`) are called 7,345 times:
- Context cache lookups
- Result storage
- Configuration access

## Optimization Priorities

### High Impact (Targets for Phase 2)

1. **Optimize Context Cache Strategy**
   - Current: Cache everything unconditionally
   - **Proposed**:
     - Only cache expensive operations (lookaheads, repetitions)
     - Skip caching for simple atoms (single char, simple regex)
     - Use cheaper cache key computation
   - **Expected gain**: 15-20% improvement

2. **Reduce Position Object Allocation**
   - Current: Create new Position for every `pos()` call
   - **Proposed**:
     - Reuse Position objects via object pool
     - Defer Position creation until actually needed for errors
     - Use integer offsets internally, Position only for error reporting
   - **Expected gain**: 10-15% improvement

3. **Streamline Source#pos and Source#bytepos**
   - Current: Called 5,731 times combined
   - **Proposed**:
     - Cache position within parsing session
     - Reduce redundant calculations
     - Inline critical paths
   - **Expected gain**: 5-10% improvement

### Medium Impact (Targets for Phase 3)

4. **Optimize Context#lookup and Context#set**
   - Use more efficient data structures
   - Reduce hash allocations
   - Expected gain: 5-8% improvement

5. **Optimize Alternative/Sequence Try Logic**
   - Reduce intermediate array allocations
   - Streamline success/failure paths
   - Expected gain: 3-5% improvement

### Low Impact (Phase 4 - Architectural)

6. **Consider JIT-compilation for hot parsers**
   - Generate specialized code for parser instances
   - Eliminate dispatch overhead
   - Expected gain: 50-100% improvement (major architectural change)

## Detailed Method Analysis

### Context#try_with_cache (19.18% - TOP PRIORITY)

```ruby
def try_with_cache(source, context, consume_all)
  key = source.bytepos  # Hash lookup expensive

  if cached?(key)       # Another hash lookup
    return lookup(key)  # Yet another hash lookup
  end

  result = try(source, context, consume_all)
  set(key, result)      # Hash insertion
  result
end
```

**Issues**:
- 3-4 hash operations per call
- Creates cache entry even for trivial parses
- No cache size limits (memory leak potential)

**Optimization**:
```ruby
def try_with_cache(source, context, consume_all)
  # Skip caching for simple atoms
  return try(source, context, consume_all) unless should_cache?

  # Use cheaper cache key
  key = source.bytepos

  # Single hash lookup with default
  @cache.fetch(key) do
    result = try(source, context, consume_all)
    @cache[key] = result if cache_worthy?(result)
    result
  end
end
```

### Source#pos (3.89%)

```ruby
def pos
  Position.new(
    self,
    StringScanner#pos,  # Native call
    StringScanner#charpos  # Native call (now cached)
  )
end
```

**Optimization**:
- Use object pool for Position instances
- Defer creation until needed for error reporting

## Next Steps

1. ✅ Complete profiling with ruby-prof
2. **Implement Phase 2 optimizations**:
   - Smart cache strategy for Context
   - Position object pooling
   - Source position optimization
3. **Benchmark after each optimization**
4. **Target**: Achieve 1.0 MB/sec (15x improvement) with Phase 2
5. **Stretch goal**: 5.0 MB/sec requires architectural changes (Phase 4)

## Comparison with Previous Findings

Our ObjectSpace profiling showed:
- 9.6M objects allocated for 186KB
- 6.9M arrays, 1.6M strings, 1.5M Position/Slice

Ruby-prof profiling confirms:
- Context operations create excessive hash operations
- Position initialization is expensive
- Array operations (from sequences, alternatives) are frequent

Both profiling methods point to the same root causes:
1. Excessive object allocation
2. Context cache overhead
3. Position tracking overhead

## Files to Modify for Phase 2

1. `lib/parslet/atoms/context.rb` - Smart caching
2. `lib/parslet/position.rb` - Object pooling
3. `lib/parslet/source.rb` - Position caching
4. `lib/parslet/atoms/base.rb` - Cache decisions

## Success Metrics

- Reduce Context#try_with_cache from 19% to <5%
- Reduce Position#initialize from 2.88% to <0.5%
- Reduce total hash operations by 50%
- Achieve 1.0+ MB/sec throughput (15x improvement)
