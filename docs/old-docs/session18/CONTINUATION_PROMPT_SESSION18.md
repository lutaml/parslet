# Continuation Prompt: Session 18 - Integer Positions Optimization

**Session**: 18  
**Priority**: HIGH  
**Goal**: Replace Position objects with integer positions to achieve 1.35-1.40x cumulative performance  
**Duration**: 7 days (compressed timeline)  
**Status**: Ready to execute

---

## Your Role

You are Kilo Code, a highly skilled software engineer tasked with implementing integer-based position tracking to optimize Parslet's performance by eliminating Position object allocation overhead.

---

## Critical Context from Session 17

### Performance Baseline (v3.2.0)

**Current Performance**:
- Average speedup: **1.27x** ±0.01x (validated across 3 runs)
- Improvement: **+1.6%** over v3.1.0 baseline (1.25x)
- Stability: **100%** of test cases faster
- Tests: **712/713 passing** (1 pre-existing failure)

### Architectural Insight from Session 17

**Key Finding**: Rope optimization (Session 17) had limited impact because:
1. String concatenation happens during **parser construction** (one-time cost)
2. Real performance gains require optimizing the **parsing hot path**
3. Session 15 profiling identified Position object allocation as bottleneck

**Conclusion**: Position object creation/manipulation is THE hot path optimization target.

---

## Mission

Eliminate Position object overhead by using integer-based position tracking throughout the parsing hot path.

### Target Improvement

- **Primary target**: ≥1.35x average (vs. current 1.27x)
- **Stretch target**: 1.40x average
- **Regression threshold**: Must maintain ≥1.25x
- **Quality**: All 712 tests must pass

---

## Your Task

Follow the implementation plan in [`docs/CONTINUATION_PLAN_SESSION18.md`](CONTINUATION_PLAN_SESSION18.md) and track progress in [`docs/IMPLEMENTATION_STATUS_SESSION18.md`](IMPLEMENTATION_STATUS_SESSION18.md).

### Phase 1: Position Analysis (Day 1) 🔴 CRITICAL

**Your Task**: Analyze current Position usage and design integer-based replacement

#### 1.1: Analyze Current Position Usage

**Search for Position usage**:
```bash
# Find Position object creation
grep -r "Position.new" lib/

# Find Position method calls
grep -r "\.pos\>" lib/
grep -r "@position" lib/

# Find charpos/bytepos usage
grep -r "charpos\|bytepos" lib/
```

**Document**:
- All files creating Position objects
- Hot path Position method calls
- Position -> Slice dependencies
- Current Position API surface

**Deliverable**: Create `docs/POSITION_ANALYSIS.md` with findings.

#### 1.2: Design Integer Position System

**Design Requirements**:
1. **Representation**: Integer bytepos (primary), charpos (derived)
2. **Slice Integration**: `Slice.new(bytepos, string, line_cache)`
3. **Source Integration**: `Source#pos` returns integer
4. **LineCache**: Already uses integers (no changes)
5. **Backward Compatibility**: Maintain existing Slice API

**Key Decision Points**:
- When to calculate charpos? (Lazy, on-demand only)
- How to handle line/column? (Keep LineCache unchanged)
- Migration strategy? (Update all atoms at once vs incrementally)

**Document design in** `docs/POSITION_ANALYSIS.md`.

---

### Phase 2: Slice Refactoring (Day 2-3) 🔴 CRITICAL

**Your Task**: Update Slice to use integer positions

#### 2.1: Update Slice Implementation

Modify [`lib/parslet/slice.rb`](../../lib/parslet/slice.rb):

**Current code**:
```ruby
class Slice
  def initialize(position, string, line_cache = nil)
    @position = position  # Position object
    @str = string
    @line_cache = line_cache
    @offset = nil
  end
  
  def offset
    @offset ||= @position.charpos
  end
end
```

**New code**:
```ruby
class Slice
  def initialize(bytepos, string, line_cache = nil)
    @bytepos = bytepos  # Integer, not Position object
    @str = string
    @line_cache = line_cache
  end
  
  def offset
    @bytepos  # Return integer directly
  end
  
  alias bytepos offset
  alias charpos offset  # For backward compatibility
  
  def line_and_column
    raise ArgumentError, 'No line cache was given, cannot infer line and column.' \
      unless line_cache
    
    line_cache.line_and_column(@bytepos)  # Already uses integer
  end
end
```

**Also update**:
- `Slice#+` operator if needed (check usage)
- `Slice.from_rope` if it uses Position

#### 2.2: Update Slice Tests

Modify [`spec/parslet/slice_spec.rb`](../../spec/parslet/slice_spec.rb):

**Replace Position objects with integers**:
```ruby
# OLD
slice = Slice.new(Position.new(string, 40, 6), 'foobar')

# NEW
slice = Slice.new(6, 'foobar')
```

**Add tests for aliases**:
```ruby
describe '#bytepos' do
  it 'returns byte position' do
    slice = Slice.new(10, 'test')
    expect(slice.bytepos).to eq(10)
  end
end

describe '#charpos' do
  it 'returns same as offset for ASCII' do
    slice = Slice.new(10, 'test')
    expect(slice.charpos).to eq(10)
  end
end
```

**Validation**: Run `bundle exec rspec spec/parslet/slice_spec.rb` - all tests must pass.

---

### Phase 3: Source Refactoring (Day 3-4) 🔴 CRITICAL

**Your Task**: Update Source to return integer positions

#### 3.1: Update Source Implementation

Modify [`lib/parslet/source.rb`](../../lib/parslet/source.rb):

**Find and replace**:
```ruby
# OLD
def pos
  Position.new(@str, @bytepos, @charpos)
end

# NEW
def pos
  @bytepos  # Return integer directly
end

alias bytepos pos  # For clarity
```

**Verify**:
- `@bytepos` is maintained correctly
- Position tracking still works
- No other Position object creation in Source

#### 3.2: Update Source Tests

Modify [`spec/parslet/source_spec.rb`](../../spec/parslet/source_spec.rb):

Replace Position expectations with integer expectations.

**Validation**: Run `bundle exec rspec spec/parslet/source_spec.rb` - all tests must pass.

---

### Phase 4: Atom Updates (Day 4-5) 🟡 HIGH PRIORITY

**Your Task**: Update all atoms to use integer positions

**Pattern to apply across all atoms**:
```ruby
# OLD
result = Slice.new(source.pos, matched_string, source.line_cache)

# NEW
result = Slice.new(source.bytepos, matched_string, source.line_cache)
```

**Files to update** (in order):
1. [`lib/parslet/atoms/str.rb`](../../lib/parslet/atoms/str.rb)
2. [`lib/parslet/atoms/re.rb`](../../lib/parslet/atoms/re.rb)
3. [`lib/parslet/atoms/repetition.rb`](../../lib/parslet/atoms/repetition.rb)
4. [`lib/parslet/atoms/sequence.rb`](../../lib/parslet/atoms/sequence.rb)
5. [`lib/parslet/atoms/alternative.rb`](../../lib/parslet/atoms/alternative.rb)
6. [`lib/parslet/atoms/lookahead.rb`](../../lib/parslet/atoms/lookahead.rb)
7. Any other atoms in `lib/parslet/atoms/`

**Strategy**:
- Update one atom at a time
- Run its specific test after each change
- Fix any failures before moving to next atom
- Run full test suite after all atoms updated

**Validation**: Run `bundle exec rspec spec/parslet/atoms/` - all tests must pass.

---

### Phase 5: Verification (Day 5) 🟡 HIGH PRIORITY

**Your Task**: Verify LineCache and error reporting work with integers

#### 5.1: Verify LineCache Compatibility

Good news: **LineCache already uses integer bytepos**!

**Verify**:
```ruby
# Check that LineCache#line_and_column accepts integers
cache = Parslet::Source::LineCache.new
line, col = cache.line_and_column(42)  # Should work
```

**Validation**: Run `bundle exec rspec spec/parslet/source/line_cache_spec.rb` - all tests must pass.

#### 5.2: Verify Error Reporting

**Files to check**:
- [`lib/parslet/cause.rb`](../../lib/parslet/cause.rb) - Error causes
- [`lib/parslet/error_reporter.rb`](../../lib/parslet/error_reporter.rb) - Error messages
- [`lib/parslet/atoms/context.rb`](../../lib/parslet/atoms/context.rb) - Error context

**Verify**:
- Error messages show correct positions
- Line/column calculation works
- No Position object assumptions in error handling

---

### Phase 6: Benchmark and Validate (Day 6) 🔴 CRITICAL

**Your Task**: Validate performance improvement

#### 6.1: Run Full Test Suite

```bash
bundle exec rspec
```

**Expected results**:
- 712/713 tests passing (maintain baseline)
- 1 pre-existing failure unchanged
- No new failures

#### 6.2: Run Performance Benchmarks (3 Runs)

```bash
# Run 1
ruby benchmark/fair_comparison.rb

# Wait 60 seconds
sleep 60

# Run 2
ruby benchmark/fair_comparison.rb

# Wait 60 seconds
sleep 60

# Run 3
ruby benchmark/fair_comparison.rb
```

**Expected results**:
- Overall average: **1.35-1.40x** (vs. 1.27x v3.2.0)
- Stable runs show average ≥1.35x
- No regressions: All cases ≥1.20x
- JSON parser: **1.60x+** (best case)
- At least **8/14 cases ≥1.35x**

Run **3 times with 60-second cooldown** between runs to validate stability.

#### 6.3: Profile Performance (Optional)

```bash
# Profile allocations
ruby -r memory_profiler benchmark/profile_allocations.rb

# Profile CPU
ruby -r stackprof benchmark/profile_hotspots.rb
```

**Verify**:
- Position object allocations eliminated or near-zero
- Memory usage reduced
- No new bottlenecks introduced

---

### Phase 7: Documentation (Day 7) 🟡 HIGH PRIORITY

**Your Task**: Update all documentation with v3.3.0 results

#### 7.1: Update Performance Benchmarks

Update [`docs/PERFORMANCE_BENCHMARKS.adoc`](PERFORMANCE_BENCHMARKS.adoc):

Add v3.3.0 results section showing improvement over v3.2.0.

#### 7.2: Update Architecture Roadmap

Update [`docs/ARCHITECTURE_V4_PLAN.adoc`](ARCHITECTURE_V4_PLAN.adoc):

Mark Phase 2 (v3.3.0 Integer Positions) as complete with achieved metrics.

#### 7.3: Update README

Update [`README.adoc`](../../README.adoc):

Update performance numbers from 1.27x to achieved average (target: 1.37x).

#### 7.4: Create Release Notes

Create [`docs/RELEASE_NOTES_v3.3.0.md`](RELEASE_NOTES_v3.3.0.md):

Document changes, performance improvements, and any breaking changes.

#### 7.5: Create Session Completion Document

Create [`docs/SESSION_18_COMPLETE.md`](SESSION_18_COMPLETE.md):

Document achievements, lessons learned, and recommendations for v3.4.0.

---

## Critical Principles (MUST FOLLOW)

### Object-Oriented Architecture

1. **Single Responsibility**: Position tracking is separate from other concerns
2. **Open/Closed**: Changes extend behavior without modifying existing contracts
3. **Separation of Concerns**: Position != LineCache != Slice
4. **Backward Compatibility**: Maintain existing public APIs

### MECE (Mutually Exclusive, Collectively Exhaustive)

1. **bytepos**: Primary position (always integer)
2. **charpos**: Derived position (calculated if needed)
3. **line/column**: External concern (handled by LineCache)
4. **No overlap**: Each attribute has distinct meaning

### Testing Philosophy

1. **Behavior correctness > passing tests**: If tests fail, verify expected behavior first
2. **Update tests if needed**: Tests may need adjustment to integer expectations
3. **Incremental testing**: Test after each atom update
4. **Full validation**: Run complete suite before benchmarking

---

## Quick Start Commands

```bash
# 1. Analyze Position usage
grep -r "Position.new" lib/
grep -r "\.pos\>" lib/

# 2. Update Slice (Phase 2.1)
# Edit lib/parslet/slice.rb

# Run Slice tests
bundle exec rspec spec/parslet/slice_spec.rb

# 3. Update Source (Phase 3.1)
# Edit lib/parslet/source.rb

# Run Source tests
bundle exec rspec spec/parslet/source_spec.rb

# 4. Update atoms (Phase 4)
# Edit atoms one at a time

# Run all atom tests
bundle exec rspec spec/parslet/atoms/

# 5. Run full test suite
bundle exec rspec

# 6. Run benchmarks (3 runs)
ruby benchmark/fair_comparison.rb && sleep 60 && \
ruby benchmark/fair_comparison.rb && sleep 60 && \
ruby benchmark/fair_comparison.rb
```

---

## Success Criteria

### Must Achieve (Release Blockers)

- [ ] **Integer positions implemented** throughout codebase
- [ ] **Position object eliminated** from hot paths
- [ ] **All tests passing** (712/713 baseline)
- [ ] **Performance target**: ≥1.35x average (validated 3 runs)
- [ ] **No regressions**: All test cases stable
- [ ] **Documentation complete**: Benchmarks, README, release notes

### Quality Gates

- [ ] Clean architecture: MECE, separation of concerns
- [ ] No copy-paste code
- [ ] Backward compatible API (or clearly documented breaking changes)
- [ ] Performance improvement reproducible (3+ runs)
- [ ] Allocations profiling shows Position elimination

### Nice to Have

- [ ] Memory profiling shows reduced allocations
- [ ] GC pressure reduced (verify in stats)
- [ ] Additional optimization opportunities identified

---

## Important Notes

### Backward Compatibility

**Critical**: Minimize breaking changes:
- Maintain existing Slice API
- Add aliases (charpos, bytepos) for clarity
- Document any breaking changes in release notes
- Provide migration guide if needed

### Test Philosophy

If tests fail after integer position implementation:

1. **First**, verify the behavior is correct
2. **Second**, check if test expectations need updating (Position → integer)
3. **Remember**: Correct behavior > passing tests
4. **Document**: Any behavior changes in release notes

### Performance Variance

Benchmarks may show variance (±3-10% normal):

1. Run **3 times minimum** with cooldown
2. Calculate mean and std deviation
3. Exclude outliers (>2σ from mean) if needed
4. Report final average with confidence interval

---

## Contingency Plans

### If Performance Target Not Met (<1.35x)

1. Profile to identify actual bottleneck
2. Check if Position allocations were actually eliminated
3. Look for other allocation hot paths
4. Ship as v3.2.1 if showing some improvement
5. Document findings for v3.4.0

### If Tests Fail Systematically

1. Identify root cause (integer vs Position mismatch?)
2. Fix architecture if needed (tests may need updates)
3. Remember: Correct implementation > failing tests
4. Document expected behavior changes in release notes

### If Behind Schedule

**Priority order**:
1. Slice + Source (highest impact) - **DO NOT SKIP**
2. Atom updates (required for correctness) - **DO NOT SKIP**
3. Documentation (can be async) - Can defer to v3.3.1
4. Profiling (validation) - Can defer if benchmarks show improvement

---

## Expected Timeline

- **Day 1**: Analysis + design (no code changes)
- **Day 2**: Slice refactoring + tests
- **Day 3**: Source refactoring + tests
- **Day 4**: Atom updates (Str, Re, Repetition)
- **Day 5**: Remaining atoms + verification
- **Day 6**: Full test suite + 3 benchmark runs
- **Day 7**: Documentation + release prep

**Total**: 7 days compressed (vs. planned 2-3 weeks)

---

## Next Session Preview

After v3.3.0 ships (Session 18 complete), Session 19 will focus on:

**Most Likely**: v3.4.0 Additional Optimizations
- Profile-guided optimization of remaining hot paths
- Target: +3-5% additional improvement (1.40-1.45x cumulative)
- Duration: 1-2 weeks

**Alternative**: Developer experience improvements or API enhancements

---

**Let's eliminate Position object overhead and achieve 1.35-1.40x performance!**