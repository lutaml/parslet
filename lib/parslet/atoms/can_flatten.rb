
module Parslet::Atoms
  # A series of helper functions that have the common topic of flattening
  # result values into the intermediary tree that consists of Ruby Hashes and
  # Arrays.
  #
  # This module has one main function, #flatten, that takes an annotated
  # structure as input and returns the reduced form that users expect from
  # Atom#parse.
  #
  # NOTE: Since all of these functions are just that, functions without
  # side effects, they are in a module and not in a class. Its hard to draw
  # the line sometimes, but this is beyond.
  #
  module CanFlatten
    # Takes a mixed value coming out of a parslet and converts it to a return
    # value for the user by dropping things and merging hashes.
    #
    # Named is set to true if this result will be embedded in a Hash result from
    # naming something using <code>.as(...)</code>. It changes the folding
    # semantics of repetition.
    #
    def flatten(value, named=false)
      # Passes through everything that isn't an array of things
      return value unless value.instance_of? Array

      # Extracts the s-expression tag
      tag = value[0]

      # Flatten each element
      tail_size = value.size - 1
      result = Array.new(tail_size)
      i = 0
      while i < tail_size
        result[i] = flatten(value[i + 1])
        i += 1
      end

      case tag
        when :sequence
          return flatten_sequence(result)
        when :maybe
          return named ? result.first : result.first || ''
        when :repetition
          return flatten_repetition(result, named)
      end

      fail "BUG: Unknown tag #{tag.inspect}."
    end

    # Lisp style fold left where the first element builds the basis for
    # an inject.
    #
    def foldl(list, &block)
      return '' if list.empty?
      result = list[0]
      i = 1
      len = list.size
      while i < len
        result = block.call(result, list[i])
        i += 1
      end
      result
    end

    # Flatten results from a sequence of parslets.
    #
    # @api private
    #
    def flatten_sequence(list)
      foldl(list.compact) { |r, e|        # and then merge flat elements
        merge_fold(r, e)
      }
    end
    # @api private
    def merge_fold(l, r)
      l_class = l.class
      r_class = r.class

      # equal pairs: merge. ----------------------------------------------------
      if l_class == r_class
        if l_class == Hash
          warn_about_duplicate_keys(l, r)
          return l.merge(r)
        else
          return l + r
        end
      end

      # unequal pairs: hoist to same level. ------------------------------------
      l_is_str = l_class == String || l.instance_of?(Parslet::Slice)
      r_is_str = r_class == String || r.instance_of?(Parslet::Slice)

      # Maybe classes are not equal, but both are stringlike?
      if l_is_str && r_is_str
        # if we're merging a String with a Slice, the slice wins.
        return r if r.instance_of?(Parslet::Slice)
        return l if l.instance_of?(Parslet::Slice)

        fail "NOTREACHED: What other stringlike classes are there?"
      end

      # special case: If one of them is a string/slice, the other is more important
      return l if r_is_str
      return r if l_is_str

      # otherwise just create an array for one of them to live in
      return l + [r] if r_class == Hash
      return [l] + r if l_class == Hash

      fail "Unhandled case when foldr'ing sequence."
    end

    # Flatten results from a repetition of a single parslet. named indicates
    # whether the user has named the result or not. If the user has named
    # the results, we want to leave an empty list alone - otherwise it is
    # turned into an empty string.
    #
    # @api private
    #
    def flatten_repetition(list, named)
      if list.any? { |e| e.instance_of?(Hash) }
        # If keyed subtrees are in the array, we'll want to discard all
        # strings inbetween. To keep them, name them.
        return list.select { |e| e.instance_of?(Hash) }
      end

      if list.any? { |e| e.instance_of?(Array) }
        # If any arrays are nested in this array, flatten all arrays to this
        # level.
        return list.
          select { |e| e.instance_of?(Array) }.
          flatten(1)
      end

      # Consistent handling of empty lists, when we act on a named result
      return [] if named && list.empty?

      # If there are only strings, concatenate them and return that.
      foldl(list.compact) { |s,e| s+e }
    end

    # That annoying warning 'Duplicate subtrees while merging result' comes
    # from here. You should add more '.as(...)' names to your intermediary tree.
    #
    def warn_about_duplicate_keys(h1, h2)
      d = h1.keys & h2.keys
      unless d.empty?
        warn "Duplicate subtrees while merging result of \n  #{self.inspect}\nonly the values"+
             " of the latter will be kept. (keys: #{d.inspect})"
      end
    end
  end
end
