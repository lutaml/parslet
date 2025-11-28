# frozen_string_literal: true

# Base class for AST visitors following the Visitor pattern
# This separates tree traversal logic from transformation logic
# making the code more maintainable and extensible.
module Parslet
  # Base visitor class that traverses the Parslet AST
  # Subclasses override visit_* methods to perform transformations
  class ASTVisitor
    # Visit a parslet and its children
    # Subclasses should override specific visit_* methods
    # @param parslet [Parslet::Atoms::Base] parslet to visit
    # @return [Parslet::Atoms::Base] transformed parslet
    def visit(parslet)
      case parslet
      when Parslet::Atoms::Sequence
        visit_sequence(parslet)
      when Parslet::Atoms::Alternative
        visit_alternative(parslet)
      when Parslet::Atoms::Repetition
        visit_repetition(parslet)
      when Parslet::Atoms::Lookahead
        visit_lookahead(parslet)
      when Parslet::Atoms::Named
        visit_named(parslet)
      when Parslet::Atoms::Str
        visit_str(parslet)
      when Parslet::Atoms::Re
        visit_re(parslet)
      else
        # Leaf nodes or unknown types - return as-is
        parslet
      end
    end

    # Visit a sequence node
    # Default implementation visits children and reconstructs if changed
    # @param parslet [Parslet::Atoms::Sequence] sequence to visit
    # @return [Parslet::Atoms::Base] transformed sequence
    def visit_sequence(parslet)
      new_parslets = parslet.parslets.map { |p| visit(p) }
      if new_parslets == parslet.parslets
        parslet
      else
        Parslet::Atoms::Sequence.new(*new_parslets)
      end
    end

    # Visit an alternative node
    # Default implementation visits children and reconstructs if changed
    # @param parslet [Parslet::Atoms::Alternative] alternative to visit
    # @return [Parslet::Atoms::Base] transformed alternative
    def visit_alternative(parslet)
      new_alternatives = parslet.alternatives.map { |p| visit(p) }
      if new_alternatives == parslet.alternatives
        parslet
      else
        Parslet::Atoms::Alternative.new(*new_alternatives)
      end
    end

    # Visit a repetition node
    # Default implementation visits child and reconstructs if changed
    # @param parslet [Parslet::Atoms::Repetition] repetition to visit
    # @return [Parslet::Atoms::Base] transformed repetition
    def visit_repetition(parslet)
      new_parslet = visit(parslet.parslet)
      if new_parslet.equal?(parslet.parslet)
        parslet
      else
        Parslet::Atoms::Repetition.new(
          new_parslet,
          parslet.min,
          parslet.max,
          parslet.instance_variable_get(:@tag)
        )
      end
    end

    # Visit a lookahead node
    # Default implementation visits child and reconstructs if changed
    # @param parslet [Parslet::Atoms::Lookahead] lookahead to visit
    # @return [Parslet::Atoms::Base] transformed lookahead
    def visit_lookahead(parslet)
      new_bound = visit(parslet.bound_parslet)
      if new_bound.equal?(parslet.bound_parslet)
        parslet
      else
        Parslet::Atoms::Lookahead.new(new_bound, parslet.positive)
      end
    end

    # Visit a named node
    # Default implementation visits child and reconstructs if changed
    # @param parslet [Parslet::Atoms::Named] named to visit
    # @return [Parslet::Atoms::Base] transformed named
    def visit_named(parslet)
      new_parslet = visit(parslet.parslet)
      if new_parslet.equal?(parslet.parslet)
        parslet
      else
        Parslet::Atoms::Named.new(new_parslet, parslet.name)
      end
    end

    # Visit a string literal node
    # Default implementation returns as-is (leaf node)
    # @param parslet [Parslet::Atoms::Str] string to visit
    # @return [Parslet::Atoms::Base] transformed string
    def visit_str(parslet)
      parslet
    end

    # Visit a regex node
    # Default implementation returns as-is (leaf node)
    # @param parslet [Parslet::Atoms::Re] regex to visit
    # @return [Parslet::Atoms::Base] transformed regex
    def visit_re(parslet)
      parslet
    end
  end
end
