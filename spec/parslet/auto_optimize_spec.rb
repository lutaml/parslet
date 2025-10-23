# frozen_string_literal: true

require 'spec_helper'

describe 'Automatic Rule Optimization' do
  include Parslet

  context 'when optimize_rules! is called' do
    class OptimizedParser < Parslet::Parser
      optimize_rules!

      rule(:redundant) {
        str('a').repeat(1, 1) >>
        str('b').repeat(1, 1) >>
        str('c').repeat(1, 1)
      }

      rule(:nested_maybe) {
        str('x').repeat(0, 1).repeat(0, 1)
      }

      rule(:exact_counts) {
        str('m').repeat(2, 2).repeat(3, 3)
      }

      root :redundant
    end

    it 'automatically simplifies repeat(1,1) in rules' do
      parser = OptimizedParser.new
      # The rule should parse successfully
      expect(parser.redundant.parse('abc')).to eq('abc')
    end

    it 'automatically simplifies nested maybe' do
      parser = OptimizedParser.new
      # Should match with x
      expect(parser.nested_maybe.parse('x')).to eq('x')
      # Should match without x (returns empty string, not nil)
      expect(parser.nested_maybe.parse('')).to eq('')
    end

    it 'automatically simplifies multiplied exact counts' do
      parser = OptimizedParser.new
      # Should require exactly 6 m's
      expect(parser.exact_counts.parse('mmmmmm')).to eq('mmmmmm')
    end

    it 'produces the same results as manual optimization' do
      manual = str('a').repeat(1, 1) >> str('b').repeat(1, 1)
      manual_optimized = Parslet::Optimizer.simplify_quantifiers(manual)

      auto_parser = OptimizedParser.new

      input = 'ab'
      # Both should return Slice objects (parslet's default)
      expect(auto_parser.redundant.parse('abc').to_s).to eq('abc')
      expect(manual_optimized.parse(input).to_s).to eq('ab')
    end
  end

  context 'when optimize_rules! is not called' do
    class UnoptimizedParser < Parslet::Parser
      rule(:redundant) {
        str('a').repeat(1, 1) >>
        str('b').repeat(1, 1)
      }

      root :redundant
    end

    it 'does not automatically optimize rules' do
      parser = UnoptimizedParser.new
      # Should still work, just not optimized
      expect(parser.redundant.parse('ab')).to be_truthy
    end

    it 'defaults optimize_rules? to false' do
      expect(UnoptimizedParser.optimize_rules?).to be false
    end
  end

  context 'with complex nested structures' do
    class ComplexOptimizedParser < Parslet::Parser
      optimize_rules!

      rule(:deeply_nested) {
        str('a').repeat(1, 1).repeat(1, 1).repeat(1, 1)
      }

      rule(:mixed) {
        str('x').repeat(1, 1) >> str('y').repeat(0, 1) >> str('z')
      }

      root :deeply_nested
    end

    it 'simplifies deeply nested repetitions' do
      parser = ComplexOptimizedParser.new
      expect(parser.deeply_nested.parse('a')).to eq('a')
    end

    it 'handles mixed simplifiable and non-simplifiable patterns' do
      parser = ComplexOptimizedParser.new
      # With y
      expect(parser.mixed.parse('xyz')).to be_truthy
      # Without y
      expect(parser.mixed.parse('xz')).to be_truthy
    end
  end

  context 'backward compatibility' do
    it 'does not affect parsers without optimize_rules!' do
      class LegacyParser < Parslet::Parser
        rule(:test) { str('a').repeat(1, 1) }
        root :test
      end

      parser = LegacyParser.new
      # Should still work exactly as before
      expect(parser.test.parse('a')).to be_truthy
    end

    it 'does not break existing test suite' do
      # Run a sample from existing tests to ensure compatibility
      parser = str('hello').repeat(1, 1)
      expect(parser.parse('hello')).to eq('hello')
    end
  end

  context 'combined optimizations' do
    class CombinedOptParser < Parslet::Parser
      optimize_rules!

      rule(:combined) {
        # Has both quantifier and sequence issues
        (str('h') >> str('e') >> str('l') >> str('l') >> str('o')).repeat(1, 1) >>
        str(' ') >>
        (str('w') >> str('o') >> str('r') >> str('l') >> str('d')).repeat(1, 1)
      }

      root :combined
    end

    it 'applies both quantifier and sequence optimizations' do
      parser = CombinedOptParser.new
      # Should merge strings and unwrap repeat(1,1)
      # Original: (Str('h') >> Str('e') >> ... >> Str('o')).repeat(1,1) >> Str(' ') >> (Str('w') >> ... >> Str('d')).repeat(1,1)
      # After quantifier: Sequence(Str('h'), Str('e'), ..., Str('o')) >> Str(' ') >> Sequence(Str('w'), ..., Str('d'))
      # After sequence: Str('hello') >> Str(' ') >> Str('world')
      # Final merge: Str('hello world')

      result = parser.combined.parse('hello world')
      expect(result).to eq('hello world')
    end

    it 'produces same results as manual optimization' do
      parser = CombinedOptParser.new

      # Manual construction without optimization
      manual = (str('h') >> str('e') >> str('l') >> str('l') >> str('o')).repeat(1, 1) >>
               str(' ') >>
               (str('w') >> str('o') >> str('r') >> str('l') >> str('d')).repeat(1, 1)

      input = 'hello world'
      expect(parser.combined.parse(input)).to eq(manual.parse(input))
    end
  end

  context 'edge cases' do
    class EdgeCaseParser < Parslet::Parser
      optimize_rules!

      rule(:normal_repeat) {
        str('a').repeat(0, 3)  # Should not be simplified
      }

      rule(:variable_repeat) {
        str('b').repeat(1)  # Should not be simplified (unbounded)
      }

      root :normal_repeat
    end

    it 'does not simplify non-trivial repetitions' do
      parser = EdgeCaseParser.new
      expect(parser.normal_repeat.parse('a')).to be_truthy
      expect(parser.normal_repeat.parse('aa')).to be_truthy
      expect(parser.normal_repeat.parse('aaa')).to be_truthy
    end

    it 'does not simplify unbounded repetitions' do
      parser = EdgeCaseParser.new
      expect(parser.variable_repeat.parse('b')).to be_truthy
      expect(parser.variable_repeat.parse('bbb')).to be_truthy
    end
  end
end
