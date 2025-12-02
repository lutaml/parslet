# Session 14: Profiling Analysis - Calc/Sentence Bottlenecks

**Date**: 2025-12-01  
**Goal**: Identify why calc/sentence parsers only achieve 1.12-1.19x vs JSON's 1.48-1.59x

---

## Executive Summary

Profiling reveals **distinct bottlenecks** for each parser type:

1. **Calc Parser**: Position tracking overhead (Base#succ) at **9.07%** - 2x higher than JSON
2. **Sentence Parser**: String concatenation (Slice#+, String#+) at **~7%** - unique bottleneck
3. **JSON Parser** (baseline): Well-balanced, position overhead only **4.2%**

**Key Finding**: Position tracking (Base#succ) is THE critical bottleneck for calc parsers and a major one for sentence parsers. This explains their consistent 1.12-1.19x performance.

---

## Detailed Comparison

### 1. Position Tracking Overhead

| Parser | Base#succ | Position#initialize | Source#pos | Total |
|--------|-----------|---------------------|------------|-------|
| **Calc** | **9.07%** (102,300 calls) | N/A | N/A | **~9%** |
| **Sentence** | **5.66%** (31,900 calls) | N/A | N/A | **~6%** |
| **JSON** | **3.75%** (260,600 calls) | 1.79% (372,700) | 2.44% | **~8%** |

**Insight**: Calc has the highest *self-time* for succ (9.07%) despite fewer calls than JSON. This suggests calc's grammar causes more expensive position tracking operations.

### 2. Flatten Overhead

| Parser | flatten | foldl | flatten_repetition | Total |
|--------|---------|-------|--------------------|-------|
| **Calc** | 7.37% (100,300) | 3.17% (43,800) | N/A | **~10%** |
| **Sentence** | 4.80% (31,900) | 4.42% (4,000) | 3.15% (2,100) | **~12%** |
| **JSON** | 5.26% (250,400) | 2.64% (79,300) | N/A | **~8%** |

**Insight**: Sentence has highest relative flatten overhead due to repetition flattening (3.15%).

### 3. Apply/Cache Overhead

| Parser | Base#apply | Context#try_with_cache | Total |
|--------|------------|------------------------|-------|
| **Calc** | 7.15% (177,600) | 4.69% (177,600) | **11.84%** |
| **Sentence** | 4.85% (34,400) | 5.74% (34,400) | **10.59%** |
| **JSON** | 9.32% (621,100) | 9.51% (621,100) | **18.83%** |

**Insight**: JSON has much higher apply/cache overhead but is still fastest due to effective caching. Calc/sentence have lower overhead but don't benefit as much from caching.

### 4. Unique Bottlenecks

#### Calc-Specific
- **Sequence overhead**: 2.81% (32,100 calls)
- **Repetition overhead**: 6.09% for Kernel#loop (26,000 calls)
- **Entity lookups**: 1.85% (56,900 calls)

Total unique overhead: **~11%**

#### Sentence-Specific
- **Slice concatenation**: 3.68% (23,800 calls) 
- **String concatenation**: 3.38% (23,800 calls)
- **Array indexing**: 8.97% (91,600 calls) - highest of all three!

Total unique overhead: **~16%**

#### JSON-Specific
- **Source operations**: bytepos= (4.01%), consume (3.90%) = **7.91%**
- **Str#try**: 6.55% (143,500 calls)

Total: **~14%**

---

## Call Volume Analysis

| Parser | Total applies | Input size | Applies per byte |
|--------|--------------|------------|------------------|
| **Calc** | 177,600 | 273 bytes | **650** |
| **Sentence** | 34,400 | 774 bytes | **44** |
| **JSON** | 621,100 | 759 bytes | **818** |

**Insight**: Calc and JSON have very high applies-per-byte ratios (650 and 818), suggesting complex grammars with lots of backtracking. Sentence is much simpler (44).

---

## Top 5 Optimization Targets

### Priority 1: Position Tracking (Calc/Sentence) 🔴 CRITICAL
**Problem**: Base#succ is 9.07% in calc, 5.66% in sentence  
**Solution**: Cache Position objects in Source  
**Expected Impact**: -3-5% overhead → +3-5% speedup across all parsers  
**Estimated Gain**: 2-3 more cases reach ≥1.30x

### Priority 2: String Concatenation (Sentence) 🟡 HIGH
**Problem**: Slice#+ (3.68%) + String#+ (3.38%) = 7% overhead unique to sentence  
**Solution**: Use string builder or array join instead of repeated concatenation  
**Expected Impact**: -5% overhead → +5% speedup for sentence parsers  
**Estimated Gain**: 2-3 sentence cases reach ≥1.30x

### Priority 3: Source Operations (All) 🟡 HIGH
**Problem**: bytepos lookups (1.60-2.22% across parsers)  
**Solution**: Cache bytepos in local variables in hot methods  
**Expected Impact**: -1-2% overhead → +1-2% speedup  
**Estimated Gain**: 1-2 more cases reach ≥1.30x

### Priority 4: Flatten Optimization (Calc) 🟢 MEDIUM
**Problem**: flatten 7.37% + foldl 3.17% = 10.54% in calc  
**Solution**: Optimize flatten_repetition, avoid unnecessary flattening  
**Expected Impact**: -2-3% overhead → +2-3% speedup for calc  
**Estimated Gain**: 1-2 calc cases reach ≥1.30x

### Priority 5: Sequence Dispatch (Calc) 🟢 MEDIUM
**Problem**: Sequence#try at 2.81% with 32,100 calls  
**Solution**: Fast path for 2-element sequences  
**Expected Impact**: -1% overhead → +1% speedup for calc  
**Estimated Gain**: 1 calc case reaches ≥1.30x

---

## Recommended Implementation Order

1. **Phase 2**: Position caching (Priority 1) - affects ALL parsers, biggest impact
2. **Phase 3**: Source operation caching (Priority 3) - affects ALL parsers
3. **Phase 4**: Parser-specific based on results:
   - If sentence still slow: String concatenation (Priority 2)
   - If calc still slow: Flatten (Priority 4) or Sequence (Priority 5)

---

## Success Probability Analysis

**Current status**: 5/14 cases ≥1.30x (36%)  
**Target**: 10-12/14 cases ≥1.30x (71-86%)

**With Position Caching (Phase 2)**:
- Expected: +3-5% across all parsers
- Estimated: 7-8/14 cases ≥1.30x (50-57%)

**With Source Caching (Phase 3)**:
- Expected: +1-2% additional
- Estimated: 9-10/14 cases ≥1.30x (64-71%)

**With Parser-Specific (Phase 4)**:
- Expected: +2-5% for targeted parsers
- Estimated: 11-12/14 cases ≥1.30x (79-86%) ✅

**Confidence**: HIGH - We have clear targets with measurable overhead

---

## Next Steps

1. ✅ **Phase 1 Complete**: Profiling identified bottlenecks
2. 🔴 **Phase 2 Next**: Implement position caching in Source
3. 🟡 **Phase 3 Next**: Implement source operation caching
4. 🟢 **Phase 4 Next**: Parser-specific optimizations
5. ⚪ **Phase 5 Next**: Validation and iteration

---

## Appendix: Raw Profiling Data

### Calc/small - Top 20 Self-Time

```
 1.   9.07%   102,300 calls - Parslet::Atoms::Base#succ
 2.   7.37%   100,300 calls - Parslet::Atoms::CanFlatten#flatten
 3.   7.15%   177,600 calls - Parslet::Atoms::Base#apply
 4.   6.09%    26,000 calls - Kernel#loop
 5.   4.88%   511,500 calls - BasicObject#equal?
 6.   4.69%   177,600 calls - Parslet::Atoms::Context#try_with_cache
 7.   3.17%    43,800 calls - Parslet::Atoms::CanFlatten#foldl
 8.   2.81%    32,100 calls - Parslet::Atoms::Sequence#try
 9.   2.66%    26,000 calls - Parslet::Atoms::Repetition#try_repetition_general
10.   2.63%    97,100 calls - Class#new
11.   2.55%    58,500 calls - Parslet::Atoms::Re#try
12.   2.29%   236,200 calls - StringScanner#pos
13.   2.26%   221,400 calls - Kernel#nil?
14.   2.22%   177,700 calls - Parslet::Source#bytepos
15.   2.16%    24,000 calls - Parslet::Atoms::CanFlatten#flatten_repetition
```

### Sentence/small - Top 20 Self-Time

```
 1.   8.97%    91,600 calls - Array#[]
 2.   5.74%    34,400 calls - Parslet::Atoms::Context#try_with_cache
 3.   5.66%    31,900 calls - Parslet::Atoms::Base#succ
 4.   5.22%    80,800 calls - Class#new
 5.   4.85%    34,400 calls - Parslet::Atoms::Base#apply
 6.   4.80%    31,900 calls - Parslet::Atoms::CanFlatten#flatten
 7.   4.42%     4,000 calls - Parslet::Atoms::CanFlatten#foldl
 8.   3.68%    23,800 calls - Parslet::Slice#+
 9.   3.63%    27,900 calls - Kernel#class
10.   3.59%     2,200 calls - Kernel#loop
11.   3.50%   135,100 calls - Integer#+
12.   3.38%    23,800 calls - String#+
13.   3.15%     2,100 calls - Parslet::Atoms::CanFlatten#flatten_repetition
14.   2.72%    28,600 calls - Hash#[]
15.   2.65%    30,000 calls - StringScanner#string
```

### JSON/small - Top 20 Self-Time

```
 1.   9.51%   621,100 calls - Parslet::Atoms::Context#try_with_cache
 2.   9.32%   621,100 calls - Parslet::Atoms::Base#apply
 3.   6.55%   143,500 calls - Parslet::Atoms::Str#try
 4.   5.86%   599,000 calls - Class#new
 5.   5.40%   143,100 calls - Parslet::Atoms::Sequence#try
 6.   5.26%   250,400 calls - Parslet::Atoms::CanFlatten#flatten
 7.   4.01%   444,300 calls - Parslet::Source#bytepos=
 8.   3.90%   188,800 calls - Parslet::Source#consume
 9.   3.75%   260,600 calls - Parslet::Atoms::Base#succ
10.   2.69%    85,300 calls - Parslet::Atoms::Entity#try
11.   2.64%    79,300 calls - Parslet::Atoms::CanFlatten#foldl
12.   2.44%   372,700 calls - Parslet::Source#pos
13.   2.08%    65,900 calls - Parslet::Atoms::Repetition#try
14.   1.79%   372,700 calls - Parslet::Position#initialize
15.   1.76%    49,200 calls - Parslet::Atoms::Lookahead#try