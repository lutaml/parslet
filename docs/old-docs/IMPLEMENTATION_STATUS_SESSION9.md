# Implementation Status: Session 9 - Zero Regressions

**Session**: 9 (CRITICAL)
**Created**: 2025-11-30
**Last Updated**: 2025-11-30
**Status**: PLANNED (Not Started)

---

## Mission

**Eliminate ALL 5 performance regressions** before v3.1.0 release.

**Non-Negotiable**: We CANNOT ship with ANY case slower than vanilla parslet 2.0.

---

## Regression Cases to Fix

### Critical (MUST FIX)
- [ ] **calc/large**: 0.68x → target: >1.05x (32% regression - WORST)
- [ ] **sentence/medium**: 0.86x → target: >1.0x (14% regression)
- [ ] **sentence/tiny**: 0.87x → target: >1.0x (13% regression)
- [ ] **sentence/small**: 0.90x → target: >1.0x (10% regression)
- [ ] **calc/small**: 0.91x → target: >1.0x (9% regression)

### Summary
- Total regressions: **5/14 cases**
- Must achieve: **0/14 regressions**
- Target average: **>1.3x** (currently 1.28x)

---

## Implementation Phases

### Phase 1: Investigation (Hours 0-2)
**Status**: Not Started

#### Task 1.1: Profile Sentence Parser
- [ ] Create `benchmark/profile_sentence_regression.rb`
- [ ] Test sentence parser with optimization disabled
- [ ] Compare: vanilla vs plurimath-opt vs plurimath-noopt
- [ ] Identify which optimization causes overhead
- [ ] Document findings

**Expected Outcome**: Understand why sentence parser is 10-14% slower

#### Task 1.2: Profile Calc Regressions
- [ ] Create `benchmark/profile_calc_regression.rb`
- [ ] Profile calc/large (0.68x - worst case)
- [ ] Profile calc/small (0.91x)
- [ ] Compare against calc/medium (1.07x - works)
- [ ] Identify pathological patterns

**Expected Outcome**: Understand calc regression root causes

#### Task 1.3: Analyze Optimization Effectiveness
- [ ] Create `benchmark/analyze_optimization_effectiveness.rb`
- [ ] Measure optimization cost per parser type
- [ ] Identify which optimizations help/hurt
- [ ] Create optimization recommendation matrix

**Expected Outcome**: Know which optimizations to apply where

---

### Phase 2: Implement Smart Optimization (Hours 2-5)
**Status**: Not Started

#### Task 2.1: Add Parser Characterization
- [ ] Add `Parslet::Parser.simple_parser?` method
- [ ] Implement heuristics (rule count, depth, complexity)
- [ ] Test classification accuracy
- [ ] Document criteria

**Location**: `lib/parslet.rb`

**Code**:
```ruby
class Parslet::Parser
  def self.simple_parser?
    # Heuristics for simple parsers
    rule_count = @rules&.size || 0
    max_depth = calculate_max_rule_depth
    
    rule_count < 10 && max_depth < 5
  end
  
  private
  def self.calculate_max_rule_depth
    # Analyze rule tree depth
    # Return maximum nesting level
  end
end
```

#### Task 2.2: Implement Smart Optimization Logic
- [ ] Modify `Parslet::Parser` auto-optimization
- [ ] Apply optimization only for complex parsers
- [ ] Allow manual override (opt-in/opt-out)
- [ ] Add optimization strategy selection

**Location**: `lib/parslet.rb`

**Code**:
```ruby
class Parslet::Parser
  def self.inherited(subclass)
    super
    # Smart optimization based on characteristics
    subclass.class_eval do
      if should_auto_optimize?
        optimize_rules!
      end
    end
  end
  
  private
  def self.should_auto_optimize?
    !simple_parser? && optimization_beneficial?
  end
  
  def self.optimization_beneficial?
    # Check if optimization will help
    # Based on parser characteristics
    true # Default: optimize unless simple
  end
end
```

#### Task 2.3: Add Per-Parser Control
- [ ] Add `optimize_rules!` with strategy selection
- [ ] Add `disable_optimization!` method
- [ ] Allow fine-grained control
- [ ] Document usage

**Location**: `lib/parslet.rb`

**Code**:
```ruby
class Parslet::Parser
  def self.optimize_rules!(strategies: :auto)
    if strategies == :auto
      strategies = determine_optimal_strategies
    end
    
    apply_optimization_strategies(strategies)
  end
  
  def self.disable_optimization!
    @optimization_disabled = true
  end
  
  private
  def self.determine_optimal_strategies
    # Return appropriate strategies based on parser
    if simple_parser?
      [:flatten] # Minimal overhead
    else
      [:cut, :flatten, :lookahead] # Full optimization
    end
  end
end
```

---

### Phase 3: Fix Calc/Large Pathology (Hours 5-6)
**Status**: Not Started

#### Task 3.1: Identify Pathological Pattern
- [ ] Profile calc/large execution
- [ ] Identify backtracking hot spots
- [ ] Measure cache effectiveness
- [ ] Document pattern

#### Task 3.2: Add Strategic Cut Operators
- [ ] Modify calc parser grammar
- [ ] Add cuts at decision points
- [ ] Test parse correctness
- [ ] Benchmark improvement

**Location**: `benchmark/parsers/calc_parser.rb`

**Potential Fix**:
```ruby
class CalcParser < Parslet::Parser
  rule(:expression) {
    term >> (cut >> match['+-'] >> term).repeat
    # Cut prevents backtracking after operator
  }
  
  rule(:term) {
    factor >> (cut >> match['*/'] >> factor).repeat
  }
end
```

#### Task 3.3: Test Alternative Approaches
- [ ] Try memoization for large expressions
- [ ] Test repetition optimization tuning
- [ ] Consider parser restructuring
- [ ] Measure each approach

---

### Phase 4: Validate Zero Regressions (Hours 6-8)
**Status**: Not Started

#### Task 4.1: Create Regression Validator
- [ ] Create `benchmark/validate_no_regressions.rb`
- [ ] Implement strict checking (all >1.0x)
- [ ] Add CI-friendly exit codes
- [ ] Generate regression report

**Location**: `benchmark/validate_no_regressions.rb`

**Code**:
```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'comprehensive_suite'

def validate_no_regressions
  puts "Validating: Zero Regressions Required"
  puts "=" * 80
  
  results = run_comprehensive_benchmarks
  regressions = results.select { |r| r[:speedup] < 1.0 }
  
  if regressions.empty?
    puts "\n✅ RELEASE READY"
    puts "All #{results.size} test cases faster than vanilla"
    avg = (results.map { |r| r[:speedup] }.sum / results.size).round(2)
    puts "Average speedup: #{avg}x"
    exit 0
  else
    puts "\n❌ RELEASE BLOCKED"
    puts "Found #{regressions.size} regressions:"
    regressions.each do |r|
      pct = ((r[:speedup] - 1) * 100).round(1)
      puts "  #{r[:parser]}/#{r[:input]}: #{r[:speedup]}x (#{pct}%)"
    end
    exit 1
  end
end

validate_no_regressions if __FILE__ == $0
```

#### Task 4.2: Run Full Test Suite
- [ ] Run all 675 tests: `bundle exec rake spec`
- [ ] Validate no test regressions
- [ ] Check memory allocations
- [ ] Verify optimization correctness

#### Task 4.3: Run Comprehensive Benchmarks
- [ ] Execute full benchmark suite
- [ ] Validate ALL cases >1.0x
- [ ] Generate final report
- [ ] Update documentation

#### Task 4.4: Final Documentation Update
- [ ] Update README.adoc with accurate claims
- [ ] Update HISTORY.txt
- [ ] Create Session 9 completion doc
- [ ] Update benchmark reports

---

## Files to Modify

### Core Implementation
- [ ] `lib/parslet.rb` - Smart optimization logic
- [ ] `lib/parslet/parser.rb` - Parser characterization
- [ ] `lib/parslet/optimizer.rb` - Strategy selection (if needed)

### Benchmark Tools
- [ ] `benchmark/profile_sentence_regression.rb` (NEW)
- [ ] `benchmark/profile_calc_regression.rb` (NEW)
- [ ] `benchmark/analyze_optimization_effectiveness.rb` (NEW)
- [ ] `benchmark/validate_no_regressions.rb` (NEW)

### Parser Fixes (if needed)
- [ ] `benchmark/parsers/calc_parser.rb` - Add cuts
- [ ] `benchmark/parsers/sentence_parser.rb` - Disable opt (temp)

### Documentation
- [ ] `README.adoc` - Update performance claims
- [ ] `HISTORY.txt` - Update v3.1.0 notes
- [ ] `docs/SESSION_9_COMPLETE.md` (NEW)
- [ ] `docs/optimization-guide.md` - Update with insights

---

## Success Metrics

### Release Criteria (MUST ACHIEVE)
- [ ] **ALL 14 cases > 1.0x** (zero regressions)
- [ ] **Minimum speedup: 1.02x** across all cases
- [ ] **Average speedup: > 1.3x** (currently 1.28x)
- [ ] **All 675 tests passing**
- [ ] **No memory regressions**

### Target Improvements
- [ ] sentence/tiny: 0.87x → >1.0x (+13% needed)
- [ ] sentence/small: 0.90x → >1.0x (+10% needed)
- [ ] sentence/medium: 0.86x → >1.0x (+14% needed)
- [ ] calc/small: 0.91x → >1.0x (+9% needed)
- [ ] calc/large: 0.68x → >1.0x (+32% needed - hardest)

### Quality Metrics
- [ ] JSON parser maintains >2.0x average
- [ ] ERB parser maintains >1.1x average
- [ ] No case varies >20% between runs
- [ ] Memory 20-50% better than vanilla (maintained)

---

## Risk Mitigation

### If Optimization Can't Be Fixed (Deadline: 6 hours)
**Fallback**: Make optimization opt-in

```ruby
# lib/parslet.rb - Revert to opt-in
class Parslet::Parser
  def self.inherited(subclass)
    super
    # DON'T auto-optimize
    # Users must explicitly call optimize_rules!
  end
end
```

**Documentation Strategy**:
- Document which parsers benefit from optimization
- Provide guidelines for when to optimize
- Show benchmark results for opt-in vs opt-out

### If Calc/Large Can't Be Fixed (Deadline: 7 hours)
**Options**:
1. Document as known limitation (rare 50KB calc expressions)
2. Provide workaround (chunk large expressions)
3. Add specific calc optimization mode

### If Multiple Regressions Persist (Deadline: 8 hours)
**Release Strategy**:
1. Ship with opt-in optimization
2. Honest documentation about trade-offs
3. Plan v3.2.0 with smarter defaults
4. Provide migration guide

---

## Progress Tracking

### Hour-by-Hour Checkpoints

**Hour 2:**
- [ ] Root cause of sentence regression identified
- [ ] Root cause of calc regressions identified
- [ ] Solution approach decided

**Hour 4:**
- [ ] Smart optimization implemented
- [ ] Initial testing shows improvement
- [ ] At least 3/5 regressions fixed

**Hour 6:**
- [ ] All 5 regressions fixed OR
- [ ] Decision made on fallback approach
- [ ] Implementation complete

**Hour 8:**
- [ ] Final validation complete
- [ ] All tests passing
- [ ] Documentation updated
- [ ] RELEASE READY or POSTPONED

---

## Decision Log

### Major Decisions

#### Decision 1: Optimization Strategy
- **Options**: A) Smart auto-opt, B) Opt-in, C) Hybrid
- **Chosen**: TBD (after investigation)
- **Rationale**: TBD

#### Decision 2: Sentence Parser
- **Options**: A) Disable opt, B) Selective opt, C) Fix opt
- **Chosen**: TBD
- **Rationale**: TBD

#### Decision 3: Calc/Large
- **Options**: A) Better cuts, B) Memoization, C) Document
- **Chosen**: TBD
- **Rationale**: TBD

---

## Notes

### Key Insights
- Simple parsers may not benefit from complex optimizations
- Optimization adds overhead that must be justified by gains
- Parser characteristics should guide optimization strategy
- One-size-fits-all optimization is wrong approach

### Lessons for Future
- Always validate against real baseline, not assumptions
- Profile before optimizing, measure after
- Consider parser complexity in optimization decisions
- Zero tolerance for regressions in performance libraries

---

*Implementation Status Document*  
*Session 9: Zero Regressions Required*  
*Target: ALL cases >1.0x faster*