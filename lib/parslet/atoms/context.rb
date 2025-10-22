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
      @max_position = 0  # Track furthest position for cache eviction
      @eviction_threshold = 200  # Evict positions more than 200 bytes behind

      # Selective memoization: track hit/miss rates to only cache beneficial parslets
      @hit_counts = Hash.new(0)
      @miss_counts = Hash.new(0)
      @cache_threshold = 2  # Only cache if we've had 2+ hits
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
      cache_key = obj.object_id

      # Track furthest position and evict old cache entries
      # In left-to-right parsing, positions far behind won't be revisited
      if beg > @max_position
        @max_position = beg

        # Evict positions that are too far behind current position
        # This prevents unbounded cache growth (O(n*m) memory issue in packrat)
        # Evict every time we move forward to keep cache bounded
        min_keep_pos = beg - @eviction_threshold
        @cache.delete_if { |pos, _| pos < min_keep_pos }
      end

      # Check if this parslet/position combo is already cached
      if @cache[beg].key?(cache_key)
        # Cache hit - track it
        @hit_counts[cache_key] += 1
        result, advance = @cache[beg][cache_key]
        source.bytepos = beg + advance
        return result
      end

      # Cache miss - execute the parslet
      @miss_counts[cache_key] += 1
      result = obj.try(source, self, consume_all)
      advance = source.bytepos - beg

      # Only cache if this parslet has shown it benefits from caching
      # (has had multiple hits, or we're still learning about it)
      total_attempts = @hit_counts[cache_key] + @miss_counts[cache_key]
      if total_attempts <= @cache_threshold || @hit_counts[cache_key] > 0
        @cache[beg][cache_key] = [result, advance]
      end

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
