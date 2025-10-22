module Parslet::Atoms
  # Helper class that implements a transient cache that maps position and
  # parslet object to results. This is used for memoization in the packrat
  # style.
  #
  # Also, error reporter is stored here and error reporting happens through
  # this class. This makes the reporting pluggable.
  #
  class Context
    # @param reporter [#err, #err_at] Error reporter (leave empty for default
    #   reporter)
    def initialize(reporter=Parslet::ErrorReporter::Tree.new)
      @cache = Hash.new { |h, k| h[k] = {} }
      @reporter = reporter
      @captures = Parslet::Scope.new
    end

    # Caches a parse answer for obj at source.pos. Applying the same parslet
    # at one position of input always yields the same result, unless the input
    # has changed.
    #
    # We need the entire source here so we can ask for how many characters
    # were consumed by a successful parse. Imitation of such a parse must
    # advance the input pos by the same amount of bytes.
    #
    def try_with_cache(obj, source, consume_all)
      # Skip caching entirely for atoms that don't benefit from it
      unless obj.cached?
        return obj.try(source, self, consume_all)
      end

      beg = source.bytepos

      # Use Hash#fetch for single hash operation instead of lookup + set
      entry = @cache[beg].fetch(obj.object_id) do
        result = obj.try(source, self, consume_all)
        # Cache the result with the advance amount
        @cache[beg][obj.object_id] = [result, source.bytepos - beg]
        return result
      end

      # Cache hit: entry is [result, advance]
      result, advance = entry

      # The data we're skipping here has been read before. (since it is in
      # the cache) PLUS the actual contents are not interesting anymore since
      # we know obj matches at beg. So skip reading.
      source.bytepos = beg + advance
      return result
    end

    # Pre-allocated constants to avoid repeated array allocations
    # These are the most common return values during parsing
    SUCCESS_NIL = [true, nil].freeze
    ERROR_NIL = [false, nil].freeze

    # Report an error at a given position.
    # @see ErrorReporter
    #
    def err_at(*args)
      return [false, @reporter.err_at(*args)] if @reporter
      ERROR_NIL
    end

    # Report an error.
    # @see ErrorReporter
    #
    def err(*args)
      return [false, @reporter.err(*args)] if @reporter
      ERROR_NIL
    end

    # Report a successful parse.
    # @see ErrorReporter::Contextual
    #
    def succ(*args)
      # The default error reporter (Tree) has an empty succ method that returns nil
      # So for the common case (no reporter or default reporter), use pre-allocated constant
      return SUCCESS_NIL unless @reporter
      result = @reporter.succ(*args)
      return SUCCESS_NIL if result.nil?
      [true, result]
    end

    # Returns the current captures made on the input (see
    # Parslet::Atoms::Base#capture). Use as follows:
    #
    #   context.captures[:foobar] # => returns capture :foobar
    #
    attr_reader :captures

    # Starts a new scope. Use the #scope method of Parslet::Atoms::DSL
    # to call this.
    #
    def scope
      captures.push
      yield
    ensure
      captures.pop
    end

  private
    # NOTE These methods use #object_id directly, since that seems to bring the
    # most performance benefit. This is a hot spot; going through
    # Atoms::Base#hash doesn't yield as much.
    #
    def lookup(obj, pos)
      @cache[pos][obj.object_id]
    end
    def set(obj, pos, val)
      @cache[pos][obj.object_id] = val
    end
  end
end
