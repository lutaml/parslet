# Session 19 Optimization Design

## Status: Design Complete

---

## Key Finding: Most Optimizations Already Done

### Previous Work (Sessions 58, 60)

**Already implemented:**
- ✅ Frozen error messages in `str.rb` (lines 19-22)
- ✅ Frozen error messages in `re.rb` (lines 21-24)
- ✅ Frozen error messages in `repetition.rb` (lines 26-29)
- ✅ Frozen error messages in `sequence.rb` (lines 16-18)
- ✅ Frozen error messages in `alternative.rb` (line 25)
- ✅ Frozen constants in `base.rb` (lines 176-197)

**Result:** Most string allocations are already eliminated!

---

## Remaining Opportunities

### Opportunity 1: Dynamic String in base.rb:110 (EASY WIN)

**Location:** `lib/parslet/atoms/base.rb:110`

**Current code:**
```ruby
return context.err_at(
  self,
  source,
  "Don't know what to do with #{offending_input.to_s.inspect}",
  offending_pos
)
```

**Issue:** Dynamic string allocation on every consume_all failure

**Fix:** Use frozen string constant with concatenation

**Implementation:**
```ruby
# At class level (around line 16):
ERROR_UNKNOWN_INPUT = "Don't know what to do with ".freeze

# At line 110:
return context.err_at(
  self,
  source,
  ERROR_UNKNOWN_INPUT + offending_input.to_s.inspect,
  offending_pos
)
```

**Expected impact:**
- Memory: Minimal (rarely called)
- CPU: Minimal
- Code quality: Better (consistent with pattern)

**Complexity:** Very Low (5 minutes)

---

### Opportunity 2: Array Pre-allocation Analysis (COMPLEX)

**Current situation:**
- Array allocations: 59.5 MB (74% of total)
- 1,243,200 array objects created

**Top Array allocation sites:**
1. `base.rb:96` - 12.1 MB (303,000 arrays)
2. `base.rb:209` - 8.2 MB (206,000 arrays)  
3. `sequence.rb:75` - 5.3 MB (88,000 arrays)
4. `can_flatten.rb:49` - 4.1 MB (91,000 arrays)

**Analysis needed:**
- What are these arrays for?
- Can they be pre-allocated?
- Can they be reused?
- Are they necessary?

**Complexity:** High (requires deep architectural analysis)

**Risk:** Medium (core data structures)

**Timeline:** 3-5 days analysis + implementation

---

## Recommendation: Quick Win Strategy

### Phase 3.1 Complete: Design

**Selected approach:**
1. ✅ Fix remaining dynamic string (Opportunity 1)
2. ✅ Run benchmarks to measure improvement
3. ✅ If improvement < 1%, investigate array allocations
4. ✅ If no clear path forward, ship v3.3.0 as final

### Rationale

**Why fix the dynamic string:**
- Consistent with Sessions 58, 60 pattern
- Zero risk
- Future-proof (if consume_all errors increase)
- Code quality improvement

**Why not array optimization now:**
- Needs deep analysis (3-5 days)
- High complexity
- Risk of breaking correctness
- Diminishing returns likely

**Expected results:**
- String fix: +0.1-0.2% improvement (if measureable)
- Benchmark variance: ±5-10%
- Likely outcome: No significant change

**Decision tree:**
```
Fix string → Run 3 benchmarks
  ├─ If 3.52x+ → Ship as v3.4.0 ✓
  ├─ If 3.48-3.52x → Ship as v3.3.1 (minor improvement)
  └─ If <3.48x → Revert, investigate further
```

---

## Implementation Plan

### Step 1: Fix Dynamic String (15 minutes)

**File:** `lib/parslet/atoms/base.rb`

**Changes:**
1. Add constant at class level (after line 16):
   ```ruby
   # Phase 61: Frozen error message for unknown input
   ERROR_UNKNOWN_INPUT = "Don't know what to do with ".freeze
   ```

2. Update line 110:
   ```ruby
   ERROR_UNKNOWN_INPUT + offending_input.to_s.inspect,
   ```

**Testing:**
```bash
bundle exec rspec
# Expected: 713/714 passing
```

**Memory profile:**
```bash
bundle exec ruby benchmark/profile_memory_session19.rb > docs/memory_profile_v3.4.0.txt
# Compare string allocations vs v3.3.0
```

### Step 2: Benchmark (1 hour)

**Run 3 times with 60s cooldown:**
```bash
bundle exec ruby benchmark/fair_comparison.rb
sleep 60
bundle exec ruby benchmark/fair_comparison.rb  
sleep 60
bundle exec ruby benchmark/fair_comparison.rb
```

**Record:**
- Run 1 average
- Run 2 average  
- Run 3 average
- Overall average

**Compare vs v3.3.0:**
- v3.3.0: 3.48x ±2.47x
- v3.4.0: ??? (expected: 3.48-3.50x)

### Step 3: Decision (10 minutes)

**If improvement >= 0.05x (3.53x+):**
- ✅ Ship as v3.4.0
- Document as "final string optimization"
- Note: Array optimization requires v4.0 architecture

**If improvement < 0.05x (3.48-3.53x):**
- ✅ Ship as v3.3.1 (code quality improvement)
- Document: "No measurable performance change"
- Reason: Variance masks small improvements

**If regression (<3.48x):**
- ❌ Revert changes
- Investigate cause
- May indicate measurement issue

---

## Alternative: Ship v3.3.0 as Final

### Case for "Good Enough"

**Achievement so far:**
- v3.3.0: **3.48x speedup** vs vanilla 2.0.0
- **Target was 1.35x** (achieved 2.58x above target!)
- 713/714 tests passing
- Position elimination verified
- GC dominates (67%) but parsers handle it

**Diminishing returns:**
- Remaining optimizations are complex
- Array allocation requires architecture changes
- Risk/reward ratio unfavorable
- Better to focus on v4.0 architecture

**Action items if shipping as final:**
1. Update docs to declare "optimization complete"
2. Document remaining opportunities for v4.0
3. Focus on features, bug fixes, stability
4. v4.0 can address architecture for 3-5x more

---

## Expected Session 19 Outcome

### Most Likely: v3.4.0 with minor improvement

**Changes:**
- One frozen string constant added
- 0.1-0.2% improvement (if measurable)
- Same test results (713/714)

**Documentation:**
- "Completed string optimization"
- "Remaining bottleneck: Array allocations (v4.0)"
- "3.48-3.50x average speedup achieved"

**Next steps:**
- Consider v3.3.0 as optimization endpoint
- Plan v4.0 architecture for next leap
- Focus on non-performance improvements

---

## Conclusion

**Design complete:** Simple constant extraction for remaining dynamic string.

**Ready to implement:** Phase 3.2 can proceed.

**Timeline:** 1-2 hours total (15 min fix + 1 hour benchmark).

**Confidence:** High (low risk, proven pattern).

**Expected outcome:** Ship v3.4.0 or v3.3.1 with documentation update.