# Continuation Prompt: v4.0 Phase 1.1 - Object Pool Infrastructure

**Session**: v4.0 Phase 1.1  
**Priority**: CRITICAL  
**Goal**: Implement base object pooling infrastructure  
**Duration**: Week 1 of 24 weeks  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, a highly skilled software engineer tasked with implementing the architectural foundation for plurimath-parslet v4.0. Your focus is on creating a robust, object-oriented object pooling system that will reduce GC overhead from 67% to 20%.

---

## Critical Context

### Current State (v3.0.0)
- **Performance**: 1.52x over original Parslet
- **Bottleneck #1**: GC overhead 67% of CPU time
- **Bottleneck #2**: Array allocations 74% of memory
- **Tests**: 713/714 passing (99.86%)

### v4.0 Target
- **Performance Goal**: 5-10x improvement over v3.0.0
- **Phase 1 Goal**: Reduce GC from 67% to 20% via object pooling
- **Timeline**: 24 weeks compressed (3-6 months)

### Why Object Pooling?
Session 19 profiling identified that 67% of CPU time is spent in garbage collection. By reusing objects instead of creating new ones, we can dramatically reduce GC pressure and achieve 2-3x throughput improvement from GC reduction alone.

---

## Your Task

Implement Phase 1.1 from the continuation plan: **Object Pool Infrastructure**.

Follow the implementation plan in [`docs/CONTINUATION_PLAN_V4.0.md`](CONTINUATION_PLAN_V4.0.md) and track progress in [`docs/IMPLEMENTATION_STATUS_V4.0.md`](IMPLEMENTATION_STATUS_V4.0.md).

---

## Phase 1.1: Object Pool Infrastructure (Week 1)

### Objective

Create a robust, reusable object pooling system that follows object-oriented principles:
- **MECE** (Mutually Exclusive, Collectively Exhaustive)
- **Single Responsibility**: Each class has one clear purpose
- **Open/Closed**: Open for extension, closed for modification
- **Separation of Concerns**: Pool management, object lifecycle, statistics separate

### Implementation Requirements

#### 1. Base ObjectPool Class

**File**: `lib/parslet/pool.rb`

**Design Principles**:
- Generic pool that works with any class
- Configurable pool size
- Pre-allocation for efficiency
- Statistics tracking (optional but recommended)
- Thread-safety consideration (document if not implemented)

**Required API**:
```ruby
class Parslet::ObjectPool
  # Initialize pool for given class
  def initialize(klass, size: 1000)
  
  # Get object from pool (create new if empty)
  def acquire
  
  # Return object to pool (calls reset! if available)
  def release(obj)
  
  # Statistics (optional but recommended)
  def stats
    {
      size: @size,
      available: @available.size,
      created: @created_count,
      reused: @reused_count
    }
  end
end
```

**Implementation Details**:
- Use array for available objects (`@available`)
- Track pool size limit
- Pre-allocate objects on initialization
- Call `obj.reset!` before returning to pool (if method exists)
- Don't exceed pool size (discard extras)

**Example Usage**:
```ruby
# Create pool for Slice objects
slice_pool = Parslet::ObjectPool.new(Parslet::Slice, size: 1000)

# Acquire from pool
slice = slice_pool.acquire
slice.reset!(0, "hello")  # Initialize for use

# Use slice...

# Return to pool
slice_pool.release(slice)
```

#### 2. Specialized Pools

**SlicePool**: `lib/parslet/pools/slice_pool.rb`

```ruby
class Parslet::SlicePool < Parslet::ObjectPool
  def initialize(size: 1000)
    super(Parslet::Slice, size: size)
  end
  
  # Convenience method
  def acquire_with(bytepos, str)
    slice = acquire
    slice.reset!(bytepos, str)
    slice
  end
end
```

**ArrayPool**: `lib/parslet/pools/array_pool.rb`

```ruby
class Parslet::ArrayPool < Parslet::ObjectPool
  def initialize(size: 1000)
    super(Array, size: size)
  end
  
  def release(array)
    array.clear  # Reset array before pooling
    super(array)
  end
end
```

#### 3. Comprehensive Tests

**File**: `spec/parslet/pool_spec.rb`

Test cases required:
- Pool initialization
- Object acquisition (from pool)
- Object acquisition (new when empty)
- Object release
- Pool size limits (don't exceed)
- Reset method called on release
- Statistics tracking (if implemented)
- Multiple acquire/release cycles

**File**: `spec/parslet/pools/slice_pool_spec.rb`

Test cases required:
- Slice-specific pool behavior
- `acquire_with` convenience method
- Slice reset working correctly
- Integration with Slice class

**File**: `spec/parslet/pools/array_pool_spec.rb`

Test cases required:
- Array-specific pool behavior
- Array clearing on release
- Array reuse correctness

---

## Architecture Principles to Follow

### 1. Object-Oriented Design (MECE)

**Good Example**:
```ruby
# MECE: Clear separation of concerns
class ObjectPool
  # Responsibility: Manage pool lifecycle
end

class SlicePool < ObjectPool
  # Responsibility: Slice-specific behavior
end

class Slice
  # Responsibility: Slice operations
  def reset!(pos, str)
    # Reset for reuse
  end
end
```

**Bad Example**:
```ruby
# Not MECE: Mixed concerns
class Slice
  def self.pool_acquire
    # Pool management in Slice class - wrong!
  end
end
```

### 2. Open/Closed Principle

The base `ObjectPool` should work with any class without modification:

```ruby
# Extension, not modification
class CustomPool < ObjectPool
  def custom_behavior
    # Extend behavior
  end
end
```

### 3. Single Responsibility

Each class has ONE clear responsibility:
- `ObjectPool`: Manage object lifecycle in pool
- `SlicePool`: Slice-specific pool configuration
- `Slice`: Slice operations and reset

---

## Testing Strategy

### Unit Tests
- Test each pool class independently
- Mock or stub objects where needed
- Test edge cases (empty pool, full pool, etc.)
- Test reset behavior

### Integration Tests
- Test pool with real Slice objects
- Verify object reuse working correctly
- Ensure no memory leaks
- Validate statistics (if implemented)

### Performance Tests
- Benchmark pool acquisition vs. new object creation
- Measure pool overhead (should be <1%)
- Profile memory usage

---

## Validation Checklist

Before marking Phase 1.1 complete:

- [ ] `lib/parslet/pool.rb` created with full API
- [ ] `lib/parslet/pools/slice_pool.rb` created
- [ ] `lib/parslet/pools/array_pool.rb` created
- [ ] `spec/parslet/pool_spec.rb` created (>90% coverage)
- [ ] `spec/parslet/pools/slice_pool_spec.rb` created
- [ ] `spec/parslet/pools/array_pool_spec.rb` created
- [ ] All tests passing
- [ ] No memory leaks (run with profiling)
- [ ] Pool overhead <1% (benchmark validation)
- [ ] Code follows OOP principles
- [ ] Documentation comments added

---

## Success Criteria

### Functional Requirements
- Object pool working correctly
- Objects can be acquired and released
- Pool size limits respected
- Reset methods called properly
- Specialized pools for Slice and Array

### Quality Requirements
- Test coverage >90%
- All tests passing
- No memory leaks
- Code follows OOP principles (MECE, SRP, O/C)
- Clear separation of concerns

### Performance Requirements
- Pool overhead <1% compared to direct allocation
- Pre-allocation reduces startup cost
- Object reuse measurable

---

## Red Flags to Avoid

### ❌ Don't Do This:

1. **Mixing concerns**:
```ruby
class Slice
  @@pool = []  # Pool management in Slice - wrong!
end
```

2. **Hardcoding class names**:
```ruby
def acquire
  Slice.new  # Should use @klass
end
```

3. **No reset before reuse**:
```ruby
def release(obj)
  @available.push(obj)  # Forgot to reset!
end
```

4. **Unbounded pool growth**:
```ruby
def release(obj)
  @available.push(obj)  # No size check - memory leak!
end
```

### ✅ Do This Instead:

1. **Separation of concerns**:
```ruby
# Pool manages lifecycle
class ObjectPool
  def acquire
    @available.pop || @klass.new
  end
end

# Slice handles operations
class Slice
  def reset!(pos, str)
    @bytepos = pos
    @str = str
  end
end
```

2. **Generic implementation**:
```ruby
def acquire
  @available.pop || @klass.new  # Uses configurable class
end
```

3. **Proper reset**:
```ruby
def release(obj)
  obj.reset! if obj.respond_to?(:reset!)
  @available.push(obj)
end
```

4. **Size limits**:
```ruby
def release(obj)
  return if @available.size >= @size  # Respect limit
  obj.reset! if obj.respond_to?(:reset!)
  @available.push(obj)
end
```

---

## Implementation Order

### Day 1: Base Pool
1. Create `lib/parslet/pool.rb`
2. Implement `ObjectPool` class
3. Add acquire/release methods
4. Add pre-allocation
5. Add size limits

### Day 2: Tests
1. Create `spec/parslet/pool_spec.rb`
2. Test all pool behaviors
3. Test edge cases
4. Validate correctness

### Day 3: Specialized Pools
1. Create `lib/parslet/pools/slice_pool.rb`
2. Create `lib/parslet/pools/array_pool.rb`
3. Create corresponding specs
4. Test specializations

### Day 4: Integration & Validation
1. Run full test suite
2. Memory profiling (no leaks)
3. Performance benchmarking
4. Documentation review

### Day 5: Polish & Complete
1. Code review
2. Documentation completion
3. Update implementation status
4. Prepare for Phase 1.2

---

## Expected Output

After completing Phase 1.1, you should have:

1. **Files Created** (7 files):
   - `lib/parslet/pool.rb`
   - `lib/parslet/pools/slice_pool.rb`
   - `lib/parslet/pools/array_pool.rb`
   - `spec/parslet/pool_spec.rb`
   - `spec/parslet/pools/slice_pool_spec.rb`
   - `spec/parslet/pools/array_pool_spec.rb`

2. **Tests Passing**:
   - All new pool tests passing (>30 examples)
   - Existing test suite still passing (713/714)
   - No test regressions

3. **Performance Baseline**:
   - Pool overhead measured (<1% target)
   - Object reuse verified
   - Memory profile clean (no leaks)

4. **Documentation**:
   - Code comments explaining design
   - Usage examples in comments
   - Updated implementation status

---

## Next Phase Preview

After Phase 1.1 completes, Phase 1.2 will:
- Integrate SlicePool with Slice class
- Modify all Slice creation to use pool
- Update `lib/parslet/atoms/str.rb`
- Update `lib/parslet/atoms/repetition.rb`
- Measure GC reduction (target: 67% → 57%)

But focus on Phase 1.1 first! Build solid foundation.

---

## Questions to Consider

As you implement, think about:

1. **Thread Safety**: Do we need thread-safe pools? Document decision.
2. **Pool Warming**: Should pools pre-allocate on first use or initialization?
3. **Statistics**: Are pool statistics useful for debugging? Worth the overhead?
4. **Pool Size**: Is 1000 a good default? Should it be tunable?
5. **Reset Protocol**: Is `reset!` a good convention? Should we enforce interface?

Document your decisions in code comments.

---

## Debugging Tips

If things go wrong:

1. **Memory Leaks**:
   - Check pool size limits working
   - Verify objects being released
   - Use memory profiler (memory_profiler gem)

2. **Test Failures**:
   - Verify reset! being called
   - Check object state after reuse
   - Validate pool size logic

3. **Performance Issues**:
   - Profile pool overhead
   - Check pre-allocation working
   - Verify no unnecessary allocations

---

## Git Workflow

### Commits

Use semantic commit messages:

```bash
# Feature commits
git commit -m "feat(pool): implement base ObjectPool class"
git commit -m "feat(pool): add SlicePool and ArrayPool"

# Test commits
git commit -m "test(pool): add comprehensive pool tests"

# Documentation commits
git commit -m "docs(pool): add pool architecture documentation"
```

### Notes

- Commit frequently (after each logical step)
- Keep commits focused (one feature/fix per commit)
- Update IMPLEMENTATION_STATUS_V4.0.md as you go

---

## Resources

### Existing Code to Review
- [`lib/parslet/slice.rb`](../lib/parslet/slice.rb) - Understand Slice structure
- [`lib/parslet/rope.rb`](../lib/parslet/rope.rb) - Existing rope implementation
- [`lib/parslet/atoms/base.rb`](../lib/parslet/atoms/base.rb) - Base atom structure

### Documentation
- [`docs/CONTINUATION_PLAN_V4.0.md`](CONTINUATION_PLAN_V4.0.md) - Full v4.0 plan
- [`docs/ARCHITECTURE_V4_PLAN.adoc`](ARCHITECTURE_V4_PLAN.adoc) - Architecture overview
- [`docs/SESSION_19_COMPLETE.md`](SESSION_19_COMPLETE.md) - Profiling findings

### Testing
- Existing `spec/` files - Follow same testing patterns
- RSpec documentation for test structure

---

## Important Reminders

1. **Architecture First**: Focus on correct OOP design, not just "make it work"
2. **MECE Principle**: Ensure classes are mutually exclusive, collectively exhaustive
3. **Test Thoroughly**: >90% coverage, edge cases, integration tests
4. **No Shortcuts**: Don't lower standards, proper implementation required
5. **Document Decisions**: Comment WHY, not just WHAT

---

## Expected Timeline

- **Day 1**: Base ObjectPool implementation
- **Day 2**: Comprehensive testing
- **Day 3**: Specialized pools (Slice, Array)
- **Day 4**: Integration validation
- **Day 5**: Polish and completion

**Total**: 5 days for Phase 1.1

After completion, we move to Phase 1.2 (Slice integration).

---

**Let's build the foundation for v4.0! Focus on quality architecture and thorough testing. 🏗️**