# frozen_string_literal: true

require_relative '../ast_visitor'

module Parslet
  module Optimizers
    # Optimizes sequence patterns in the AST
    # Follows visitor pattern for clean separation of concerns
    #
    # Transformations:
    # - str('a') >> str('b') => str('ab') (merge adjacent strings)
    # - (A >> B) >> C => A >> B >> C (flatten nested sequences)
    # - Sequence(A) => A (unwrap single-element sequences)
    class SequenceOptimizer < ASTVisitor
      # Visit a sequence node and apply sequence optimizations
      # @param parslet [Parslet::Atoms::Sequence] sequence to optimize
      # @return [Parslet::Atoms::Base] optimized parslet
      def visit_sequence(parslet)
        # First optimize children recursively
        new_parslets = parslet.parslets.map { |p| visit(p) }

        # Optimization 1: Flatten nested sequences
        flattened = flatten_sequences(new_parslets)

        # Optimization 2: Merge adjacent string literals
        merged = merge_adjacent_strings(flattened)

        # Optimization 3: Unwrap single-element sequences
        return merged[0] if merged.size == 1

        # Return optimized sequence if changed
        if merged != parslet.parslets
          Parslet::Atoms::Sequence.new(*merged)
        else
          parslet
        end
      end

      private

      # Flatten nested sequences into a single level
      # @param parslets [Array<Parslet::Atoms::Base>] array of parslets
      # @return [Array<Parslet::Atoms::Base>] flattened array
      def flatten_sequences(parslets)
        result = []
        parslets.each do |p|
          if p.is_a?(Parslet::Atoms::Sequence)
            result.concat(p.parslets)
          else
            result << p
          end
        end
        result
      end

      # Merge adjacent Str atoms into single Str atoms
      # @param parslets [Array<Parslet::Atoms::Base>] array of parslets
      # @return [Array<Parslet::Atoms::Base>] array with merged strings
      def merge_adjacent_strings(parslets)
        return parslets if parslets.size < 2

        result = []
        i = 0

        while i < parslets.size
          current = parslets[i]

          if current.is_a?(Parslet::Atoms::Str)
            # Look ahead for consecutive Str atoms
            merged_str = current.str
            j = i + 1

            while j < parslets.size && parslets[j].is_a?(Parslet::Atoms::Str)
              merged_str = merged_str + parslets[j].str
              j += 1
            end

            # Create merged Str if we found consecutive strings
            if j > i + 1
              result << Parslet::Atoms::Str.new(merged_str)
              i = j
            else
              result << current
              i += 1
            end
          else
            result << current
            i += 1
          end
        end

        result
      end
    end
  end
end
