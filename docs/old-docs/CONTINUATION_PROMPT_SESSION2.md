# Plurimath Parslet - Session 2 Continuation Prompt

**Context**: High-performance parslet fork achieving 13.3x speedup through 50 optimization phases. Phase 50b complete (frozen string literals). Now in final stages: user documentation, comparative benchmarks, and release preparation.

---

## Session 2 Objectives (HIGH PRIORITY)

### Goal 1: Fix Comparative Benchmarks (Most Critical)

**Problem**: Comparative benchmarks hang when testing plurimath-parslet vs parslet 2.0

**What Was Done**:
- ✅ Added `optimize_rules!` to test parsers (json_parser.rb, calc_parser.rb, xml_parser.rb)
- ✅ Validated parsers work individually (7,220 IPS confirmed)
- ❌ Full comparative benchmark hangs (process killed by SIGKILL)

**What To Do**:

1. **Add debug logging** to identify hang point:
   ```ruby
   # In benchmark/comparative/runner.rb or dual_runner.rb
   puts "[#{Time.now.strftime('%H:%M:%S')}] Starting #{parser_name}"
   puts "[#{Time.now.strftime('%H:%M:%S')}] Testing #{test_case}..."
   ```

2. **Test parsers individually** to isolate issue:
   ```bash
   cd benchmark/comparative
   ruby -e "require_relative 'parsers/json_parser'; \
            p = Parslet::Comparative::Parsers::JsonParser.new; \
            puts p.parse('{\"a\":1}')"
   ```

3. **Create minimal test set** for quick validation:
   - Edit `test_inputs.rb`: Add `minimal_inputs` method with 2-3 cases per parser
   - Reduce warmup time from 5s to 1s
   - Reduce iterations from 100 to 10

4. **Run with timeout detection**:
   ```ruby
   require 'timeout'
   Timeout.timeout(60) do
     # benchmark code
   end
   ```

**Success Criteria**:
- Comparative benchmark completes without hanging
- Real speedup vs parslet 2.0 measured (expect 10-15x)
- Results saved to `docs/comparative-benchmark.adoc`

---

### Goal 2: Create Optimization Guide

**File**: `docs/optimization-guide.md`

**Purpose**: User-facing guide showing how to get 30x performance from plurimath-parslet

**Required Sections**:

#### 1. Quick Start (90% Benefits in 5 Minutes)
```ruby
class MyParser < Parslet::Parser
  optimize_rules!  # One line = 10-15x faster
  
  rule(:expression) { term >> (operator >> term).repeat }
  rule(:term) { number | variable }
  # ... rest of parser
end
```

#### 2. Understanding Optimizations
- What `optimize_rules!` does internally
- Quantifier optimization (repeat simplification)
- Sequence optimization (flattening)
- Choice optimization (cut insertion for O(1) space)
- Lookahead optimization

#### 3. Best Practices
**Good Patterns**:
```ruby
# Use cut operators for keywords
str('if').cut | str('while').cut | identifier

# Use match instead of many alternatives
match('[a-zA-Z0-9_]')  # NOT str('a')|str('b')|...
```

**Avoid Patterns**:
```ruby
# Deep nesting without cuts (causes backtracking)
(a >> b >> c).repeat | (a >> b >> d).repeat | (a >> e)

# Better: Use cuts or restructure
a >> ((b >> (c | d)).repeat | e)
```

#### 4. Performance Patterns
- Show timing comparisons
- Memory allocation comparisons  
- Cache hit rate impact

#### 5. Profiling
```ruby
require 'ruby-prof'
RubyProf.start
parser.parse(large_input)
result = RubyProf.stop
printer = RubyProf::GraphPrinter.new(result)
printer.print(STDOUT, {})
```

#### 6. Advanced Topics
- Manual optimization with Optimizer API
- Using interval cache (experimental)
- Tree memoization for repetitions

**Length**: 1500-2000 words with code examples

**Success Criteria**:
- Clear, actionable advice
- Code examples that work
- Shows real performance impact
- Explains the "why" behind recommendations

---

### Goal 3: Create Migration Guide

**File**: `docs/migration-guide.md`

**Purpose**: Help users migrate from parslet 2.0 to plurimath-parslet

**Required Sections**:

#### 1. Overview
- 100% backward compatible
- Drop-in replacement
- Zero breaking changes

#### 2. Installation
```ruby
# Replace in Gemfile:
gem 'parslet', '~> 2.0'
# With:
gem 'plurimath-parslet', '~> 3.1'
```

#### 3. Basic Usage (No Changes Needed)
```ruby
# All your existing code works:
class JSONParser < Parslet::Parser
  rule(:value) { object | array | string | number }
  # ... existing rules unchanged
end

# Parse exactly as before
parser = JSONParser.new
result = parser.parse(json_string)
```

#### 4. Enabling Optimizations (Optional)
```ruby
class JSONParser < Parslet::Parser
  optimize_rules!  # Add this one line
  
  rule(:value) { object | array | string | number }
  # ... existing rules unchanged
end
```

#### 5. Performance Comparison
| Configuration | Speed | Memory | Setup |
|---------------|-------|--------|-------|
| parslet 2.0 | 1x | baseline | `gem 'parslet'` |
| plurimath-parslet | 1x | baseline | `gem 'plurimath-parslet'` |
| + optimize_rules! | 13.3x | -93% cache | Add one line |
| + YJIT (Ruby 3.1+) | 27.8x | -93% cache | `ruby --yjit` |

#### 6. API Compatibility Matrix
- ✅ All parslet 2.0 APIs (str, match, repeat, etc.)
- ✅ Transform API
- ✅ Error reporting
- ➕ New: `optimize_rules!` class method
- ➕ New: `.cut` method for explicit cuts
- ➕ Experimental: Interval cache API

#### 7. Migration Checklist
- [ ] Update Gemfile
- [ ] Run `bundle install`
- [ ] Run tests (should pass without changes)
- [ ] Add `optimize_rules!` to parser classes
- [ ] Re-run tests (should still pass)
- [ ] Measure performance improvement
- [ ] Enable YJIT if on Ruby 3.1+

**Length**: 800-1000 words

**Success Criteria**:
- Clear migration path
- Emphasizes zero-risk migration
- Shows performance benefits
- Provides compatibility assurance

---

## Files Reference

### Already Complete
- ✅ `README.adoc` - Performance section added
- ✅ `STATUS_TRACKER.md` - Updated
- ✅ All 22 files with frozen string literals
- ✅ 664 Ruby + 656 Opal tests passing

### To Create (This Session)
- `docs/optimization-guide.md` - User guide
- `docs/migration-guide.md` - Migration instructions
- `benchmark/comparative/quick_comparative.rb` - Minimal benchmark script (if needed)

### To Fix
- `benchmark/comparative/runner.rb` or `dual_runner.rb` - Add logging
- `benchmark/comparative/test_inputs.rb` - Add minimal test set
- Get comparative benchmarks working

### To Update Later (Session 3+)
- `spec/performance_spec.rb` - Regression tests
- `benchmark/standard_suite.rb` - Standard benchmark infrastructure
- `docs/performance.adoc` - Add phases 31-50b
- `CHANGELOG.md` or `HISTORY.txt` - Add 3.1.0 release notes

---

## Commands to Run

### Test Current State
```bash
cd /Users/mulgogi/src/plurimath/parslet

# Verify tests still pass
bundle exec rake spec
bundle exec rake spec:opal

# Validate comparative benchmark infrastructure
bundle exec rake benchmark:comparative:validate

# Try simplified comparative run (if you create quick script)
ruby benchmark/comparative/quick_comparative.rb
```

### Debugging Comparative Benchmark
```bash
# Test individual parser
cd benchmark/comparative
ruby -r ./parsers/json_parser -e "p = Parslet::Comparative::Parsers::JsonParser.new; puts p.parse('{\"a\":1}')"

# Check if optimize_rules! causes issues
ruby -r parslet -e "class P < Parslet::Parser; optimize_rules!; rule(:r){str('a')}; end; puts P.new.parse('a')"
```

---

## Success Metrics (This Session)

### Must Complete
- [ ] Comparative benchmark working (or alternative verification of speedup)
- [ ] `docs/optimization-guide.md` created and comprehensive
- [ ] `docs/migration-guide.md` created and helpful
- [ ] All tests still passing (664 Ruby + 656 Opal)

### Nice to Have
- [ ] Real 10-15x speedup vs parslet 2.0 measured
- [ ] Benchmark results in `docs/comparative-benchmark.adoc` updated
- [ ] Examples in guides tested and working

---

## Important Notes

### Architectural Principles (CRITICAL)
1. **Correctness First**: If tests fail, verify behavior is correct before "fixing"
2. **MECE**: All designs must be mutually exclusive, collectively exhaustive
3. **Object-Oriented**: Use classes, inheritance, composition - not functional style
4. **Separation of Concerns**: Each component has single responsibility

### Known Issues to Handle
1. **Comparative Benchmark Hangs**: Primary blocker, must fix
   - Likely cause: optimize_rules! interaction with benchmark infrastructure
   - Solution: Add logging, reduce scope, test individually

2. **Benchmark Directory Gitignored**: `benchmark/comparative/` is in .gitignore
   - Changes won't be committed
   - That's OK - document fixes in continuation plan
   - Users can re-apply changes if needed

### Time Pressure
- We have a deadline to finish soon
- Focus on must-haves first
- Defer nice-to-haves if needed
- Document what's complete for next developer

---

## Getting Started

**Start with the most critical task**: Fix comparative benchmarks

1. Read `benchmark/comparative/README.md` to understand architecture
2. Add debug logging to `runner.rb` or `dual_runner.rb`
3. Create minimal test set in `test_inputs.rb`
4. Test with just JSON parser first
5. Expand to other parsers once working

**Then**: Create the two documentation files (optimization-guide.md, migration-guide.md)

**Expected Duration**: 2-3 hours for all three tasks

---

## Next Session (Session 3)

After completing Session 2, next priority is:
- Create `spec/performance_spec.rb` (regression tests)
- Enhance `benchmark/standard_suite.rb` (versioned benchmarking)
- Add performance tests to CI

See `docs/CONTINUATION_PLAN_SESSION2.md` for full timeline.

---

**Ready to Continue**: This prompt contains everything needed for Session 2
**Last Updated**: 2025-11-29
**Current Phase**: Documentation + Comparative Benchmarks