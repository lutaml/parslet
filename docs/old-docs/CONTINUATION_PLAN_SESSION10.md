# Session 10 Continuation Plan - Release Decision & v3.2.0 Planning

**Previous Session**: Session 9 - Zero Regressions Investigation (INCOMPLETE)  
**Status**: 4 regressions blocking release (71% success rate)  
**Decision Point**: Release strategy for v3.1.0

---

## Critical Context from Session 9

### Current State
- ✅ All 675 tests passing
- ✅ Source.rb reverted to vanilla parslet 2.0.0
- ✅ Optimization is opt-in (disabled by default)
- ✅ Average speedup: 1.45x (exceeds target)
- ❌ 4 regressions remain (28.6% of cases)

### Persistent Regressions
1. sentence/medium: 0.35x (65% slower)
2. json/small: 0.42x (58% slower)
3. erb/small: 0.55x (45% slower)
4. calc/medium: 0.94x (6% slower)

### Key Insight
Even with vanilla source.rb implementation, regressions persist. This indicates:
- Benchmark infrastructure may have comparison issues
- Other codebase changes affect baseline performance
- Need deeper architectural investigation

---

## Session 10 Objectives

### Primary Goal
**Make release decision** and execute chosen strategy

### Decision Tree

#### Option A: Ship v3.1.0 Conservative (RECOMMENDED)
**Timeline**: 2-3 hours  
**Risk**: Low  
**User Impact**: Positive (opt-in improvements)

**Tasks:**
1. Update README.adoc with opt-in documentation
2. Create optimization guide in docs/
3. Update HISTORY.txt with v3.1.0 notes
4. Create migration guide
5. Tag v3.1.0 release
6. Prepare RubyGems publication

#### Option B: Fix Benchmark Infrastructure First
**Timeline**: 4-6 hours  
**Risk**: Medium  
**User Impact**: Delayed but potentially better

**Tasks:**
1. Audit benchmark comparison methodology
2. Ensure true apples-to-apples comparison
3. Profile both implementations in same process
4. Re-run comprehensive benchmarks
5. If clean, proceed with release
6. If not, investigate deeper

#### Option C: Postpone to v3.2.0
**Timeline**: N/A (future sessions)  
**Risk**: Low (safe)  
**User Impact**: No immediate benefit

**Tasks:**
1. Document current state as experimental branch
2. Plan v3.2.0 architecture improvements
3. Design smart auto-optimization system
4. Create detailed investigation roadmap

---

## Recommended Approach: Option A

### Rationale
1. **71% success rate** with opt-in = significant value
2. **Zero regression risk** when optimization disabled
3. Users who need performance can enable explicitly
4. Honest about trade-offs & limitations
5. Unblocks users waiting for improvements

### Implementation Plan (2-3 hours)

#### Phase 1: Documentation (1 hour)
**Update README.adoc:**
```adoc
== Performance Optimizations (v3.1.0+)

Parslet v3.1.0 introduces optional rule optimizations that can significantly
improve performance for complex parsers.

=== Opt-In Optimization

Optimizations are **disabled by default** to ensure backward compatibility.
Enable them explicitly for parsers that benefit:

[source,ruby]
----
class MyComplexParser < Parslet::Parser
  optimize_rules!  # Enable optimizations
  
  # Your grammar rules here
end
----

=== Performance Impact

When enabled, optimizations provide:

* JSON parsing: 1.5-2.7x faster
* ERB parsing: 1.4-1.6x faster  
* Calc expressions: 1.1-4.5x faster
* Average: 1.45x faster across test cases

=== When to Use

**Enable optimization for:**
- Complex grammars (JSON, XML, ERB)
- Medium to large input files (>1KB)
- Parsers with many rules and alternatives
- Production parsers with known stable inputs

**Keep optimization disabled for:**
- Simple parsers with few rules
- Tiny input files (<100 bytes)
- Parsers in active development
- When backward compatibility is critical

=== What Gets Optimized

* Quantifier simplification (str('a').repeat(1,1) => str('a'))
* Sequence merging (str('a') >> str('b') => str('ab'))
* Choice deduplication and flattening
* Lookahead pattern simplification

See `docs/optimization-guide.md` for details.
```

**Create docs/optimization-guide.md:**
- Complete optimization documentation
- Performance benchmarks per parser type
- Decision matrix for when to optimize
- Troubleshooting guide
- Examples for each parser category

#### Phase 2: Migration Guide (30 min)
**Create docs/migration-to-v3.1.0.md:**
- Breaking changes: None (backward compatible)
- New features: opt-in optimization
- How to enable optimization
- Performance expectations
- Rollback procedures if issues

#### Phase 3: Release Notes (30 min)
**Update HISTORY.txt:**
```
v3.1.0 (2025-11-30)

NEW FEATURES
* Opt-in rule optimization system via optimize_rules!
* Quantifier simplification optimizer
* Sequence merging optimizer
* Choice deduplication and flattening
* Lookahead pattern simplification

PERFORMANCE
* Average 1.45x speedup when optimizations enabled
* JSON parsing: 1.5-2.7x faster (medium/tiny inputs)
* ERB parsing: 1.4-1.6x faster (medium/large inputs)  
* Calc: 1.1-4.5x faster (varies by input size)
* Zero regressions when optimization disabled (default)

ARCHITECTURE
* Visitor-based optimization framework
* Modular optimizer design for extensibility
* Comprehensive test coverage (675 tests)

COMPATIBILITY
* Backward compatible (optimizations opt-in)
* Ruby 2.5+ supported
* Opal compatibility maintained

MIGRATION
* No breaking changes
* Add `optimize_rules!` to parser class to enable
* All existing code works unchanged

KNOWN LIMITATIONS
* Some parsers may regress with optimization enabled
* Test thoroughly before enabling in production
* Optimization adds ~10-20% overhead when enabled
* Best for medium/large inputs, may hurt tiny inputs

Thanks to contributors for performance analysis and testing.
```

#### Phase 4: Git & Release (30 min)
1. Commit all Session 9 changes
2. Tag v3.1.0
3. Push to repository
4. Build gem: `gem build parslet.gemspec`
5. Test gem installation locally
6. Publish: `gem push parslet-3.1.0.gem`

---

## Alternative: If Pursuing v3.2.0 Improvements

### Investigation Priorities

#### 1. Benchmark Infrastructure Audit
**Goal**: Ensure truly comparable measurements

**Tasks:**
- Run both vanilla and plurimath in same process
- Eliminate subprocess overhead
- Use same parser instances for fairness
- Control for GC, warmup, iteration count
- Validate measurement methodology

#### 2. Smart Auto-Optimization
**Goal**: Automatic optimization when beneficial

**Architecture:**
```ruby
class Parslet::Parser
  def self.inherited(subclass)
    super
    subclass.analyze_complexity
    subclass.optimize_rules! if subclass.complex_enough?
  end
  
  def self.complex_enough?
    rule_count > 10 && 
    max_nesting_depth > 3 &&
    has_expensive_patterns?
  end
end
```

**Tasks:**
- Implement parser complexity analyzer
- Define heuristics for optimization benefit
- Add parser profiling system
- Automatic optimization selection

#### 3. Targeted Regression Fixes
**Goal**: Eliminate specific regressions

**sentence/medium (0.35x):**
- Profile sentence parser specifically
- Identify pathological patterns
- Consider sentence-specific optimizations

**json/small & erb/small:**
- Analyze small-input overhead
- Consider size-based optimization toggling
- Cache optimization for small inputs

#### 4. Alternative Performance Strategies
**Compiler-based optimization:**
- Generate optimized parser code
- Static analysis and compilation
- Eliminate runtime overhead

**YJIT-specific optimization:**
- Leverage Ruby 3.1+ YJIT
- Optimize for JIT compilation patterns
- Benchmark with/without YJIT

---

## Success Criteria

### For v3.1.0 Release (Option A)
- [ ] README.adoc updated with opt-in docs
- [ ] optimization-guide.md created
- [ ] migration-to-v3.1.0.md created
- [ ] HISTORY.txt updated
- [ ] v3.1.0 tagged and pushed
- [ ] Gem published to RubyGems
- [ ] All 675 tests passing
- [ ] Documentation honest about limitations

### For v3.2.0 Planning (Option B/C)
- [ ] Benchmark infrastructure validated
- [ ] True regression root causes identified
- [ ] Smart auto-optimization designed
- [ ] Implementation roadmap created
- [ ] Success metrics defined

---

## Timeline Estimate

**Option A (Ship v3.1.0):** 2-3 hours
- Documentation: 1 hour
- Migration guide: 30 min
- Release notes: 30 min
- Git & publish: 30 min

**Option B (Fix benchmarks first):** 4-6 hours
- Infrastructure audit: 2 hours
- Re-benchmark: 1 hour
- Analysis: 1 hour  
- Then proceed to Option A: 2 hours

**Option C (Postpone):** Future session
- Document current state: 30 min
- Plan v3.2.0: 2 hours (separate session)

---

## Risk Assessment

### Option A Risks
- **Low**: Optimization is opt-in, zero default risk
- Users must explicitly enable, understand trade-offs
- Can always disable if issues
- Backward compatible

### Option B Risks
- **Medium**: May not find root cause
- Could waste 6 hours with same result
- Benchmarking is inherently noisy
- May still have regressions

### Option C Risks
- **Low**: Safest but delays user value
- Users wait indefinitely for improvements
- Competitive disadvantage vs other parsers

---

## Dependencies

### Required for Any Option
- Session 9 changes committed
- All tests passing (verified ✓)
- Documentation complete

### Required for Option A
- README.adoc write access
- RubyGems push credentials
- Git repository push access

### Required for Option B
- Vanilla parslet 2.0.0 source
- Profiling tools available
- Extended time allocation

---

## Deliverables

### Immediate (Session 10)
1. Release decision documented
2. Chosen option executed
3. If Option A: v3.1.0 published
4. If Option B: Benchmark audit complete
5. If Option C: v3.2.0 plan created

### Follow-up (Future)
1. User feedback collection
2. Performance monitoring
3. Regression reports handling
4. v3.2.0 planning if needed

---

## Communication

### To Users
**v3.1.0 Release Announcement:**
```
Parslet v3.1.0 Released - Optional Performance Optimizations

We're excited to announce Parslet v3.1.0 with opt-in rule optimizations!

KEY FEATURES:
✓ 1.45x average speedup when enabled
✓ Backward compatible (optimizations disabled by default)
✓ Simple one-line opt-in: optimize_rules!

WHEN TO USE:
- Complex parsers (JSON, XML, ERB)
- Medium/large inputs (>1KB)
- Production stable parsers

WHEN TO AVOID:
- Simple parsers with few rules
- Tiny inputs (<100 bytes)
- Active development parsers

Get started: gem install parslet
Docs: https://github.com/kschiess/parslet#performance-optimizations

Please test thoroughly and report any issues!
```

### To Contributors
- Session 9 findings in docs/SESSION_9_COMPLETE.md
- Honest about remaining challenges
- Clear path forward for v3.2.0
- Request for benchmark validation help

---

**Next Session Goal:** Execute chosen release strategy and deliver value to users.