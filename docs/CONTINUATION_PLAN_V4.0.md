# Continuation Plan: v4.0 Architectural Overhaul

**Session**: v4.0 Development  
**Priority**: HIGH  
**Goal**: Implement architectural changes to achieve 5-10x performance improvement  
**Duration**: 3-6 months (compressed timeline)  
**Status**: Ready to execute

---

## Context from v3.0.0

### Current State (v3.0.0)
- **Performance**: 1.52x average improvement over original Parslet
- **Tests**: 713/714 passing (99.86%)
- **Architecture**: Model-based, position elimination, string optimization complete

### Identified Bottlenecks (Session 19)
1. **GC Overhead**: 67% of CPU time spent in garbage collection
2. **Array Allocations**: 74% of memory from Array objects
3. **Optimization Plateau**: Micro-optimizations unmeasurable within ±30-50% variance

### v4.0 Target
- **Performance Goal**: 5-10x improvement over v3.0.0 (7.5-15x over original Parslet)
- **Architecture**: Zero-copy parsing, object pooling, streaming results
- **Compatibility**: Breaking changes allowed with migration guide

---

## Phase 1: Object Pooling (Weeks 1-4) 🔴 CRITICAL

### Goal: Reduce GC Overhead from 67% to 20%

#### 1.1: Implement Object Pool Infrastructure

**Create**: `lib/parslet/pool.rb`

```ruby
# Object pool for reusable parser objects
class Parslet::ObjectPool
  def initialize(klass, size: 1000)
    @klass = klass
    @available = []
    @size = size
    preallocate
  end

  def acquire
    @available.pop || @klass.new
  end

  def release(obj)
    return if @available.size >= @size
    obj.reset! if obj.respond_to?(:reset!)
    @available.push(obj)
  end

  private

  def preallocate
    @size.times { @available.push(@klass.new) }
  end
end
```

**Files to create**:
- `lib/parslet/pool.rb` - Base pool implementation
- `lib/parslet/pools/slice_pool.rb` - Slice-specific pool
- `lib/parslet/pools/array_pool.rb` - Array buffer pool
- `spec/parslet/pool_spec.rb` - Pool tests

#### 1.2: Pool Slice Objects

**Modify**: `lib/parslet/slice.rb`

Add pooling support:
- `Slice.acquire(pos, str)` - Get from pool
- `Slice#release` - Return to pool
- `Slice#reset!(pos, str)` - Reset for reuse

**Expected impact**: -30% GC time (67% → 47%)

#### 1.3: Pool Array Buffers

**Modify**: `lib/parslet/atoms/base.rb`, `lib/parslet/atoms/repetition.rb`

Replace:
```ruby
result = []  # Creates new array each time
```

With:
```ruby
result = ArrayPool.acquire  # Reuse pre-allocated array
```

**Expected impact**: -20% GC time (47% → 27%)

#### 1.4: Pool Position Objects (Error Reporting)

**Create**: `lib/parslet/pools/position_pool.rb`

Pool Position objects used only for error reporting:
- Keep integer positions during parsing (v3.0.0 architecture)
- Pool Position objects for error materialization

**Expected impact**: -7% GC time (27% → 20%)

---

## Phase 2: Pre-allocation Strategies (Weeks 5-8) 🟡 HIGH PRIORITY

### Goal: Reduce Array Allocations from 74% to 30%

#### 2.1: Fixed-Size Buffer Pre-allocation

**Create**: `lib/parslet/buffer.rb`

```ruby
class Parslet::Buffer
  # Pre-allocated buffers for common sizes
  SIZES = [16, 64, 256, 1024, 4096]

  def self.get(size)
    pool_size = SIZES.find { |s| s >= size } || size
    BufferPool.acquire(pool_size)
  end
end
```

**Expected impact**: -20% Array allocations (74% → 54%)

#### 2.2: Lazy Result Materialization

**Modify**: `lib/parslet/atoms/base.rb`

Defer array creation until needed:
```ruby
class LazyResult
  def initialize(&block)
    @block = block
    @materialized = false
  end

  def to_a
    return @result if @materialized
    @result = @block.call
    @materialized = true
    @result
  end
end
```

**Expected impact**: -14% Array allocations (54% → 40%)

#### 2.3: Result Builder with Buffer Reuse

**Create**: `lib/parslet/result_builder.rb`

```ruby
class Parslet::ResultBuilder
  def initialize(capacity = 256)
    @buffer = Buffer.get(capacity)
    @size = 0
  end

  def append(item)
    grow if @size >= @buffer.size
    @buffer[@size] = item
    @size += 1
  end

  def to_result
    @buffer[0...@size]  # Slice to actual size
  end
end
```

**Expected impact**: -10% Array allocations (40% → 30%)

---

## Phase 3: Zero-Copy Parsing (Weeks 9-12) 🟡 HIGH PRIORITY

### Goal: Minimize String Operations

#### 3.1: String View Implementation

**Create**: `lib/parslet/string_view.rb`

```ruby
class Parslet::StringView
  def initialize(string, offset, length)
    @string = string
    @offset = offset
    @length = length
  end

  def to_s
    @string[@offset, @length]  # Only materialize when needed
  end

  def [](index)
    @string[@offset + index]
  end
end
```

**Expected impact**: -15% string allocations

#### 3.2: Rope Optimization (from v3.2 plan)

**Implement**: Deferred string concatenation
- Use rope data structure for character accumulation
- Single final string materialization
- Integrate with StringView for efficiency

**Expected impact**: -10% string allocations

#### 3.3: Immutable String Sharing

**Strategy**: Share immutable string segments
- Reference original input string where possible
- Avoid copying unchanging segments
- Use offsets instead of substrings

**Expected impact**: -5% string allocations

---

## Phase 4: Streaming Results API (Weeks 13-16) 🟢 MEDIUM PRIORITY

### Goal: Reduce Memory Footprint

#### 4.1: Iterator-Based Result Building

**Create**: `lib/parslet/result_stream.rb`

```ruby
class Parslet::ResultStream
  include Enumerable

  def initialize(parse_tree)
    @tree = parse_tree
  end

  def each
    return enum_for(:each) unless block_given?
    traverse(@tree) { |item| yield item }
  end

  private

  def traverse(node, &block)
    case node
    when Array then node.each { |n| traverse(n, &block) }
    when Hash then node.each_value { |v| traverse(v, &block) }
    else yield node
    end
  end
end
```

**Expected impact**: -30% peak memory usage

#### 4.2: Incremental Tree Construction

**Modify**: `lib/parslet/atoms/base.rb`

Build parse tree incrementally:
- Yield results as they're parsed
- Don't accumulate full tree in memory
- Compatible with streaming transformations

**Expected impact**: -20% peak memory usage

#### 4.3: On-Demand Flattening

**Strategy**: Flatten only when accessed
- Keep tree structure during parsing
- Flatten lazily on first access
- Cache flattened result

**Expected impact**: -10% CPU time in flattening

---

## Phase 5: Native Extensions (Weeks 17-20) 🔵 OPTIONAL

### Goal: 2-3x Additional Speedup

#### 5.1: C Extension for Hot Paths

**Create**: `ext/parslet/parslet.c`

Implement in C:
- Character matching (`match[...]`)
- String matching (`str('...')`)
- Position tracking
- Slice operations

**Expected impact**: +100-200% speedup in hot paths

#### 5.2: Native Buffer Management

**Implement**: Memory-efficient buffers in C
- Pre-allocated native buffers
- Zero-copy string handling
- Direct memory operations

**Expected impact**: +50% memory efficiency

---

## Phase 6: Parallel Parsing (Weeks 21-24) 🔵 EXPERIMENTAL

### Goal: Multi-Core Utilization

#### 6.1: Ractor-Based Parallel Parsing

**Create**: `lib/parslet/parallel.rb`

```ruby
class Parslet::ParallelParser
  def parse_chunks(input, chunk_size)
    chunks = input.each_slice(chunk_size)
    
    workers = chunks.map do |chunk|
      Ractor.new(chunk) do |c|
        parser = Parslet::Parser.new
        parser.parse(c)
      end
    end
    
    workers.map(&:take)  # Collect results
  end
end
```

**Expected impact**: +200-400% for large inputs

#### 6.2: Fiber-Based Concurrent Parsing

**Strategy**: Use Fibers for I/O-bound parsing
- Non-blocking I/O operations
- Concurrent parsing of multiple streams
- Efficient resource utilization

**Expected impact**: +50-100% for I/O-heavy workloads

---

## Architecture Principles

### 1. Object-Oriented Design (MECE)
- Each class has single, well-defined responsibility
- Clear separation of concerns
- Mutually Exclusive, Collectively Exhaustive

### 2. Extensibility (Open/Closed)
- Open for extension, closed for modification
- Plugin architecture for optimization strategies
- User-replaceable pooling strategies

### 3. Backward Compatibility Strategy
- v4.0 allows breaking changes (major version)
- Provide compatibility layer for v3.x
- Clear migration guide
- Deprecation warnings in v3.x series

---

## Testing Strategy

### Unit Tests
- Each new class: dedicated spec file
- Pool behavior: acquire/release/reset
- Buffer management: growth, reuse
- String views: correctness, immutability

### Integration Tests
- End-to-end parsing with pools
- Memory usage verification
- Performance regression tests
- Compatibility layer validation

### Performance Tests
- GC profiling (target: 20% from 67%)
- Array allocation profiling (target: 30% from 74%)
- Memory profiling (peak usage)
- Throughput benchmarks (5-10x target)

---

## Migration Guide (Required for v4.0)

### Breaking Changes
1. **API Changes**
   - Direct Slice manipulation deprecated
   - New streaming API required for large inputs
   - Pool management optional but recommended

2. **Behavior Changes**
   - Slice objects may be reused (don't store references)
   - Results may be lazy (call `.to_a` to materialize)
   - Position objects only for errors (not during parsing)

### Migration Steps
```ruby
# v3.x code
result = parser.parse(input)

# v4.0 code (streaming)
stream = parser.parse_stream(input)
result = stream.to_a  # Materialize if needed

# v4.0 code (with pools, optimal)
Parslet.configure do |config|
  config.enable_pooling = true
  config.pool_size = 10_000
end
result = parser.parse(input)
```

---

## Compressed Timeline

### Month 1 (Weeks 1-4): Object Pooling
- Week 1: Pool infrastructure
- Week 2: Slice pooling
- Week 3: Array pooling
- Week 4: Position pooling + validation

### Month 2 (Weeks 5-8): Pre-allocation
- Week 5: Fixed-size buffers
- Week 6: Lazy materialization
- Week 7: Result builder
- Week 8: Integration + benchmarks

### Month 3 (Weeks 9-12): Zero-Copy
- Week 9: String views
- Week 10: Rope optimization
- Week 11: Immutable sharing
- Week 12: Performance validation

### Month 4 (Weeks 13-16): Streaming
- Week 13: Result stream iterator
- Week 14: Incremental tree building
- Week 15: On-demand flattening
- Week 16: API finalization

### Month 5-6 (Weeks 17-24): Optional Enhancements
- Weeks 17-20: Native extensions (if beneficial)
- Weeks 21-24: Parallel parsing (if beneficial)

---

## Success Criteria

### Performance Targets
- [ ] **5x minimum improvement** over v3.0.0
- [ ] **10x target improvement** over v3.0.0
- [ ] **GC time**: 67% → 20% (47% reduction)
- [ ] **Array allocations**: 74% → 30% (44% reduction)
- [ ] **Memory footprint**: -50% peak usage

### Quality Gates
- [ ] All 713 core tests passing
- [ ] New tests for v4.0 features
- [ ] No memory leaks (valgrind/memory profiler)
- [ ] Comprehensive migration guide
- [ ] Updated documentation (README, guides)

### Architecture Quality
- [ ] Object-oriented design (MECE principles)
- [ ] Separation of concerns maintained
- [ ] Extensibility via plugins
- [ ] Open/closed principle followed

---

## Risk Management

### High Risk: Object Pooling
**Risk**: Memory leaks, incorrect reuse  
**Mitigation**:
- Comprehensive reset! methods
- Pool size limits
- Monitoring tools
- Memory profiling at every stage

### Medium Risk: Breaking Changes
**Risk**: User migration burden  
**Mitigation**:
- Clear migration guide
- Compatibility layer
- Beta testing period
- Community feedback

### Low Risk: Performance Target
**Risk**: Not achieving 5-10x target  
**Mitigation**:
- Incremental validation
- Profiling at each phase
- Fallback strategies
- Clear documentation of achieved improvements

---

## Documentation Updates Required

### During Development
- [ ] Update `ARCHITECTURE_V4_PLAN.adoc` with actual implementation
- [ ] Create `docs/V4_MIGRATION_GUIDE.adoc`
- [ ] Update `README.adoc` performance section
- [ ] Create `docs/V4_POOLING_GUIDE.adoc`

### Before Release
- [ ] Complete API documentation
- [ ] Update all code examples
- [ ] Create upgrade checklist
- [ ] Performance comparison charts

---

## Next Steps

1. **Immediate**: Begin Phase 1.1 (Object Pool Infrastructure)
2. **Week 1**: Complete pool implementation + tests
3. **Week 2**: Integrate Slice pooling
4. **Week 3**: Integrate Array pooling
5. **Week 4**: Validate GC reduction (target: 67% → 47%)

---

**Let's build v4.0 and achieve 5-10x performance improvement! 🚀**