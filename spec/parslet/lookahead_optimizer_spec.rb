# frozen_string_literal: true

require 'spec_helper'

describe Parslet::Optimizer, '.simplify_lookaheads' do
  let(:str_a) { Parslet::Atoms::Str.new('a') }
  let(:str_b) { Parslet::Atoms::Str.new('b') }

  describe 'double negation simplification' do
    it 'simplifies !(!x) to &x' do
      inner = Parslet::Atoms::Lookahead.new(str_a, false)  # !a
      outer = Parslet::Atoms::Lookahead.new(inner, false)  # !(!a)

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be true
      expect(result.bound_parslet).to eq(str_a)
    end

    it 'simplifies triple negation !(!(!x)) to !x' do
      inner1 = Parslet::Atoms::Lookahead.new(str_a, false)  # !a
      inner2 = Parslet::Atoms::Lookahead.new(inner1, false)  # !(!a)
      outer = Parslet::Atoms::Lookahead.new(inner2, false)  # !(!(!a))

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be false
      expect(result.bound_parslet).to eq(str_a)
    end
  end

  describe 'idempotent positive lookahead' do
    it 'simplifies &(&x) to &x' do
      inner = Parslet::Atoms::Lookahead.new(str_a, true)  # &a
      outer = Parslet::Atoms::Lookahead.new(inner, true)  # &(&a)

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be true
      expect(result.bound_parslet).to eq(str_a)
    end

    it 'simplifies &(&(&x)) to &x' do
      inner1 = Parslet::Atoms::Lookahead.new(str_a, true)  # &a
      inner2 = Parslet::Atoms::Lookahead.new(inner1, true)  # &(&a)
      outer = Parslet::Atoms::Lookahead.new(inner2, true)  # &(&(&a))

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be true
      expect(result.bound_parslet).to eq(str_a)
    end
  end

  describe 'negative of positive simplification' do
    it 'simplifies !(&x) to !x' do
      inner = Parslet::Atoms::Lookahead.new(str_a, true)   # &a
      outer = Parslet::Atoms::Lookahead.new(inner, false)  # !(&a)

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be false
      expect(result.bound_parslet).to eq(str_a)
    end
  end

  describe 'positive of negative simplification' do
    it 'simplifies &(!x) to !x' do
      inner = Parslet::Atoms::Lookahead.new(str_a, false)  # !a
      outer = Parslet::Atoms::Lookahead.new(inner, true)   # &(!a)

      result = Parslet::Optimizer.simplify_lookaheads(outer)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be false
      expect(result.bound_parslet).to eq(str_a)
    end
  end

  describe 'recursive optimization' do
    it 'optimizes lookaheads nested in sequences' do
      # Sequence(!(!a), b) => Sequence(&a, b)
      inner = Parslet::Atoms::Lookahead.new(str_a, false)
      outer = Parslet::Atoms::Lookahead.new(inner, false)
      seq = Parslet::Atoms::Sequence.new(outer, str_b)

      result = Parslet::Optimizer.simplify_lookaheads(seq)

      expect(result).to be_a(Parslet::Atoms::Sequence)
      expect(result.parslets[0]).to be_a(Parslet::Atoms::Lookahead)
      expect(result.parslets[0].positive).to be true
      expect(result.parslets[1]).to eq(str_b)
    end

    it 'optimizes lookaheads nested in alternatives' do
      # Alternative(!(!a), b) => Alternative(&a, b)
      inner = Parslet::Atoms::Lookahead.new(str_a, false)
      outer = Parslet::Atoms::Lookahead.new(inner, false)
      alt = Parslet::Atoms::Alternative.new(outer, str_b)

      result = Parslet::Optimizer.simplify_lookaheads(alt)

      expect(result).to be_a(Parslet::Atoms::Alternative)
      expect(result.alternatives[0]).to be_a(Parslet::Atoms::Lookahead)
      expect(result.alternatives[0].positive).to be true
      expect(result.alternatives[1]).to eq(str_b)
    end

    it 'optimizes lookaheads nested in repetitions' do
      # Repetition(!(!a)) => Repetition(&a)
      inner = Parslet::Atoms::Lookahead.new(str_a, false)
      outer = Parslet::Atoms::Lookahead.new(inner, false)
      rep = Parslet::Atoms::Repetition.new(outer, 0, nil, nil)

      result = Parslet::Optimizer.simplify_lookaheads(rep)

      expect(result).to be_a(Parslet::Atoms::Repetition)
      expect(result.parslet).to be_a(Parslet::Atoms::Lookahead)
      expect(result.parslet.positive).to be true
    end

    it 'optimizes lookaheads nested in named atoms' do
      # Named(!(!a)) => Named(&a)
      inner = Parslet::Atoms::Lookahead.new(str_a, false)
      outer = Parslet::Atoms::Lookahead.new(inner, false)
      named = Parslet::Atoms::Named.new(outer, :test)

      result = Parslet::Optimizer.simplify_lookaheads(named)

      expect(result).to be_a(Parslet::Atoms::Named)
      expect(result.parslet).to be_a(Parslet::Atoms::Lookahead)
      expect(result.parslet.positive).to be true
    end
  end

  describe 'preserving semantics' do
    it 'does not modify leaf atoms' do
      result = Parslet::Optimizer.simplify_lookaheads(str_a)
      expect(result).to eq(str_a)
    end

    it 'does not modify single lookahead' do
      la = Parslet::Atoms::Lookahead.new(str_a, true)
      result = Parslet::Optimizer.simplify_lookaheads(la)

      expect(result).to eq(la)
    end

    it 'does not modify negative single lookahead' do
      la = Parslet::Atoms::Lookahead.new(str_a, false)
      result = Parslet::Optimizer.simplify_lookaheads(la)

      expect(result).to eq(la)
    end
  end

  describe 'structural verification' do
    it 'double negation creates correct structure' do
      # !(!str('a')) => &str('a')
      inner = Parslet::Atoms::Lookahead.new(str_a, false)
      outer = Parslet::Atoms::Lookahead.new(inner, false)

      optimized = Parslet::Optimizer.simplify_lookaheads(outer)

      # Optimized version should be positive lookahead
      expect(optimized).to be_a(Parslet::Atoms::Lookahead)
      expect(optimized.positive).to be true
      expect(optimized.bound_parslet).to eq(str_a)
    end

    it 'idempotent positive lookahead creates correct structure' do
      # &(&str('a')) => &str('a')
      inner = Parslet::Atoms::Lookahead.new(str_a, true)
      outer = Parslet::Atoms::Lookahead.new(inner, true)

      optimized = Parslet::Optimizer.simplify_lookaheads(outer)

      # Should be simplified to single positive lookahead
      expect(optimized).to be_a(Parslet::Atoms::Lookahead)
      expect(optimized.positive).to be true
      expect(optimized.bound_parslet).to eq(str_a)
    end

    it 'negative of positive creates correct structure' do
      # !(&str('a')) => !str('a')
      inner = Parslet::Atoms::Lookahead.new(str_a, true)
      outer = Parslet::Atoms::Lookahead.new(inner, false)

      optimized = Parslet::Optimizer.simplify_lookaheads(outer)

      # Should be simplified to negative lookahead
      expect(optimized).to be_a(Parslet::Atoms::Lookahead)
      expect(optimized.positive).to be false
      expect(optimized.bound_parslet).to eq(str_a)
    end

    it 'complex nested lookaheads create correct structure' do
      # Sequence(&(!(!str('a'))), str('a')) => Sequence(&str('a'), str('a'))
      inner1 = Parslet::Atoms::Lookahead.new(str_a, false)
      inner2 = Parslet::Atoms::Lookahead.new(inner1, false)
      outer = Parslet::Atoms::Lookahead.new(inner2, true)
      seq = Parslet::Atoms::Sequence.new(outer, str_a)

      optimized = Parslet::Optimizer.simplify_lookaheads(seq)

      # Should have optimized lookahead in sequence
      expect(optimized).to be_a(Parslet::Atoms::Sequence)
      expect(optimized.parslets[0]).to be_a(Parslet::Atoms::Lookahead)
      expect(optimized.parslets[0].positive).to be true
      expect(optimized.parslets[1]).to eq(str_a)
    end
  end

  describe 'complex optimization scenarios' do
    it 'handles alternating positive and negative lookaheads' do
      # !(&(!(&a))) => &a
      la1 = Parslet::Atoms::Lookahead.new(str_a, true)   # &a
      la2 = Parslet::Atoms::Lookahead.new(la1, false)    # !(&a) => !a
      la3 = Parslet::Atoms::Lookahead.new(la2, true)     # &(!a) => !a
      la4 = Parslet::Atoms::Lookahead.new(la3, false)    # !(!a) => &a

      result = Parslet::Optimizer.simplify_lookaheads(la4)

      expect(result).to be_a(Parslet::Atoms::Lookahead)
      expect(result.positive).to be true
      expect(result.bound_parslet).to eq(str_a)
    end

    it 'optimizes lookaheads at multiple levels' do
      # Sequence(Alternative(!(!a), &(&b)), str('c'))
      la1 = Parslet::Atoms::Lookahead.new(str_a, false)
      la2 = Parslet::Atoms::Lookahead.new(la1, false)  # Should become &a
      la3 = Parslet::Atoms::Lookahead.new(str_b, true)
      la4 = Parslet::Atoms::Lookahead.new(la3, true)   # Should become &b
      alt = Parslet::Atoms::Alternative.new(la2, la4)
      seq = Parslet::Atoms::Sequence.new(alt, Parslet::Atoms::Str.new('c'))

      result = Parslet::Optimizer.simplify_lookaheads(seq)

      expect(result).to be_a(Parslet::Atoms::Sequence)
      alt_result = result.parslets[0]
      expect(alt_result).to be_a(Parslet::Atoms::Alternative)
      expect(alt_result.alternatives[0].positive).to be true
      expect(alt_result.alternatives[1].positive).to be true
    end
  end
end
