# Benchmark Methodology Audit - Session 11

**Date**: 2025-12-01
**Status**: CRITICAL ISSUES FOUND ⚠️

---

## Executive Summary

Current benchmark infrastructure has **severe methodological flaws** that make comparison invalid. The vanilla and plurimath benchmarks run in completely different contexts, introducing massive bias.

**Bottom line**: Session 9's regressions are likely measurement artifacts, not real performance issues.

---

## Critical Issues Found

### Issue 1: Different Process Contexts ❌

**Vanilla Runner** (benchmark/runners/vanilla_runner.rb):
- Runs in SUBPROCESS with `bundle exec ruby`
- Fresh Ruby VM state
- Clean GC/JIT slate  
- No accumulated state
- Isolated temporary directory

**Plurimath Runner** (benchmark/runners/plurimath_runner.rb):
- Runs in MAIN PROCESS with `ruby -Ilib`
- May have accumulated VM state
- Different GC/JIT conditions
- Shared process with benchmark orchestrator

**Impact**: Not apples-to-apples. Subprocess startup overhead, different VM states, different memory conditions.

---

### Issue 2: Parser Instance Lifecycle ❌

**Vanilla**:
```ruby
# Fresh instance PER TEST
parser = parser_class.new
parser.parse(input)  # Clean state every time
```

**Plurimath**:
```ruby
# Shared instances ACROSS TESTS
@parsers = [
  Benchmark::Parsers::SentenceParser.new,
  # ... created ONCE, reused for all tests
]
parser_wrapper.parse(input)  # May accumulate state/cache
```

**Impact**: Plurimath parsers accumulate optimization cache and state across tests. Vanilla gets clean slate each time. This is **MASSIVE bias**.

---

### Issue 3: Different Parser Loading ❌

**Vanilla**:
```ruby
# Direct parser classes from examples
require_relative 'example/sentence'
parser = MyParser.new  # Original parser class
```

**Plurimath**:
```ruby
# Wrapper classes
require_relative '../parsers/sentence_parser'
parser = Benchmark::Parsers::SentenceParser.new  # Wrapper indirection
```

**Impact**: Additional wrapper layer may introduce overhead. Not measuring same thing.

---

### Issue 4: Different Ruby Environments ❌

**Vanilla**:
- Uses `bundle exec` with isolated Gemfile
- Only parslet 2.0.0 + rspec loaded
- Clean gem environment

**Plurimath**:
- Uses `ruby -Ilib` to load local version
- May have different gem environment
- Different require paths

**Impact**: Different gem loading, different module namespaces, different $LOAD_PATH.

---

### Issue 5: Measurement Timing ⚠️

Both use same measurement logic (✓):
- Same warmup iterations
- Same adaptive iteration counts
- Same `Process.clock_gettime` precision
- Same GC stat collection

BUT they apply it in completely different contexts (✗).

---

## Why Session 9 Regressions Are Suspect

The 4 regressions reported in Session 9:

1. **sentence/medium**: 0.35x (65% slower)
2. **json/small**: 0.42x (58% slower)  
3. **erb/small**: 0.55x (45% slower)
4. **calc/medium**: 0.94x (6% slower)

### Hypothesis: Measurement Artifacts

These could be caused by:

1. **Cache accumulation bias**: Plurimath parser instances reused across tests accumulate optimization caches. For small inputs where cache lookup cost > benefit, this creates apparent slowdown.

2. **GC state differences**: Subprocess has clean GC. Main process may have accumulated objects from previous tests, triggering more GC during measurement.

3. **JIT differences**: Subprocess doesn't benefit from JIT warmup. Main process might, but inconsistently.

4. **Process context overhead**: Subprocess startup vs main process differences in how Ruby VM is initialized.

5. **Wrapper indirection**: The benchmark wrapper classes add method dispatch overhead not present in vanilla direct usage.

---

## What We Need

A **fair benchmark** that:

✅ Loads BOTH vanilla and plurimath in SAME process  
✅ Uses namespace isolation to avoid conflicts  
✅ Creates FRESH parser instances for EACH test  
✅ Uses IDENTICAL parser definitions (no wrappers)  
✅ Ensures SAME warmup, GC, JIT conditions  
✅ Runs MULTIPLE iterations with statistical validation  
✅ Measures confidence intervals and p-values

---

## Proposed Solution Architecture

```ruby
# Load vanilla parslet in isolated namespace
module VanillaParslet
  # Force load system parslet 2.0.0
  gem 'parslet', '2.0.0'
  require 'parslet'
  Parser = ::Parslet::Parser
end

# Load plurimath parslet in isolated namespace  
module OptimizedParslet
  # Force load local lib/parslet
  $LOAD_PATH.unshift(local_lib_path)
  load 'parslet.rb'
  Parser = ::Parslet::Parser
end

# Fair benchmark: identical conditions
def benchmark_fairly(parser_class_vanilla, parser_class_optimized, input)
  # Create FRESH instances
  vanilla_parser = parser_class_vanilla.new
  optimized_parser = parser_class_optimized.new
  
  # Same warmup
  3.times do
    vanilla_parser.parse(input)
    optimized_parser.parse(input)
  end
  
  # Same measurement conditions
  vanilla_time = measure_with_gc_disabled { vanilla_parser.parse(input) }
  optimized_time = measure_with_gc_disabled { optimized_parser.parse(input) }
  
  # Statistical validation (30+ iterations)
  # Calculate mean, stddev, confidence intervals, p-values
end
```

---

## Expected Outcomes

### Best Case
Fair benchmarks show NO regressions → Session 9 was measurement artifact  
→ Ship v3.1.0 immediately with confidence

### Expected Case  
Fair benchmarks show SOME workload-specific regressions → Real but acceptable  
→ Ship v3.1.0 opt-in with clear documentation

### Worst Case
Fair benchmarks show WORSE regressions → Methodology wasn't the only issue  
→ Deep profiling required, may need architectural fixes

---

## Next Steps

1. ✅ Audit complete - issues documented
2. → Create `benchmark/fair_comparison.rb` with proper methodology
3. → Run fair benchmarks and collect clean data
4. → Statistical analysis with confidence intervals
5. → Compare with Session 9 results
6. → Make data-driven release decision

---

## Conclusion

**Current benchmarks are INVALID for comparison purposes.**

The methodology introduces too many confounding variables to draw conclusions about actual performance differences. We MUST create fair benchmarks before making any release decisions.

Session 10's code review showed excellent architecture with no bugs. If fair benchmarks confirm this, we can ship with confidence. If not, we'll understand the REAL issues and address them properly.

**Trust the process: Measure fairly, analyze data, make informed decisions.**