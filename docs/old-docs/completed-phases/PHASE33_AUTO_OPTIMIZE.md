# Phase 33: Automatic Quantifier Simplification

## Overview

Phase 33 implements automatic, opt-in quantifier simplification during parser construction. This feature allows developers to enable automatic optimization of redundant repetitions across all rules in a parser by simply calling `optimize_rules!` at the class level.

## Implementation

### Core Changes

**File: `lib/parslet.rb`**

Added two class methods to `Parslet::ClassMethods`:

1. `optimize_rules!` - Enables automatic optimization for all rules
2. `optimize_rules?` - Checks if optimization is enabled

Modified the `rule()` method to automatically apply quantifier simplification when enabled:

```ruby
def rule(name, opts={}, &definition)
  undef_method name if method_defined? name
  define_method(name) do
    @rules ||= {}
    return @rules[name] if @rules.has_key?(name)

    definition_closure = proc {
      result = self.instance_eval(&definition)

      # Apply optimizations if enabled (only for classes that support it)
      if self.class.respond_to?(:optimize_rules?) && self.class.optimize_rules?
        result = Parslet::Optimizer.simplify_quantifiers(result)
      end

      result
    }

    @rules[name] = Atoms::Entity.new(name, opts[:label], &definition_closure)
  end
end
```

### Design Decisions

1. **Opt-in by Default**: Optimization is disabled by default to maintain 100% backward compatibility
2. **Class-level Control**: One call to `optimize_rules!` enables optimization for all rules in that parser
3. **Graceful Degradation**: Uses `respond_to?` check to support both `Parslet::Parser` classes and modules that include `Parslet`
4. **Reuses Phase 32 Infrastructure**: Leverages `Parslet::Optimizer.simplify_quantifiers` from Phase 32

## Usage

### Basic Usage

```ruby
class MyParser < Parslet::Parser
  optimize_rules!  # Enable automatic optimization

  rule(:redundant) {
    str('a').repeat(1, 1) >>
    str('b').repeat(1, 1)
  }
  # Automatically becomes: str('a') >> str('b')

  root :redundant
end
```

### Without Optimization (Default)

```ruby
class LegacyParser < Parslet::Parser
  # No optimize_rules! call - works exactly as before

  rule(:test) { str('a').repeat(1, 1) }
  # Stays as: str('a').repeat(1, 1)

  root :test
end
```

## Test Coverage

**File: `spec/parslet/auto_optimize_spec.rb`** (158 lines, 12 tests)

Test categories:

1. **Automatic Simplification** (4 tests)
   - `repeat(1,1)` simplification
   - Nested `maybe` simplification
   - Multiplied exact counts
   - Comparison with manual optimization

2. **Backward Compatibility** (2 tests)
   - Default behavior without `optimize_rules!`
   - Legacy parsers remain unchanged

3. **Complex Structures** (2 tests)
   - Deeply nested repetitions
   - Mixed simplifiable and non-simplifiable patterns

4. **Edge Cases** (2 tests)
   - Non-trivial repetitions (not simplified)
   - Unbounded repetitions (not simplified)

5. **Module Support** (2 tests)
   - Works with modules including `Parslet`
   - Gracefully handles missing methods

## Performance Impact

Since this feature is opt-in and only activates during parser construction (not during parsing), the performance impact is:

1. **When Disabled** (default): Zero overhead - no change to existing parsers
2. **When Enabled**:
   - One-time cost during parser class definition
   - Parsing performance matches Phase 32 optimized parsers (33.6% speedup)
   - No runtime overhead after rules are defined

## Benefits

1. **Convenience**: Single call enables optimization across all rules
2. **Consistency**: All rules use the same optimization level
3. **Maintainability**: Easy to toggle optimization on/off for testing
4. **Safety**: Opt-in design prevents unexpected behavior changes
5. **Composability**: Works seamlessly with Phase 32's manual optimization

## Compatibility

- ✅ Fully backward compatible
- ✅ Works with `Parslet::Parser` classes
- ✅ Works with modules including `Parslet`
- ✅ Compatible with all existing tests (537/537 passing)
- ✅ No breaking changes to public API

## Example: Optimized Parser

```ruby
class OptimizedJSONParser < Parslet::Parser
  optimize_rules!  # Enable optimization for all rules

  rule(:value) {
    object | array | string | number |
    true_token | false_token | null_token
  }

  rule(:string) {
    str('"') >>
    (str('\\') >> any | str('"').absent? >> any).repeat(0).as(:string) >>
    str('"')
  }

  # All redundant repetitions are automatically optimized
  # No need to manually optimize each rule
end
```

## Integration with Other Phases

Phase 33 complements existing optimization phases:

- **Phase 32**: Provides the underlying simplification engine
- **GPeg Phases (15-31)**: Cache optimizations work alongside quantifier simplification
- **Future Phases**: Can be extended to support additional optimizations

## Future Enhancements

Potential extensions to this feature:

1. **Fine-grained Control**: Per-rule optimization directives
2. **Optimization Levels**: Multiple optimization strategies (speed vs. memory)
3. **Optimization Reports**: Log what optimizations were applied
4. **Custom Optimizers**: Allow user-defined optimization passes

## Summary

Phase 33 successfully implements automatic, opt-in quantifier simplification that:

- Maintains 100% backward compatibility
- Provides convenient class-level optimization control
- Achieves the same performance gains as manual optimization
- Supports both classes and modules
- Passes all 537 tests including 12 new comprehensive tests

The feature is production-ready and can be safely adopted by users who want automatic optimization without modifying their rule definitions.
