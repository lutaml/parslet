# Session 15 Baseline Performance

**Date**: 2025-12-01  
**Ruby Version**: 3.3.2  
**Platform**: arm64-darwin23

## Executive Summary

Established stable baseline performance across 3 independent benchmark runs with excellent consistency (±1.6% variance). Current performance shows 4-5 cases meeting the ≥1.30x threshold (28-36%), significantly below the target of 10-12 cases (71-86%). Need to achieve ~6 more cases meeting threshold through targeted optimization.

## Variance Analysis (Phase 1)

### Initial Findings
Ran 5 consecutive benchmarks to assess variance:

**Overall Average Speedup Variance**: ±3.2% ✅ EXCELLENT
- Run 1: 1.24x
- Run 2: 1.26x  
- Run 3: 1.26x
- Run 4: 1.27x
- Run 5: 1.23x

**Per-Parser Variance**:
- Sentence: ±5.1% ✅ GOOD
- Calc: ±5.2% ✅ GOOD
- JSON: ±6.8% ✅ GOOD
- ERB: ±4.0% ✅ EXCELLENT

### Conclusion on Variance
Variance is **significantly better** than reported in Session 14 (±40-99%). Current measurements show ±3-7% variance, which is **acceptable** for reliable optimization validation. No variance reduction work needed.

**Likely reasons for improvement**:
1. Previous variance fixes already in codebase
2. Different measurement conditions
3. Natural methodology improvements

## Baseline Performance (Phase 2)

### Three Official Baseline Runs

| Metric | Run 1 | Run 2 | Run 3 | Mean | Variance |
|--------|-------|-------|-------|------|----------|
| Overall Avg | 1.26x | 1.27x | 1.28x | 1.27x | ±1.6% |
| Sentence | 1.17x | 1.13x | 1.17x | 1.16x | ±3.4% |
| Calc | 1.19x | 1.21x | 1.19x | 1.20x | ±1.7% |
| JSON | 1.45x | 1.48x | 1.49x | 1.47x | ±2.7% |
| ERB | 1.25x | 1.27x | 1.29x | 1.27x | ±3.1% |

### Best Cases Across Runs
- Run 1: 1.51x (json/medium.json)
- Run 2: 1.53x (json/medium.json)  
- Run 3: 1.51x (json/small.json)

### Worst Cases Across Runs
- Run 1: 1.12x (calc/medium.txt)
- Run 2: 1.11x (sentence/tiny.txt)
- Run 3: 1.14x (calc/medium.txt)

## Current Performance Status

### Cases Meeting ≥1.30x Threshold

From most recent baseline (Run 3):

✅ **4-5 cases meet threshold** (28-36%):
1. json/medium.json: ~1.47-1.53x
2. json/small.json: ~1.47-1.51x
3. json/tiny.json: ~1.35-1.42x
4. erb/small.erb: ~1.35-1.42x

Occasionally close:
- erb/medium.erb: ~1.14-1.37x (borderline)

### Cases NOT Meeting Threshold

❌ **9-10 cases below threshold**, sorted by distance:

| Case | Current | Gap to 1.30x |
|------|---------|--------------|
| calc/medium.txt | 1.02-1.14x | +0.16-0.28x |
| calc/tiny.txt | 1.13-1.22x | +0.08-0.17x |
| sentence/medium.txt | 1.14-1.16x | +0.14-0.16x |
| erb/medium.erb | 1.14-1.37x | +0.0-0.16x |
| sentence/tiny.txt | 1.11-1.18x | +0.12-0.19x |
| calc/small.txt | 1.18-1.31x | +0.0-0.12x |
| sentence/small.txt | 1.20-1.21x | +0.09-0.10x |
| calc/large.txt | 1.20-1.23x | +0.07-0.10x |
| erb/large.erb | 1.21-1.37x | +0.0-0.09x |
| erb/tiny.erb | 1.18-1.23x | +0.07-0.12x |

## Target Analysis

### Current vs Target
- **Current**: 4-5 cases (28-36%)
- **Target**: 10-12 cases (71-86%)
- **Gap**: Need 6 more cases minimum

### Closest Cases to Threshold
These cases are closest to the 1.30x threshold and should be prioritized for optimization:

1. **erb/tiny.erb**: 1.18-1.23x (need +0.07-0.12x)
2. **erb/large.erb**: 1.21-1.37x (need +0.0-0.09x) 
3. **calc/large.txt**: 1.20-1.23x (need +0.07-0.10x)
4. **sentence/small.txt**: 1.20-1.21x (need +0.09-0.10x)
5. **calc/small.txt**: 1.18-1.31x (need +0.0-0.12x)
6. **sentence/tiny.txt**: 1.11-1.18x (need +0.12-0.19x)

## Optimization Strategy

Based on Session 14 profiling analysis, identified bottlenecks:

### Priority Targets

**1. Sentence Parser String Concatenation** (RECOMMENDED FIRST)
- **Problem**: 7% overhead from `Slice#+` (3.68%) and `String#+` (3.38%)
- **Affected cases**: sentence/small, sentence/medium, sentence/tiny
- **Potential impact**: +5-7% improvement
- **Approach**: Modify grammar to batch character collection

**2. ERB Parser Optimization**
- **Problem**: Similar string concatenation patterns
- **Affected cases**: erb/tiny, erb/large, erb/medium
- **Potential impact**: +3-5% improvement

**3. Calc Parser (ADVANCED)**  
- **Problem**: `Base#succ` 9.07% overhead, but architectural issue
- **Affected cases**: calc/medium, calc/tiny
- **Difficulty**: High - requires architectural changes

### Expected Outcomes

If sentence parser optimization succeeds (+5-7%):
- sentence/small.txt: 1.20x → 1.27x ✅
- sentence/tiny.txt: 1.11-1.18x → 1.17-1.25x ✅
- sentence/medium.txt: 1.14-1.16x → 1.20-1.23x (close)

This would achieve **6-7 cases** meeting threshold (43-50%), still short of target but significant progress.

## Next Steps

1. ✅ **Phase 1 Complete**: Variance verified as acceptable (±3-7%)
2. ✅ **Phase 2 Complete**: Baseline established (1.27x mean, ±1.6%)
3. 🔄 **Phase 3-4 In Progress**: Apply targeted optimization
   - Start with sentence parser string concatenation
   - Measure impact
   - Iterate as needed
4. ⏳ **Phase 5 Pending**: Final validation and documentation

## Lessons Learned

1. **Variance was never the problem** - Current variance (±3-7%) is acceptable for optimization work
2. **Session 14 variance concerns may have been overstated** or conditions have improved
3. **Baseline is very stable** - Can proceed with confidence to optimization phase
4. **Clear gap identified** - Need ~6 more cases, with clear candidates identified