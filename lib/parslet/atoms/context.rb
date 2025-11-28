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
    # @param interval_cache [Boolean] Use GPeg-style interval tree caching
    def initialize(reporter=Parslet::ErrorReporter::Tree.new, interval_cache: false)
      @cache = Hash.new { |h, k| h[k] = {} }
      @reporter = reporter
      @captures = Parslet::Scope.new
      @max_position = 0  # Track furthest position for cache eviction
      @eviction_threshold = 200  # Evict positions more than 200 bytes behind
      @eviction_counter = 0  # Counter for periodic eviction
      @eviction_frequency = 100  # Only evict every N position advances

      # Selective memoization: track hit/miss rates to only cache beneficial parslets
      @hit_counts = Hash.new(0)
      @miss_counts = Hash.new(0)
      @cache_threshold = 2  # Only cache if we've had 2+ hits

      # GPeg-style interval tree caching (optional)
      @use_interval_cache = interval_cache
      if @use_interval_cache
        require 'parslet/interval_tree'
        require 'parslet/edit_tracker'
        # Map parslet object_id to interval tree
        @interval_cache = Hash.new { |h, k| h[k] = Parslet::IntervalTree.new }
        # Track edits for lazy position shifts
        @edit_tracker = Parslet::EditTracker.new
      end

      # Cut operator support (Phase 46b)
      # Track the last cut position to enable aggressive cache eviction
      @last_cut_position = 0
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

      # Phase 55: Cache ivars to reduce lookup overhead in hot method
      use_interval_cache = @use_interval_cache
      cache = @cache
      hit_counts = @hit_counts
      miss_counts = @miss_counts
      cache_threshold = @cache_threshold

      # Use interval-based caching if enabled (GPeg-style)
      if use_interval_cache
        return try_with_interval_cache(obj, source, consume_all)
      end

      beg = source.bytepos
      cache_key = obj.object_id

      # Track furthest position and evict old cache entries PERIODICALLY
      # In left-to-right parsing, positions far behind won't be revisited
      if beg > @max_position
        @max_position = beg
        eviction_counter = @eviction_counter + 1
        @eviction_counter = eviction_counter

        # Evict positions that are too far behind current position
        # This prevents unbounded cache growth (O(n*m) memory issue in packrat)
        # Phase 42: Only evict periodically instead of on every position advance
        # This reduces delete_if calls from ~900K to ~9K (100x reduction)
        if eviction_counter >= @eviction_frequency
          @eviction_counter = 0
          min_keep_pos = beg - @eviction_threshold
          cache.delete_if { |pos, _| pos < min_keep_pos }
        end
      end

      # Check if this parslet/position combo is already cached
      if cache[beg].key?(cache_key)
        # Cache hit - track it
        hit_counts[cache_key] += 1
        result, advance = cache[beg][cache_key]
        source.bytepos = beg + advance
        return result
      end

      # Cache miss - execute the parslet
      miss_counts[cache_key] += 1
      result = obj.try(source, self, consume_all)
      advance = source.bytepos - beg

      # Only cache if this parslet has shown it benefits from caching
      # (has had multiple hits, or we're still learning about it)
      total_attempts = hit_counts[cache_key] + miss_counts[cache_key]
      if total_attempts <= cache_threshold || hit_counts[cache_key] > 0
        cache[beg][cache_key] = [result, advance]
      end

      return result
    end

    # GPeg-style interval-based caching
    # Caches results keyed by intervals [start, end) rather than single positions
    # This enables efficient invalidation of changed regions during incremental parsing
    def try_with_interval_cache(obj, source, consume_all)
      beg = source.bytepos
      cache_key = obj.object_id

      # Try to find exact match in interval tree
      tree = @interval_cache[cache_key]
      result_data = tree.query_exact(beg, beg)  # Start with point query

      if result_data
        # Exact match found - restore result
        @hit_counts[cache_key] += 1
        result, advance = result_data
        source.bytepos = beg + advance
        return result
      end

      # No exact match - execute the parslet
      @miss_counts[cache_key] += 1
      result = obj.try(source, self, consume_all)
      advance = source.bytepos - beg
      end_pos = beg + advance

      # Store in interval tree: [start, end) -> [result, advance]
      # Only cache if beneficial (selective memoization)
      total_attempts = @hit_counts[cache_key] + @miss_counts[cache_key]
      if total_attempts <= @cache_threshold || @hit_counts[cache_key] > 0
        tree.insert(beg, end_pos, [result, advance])
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

    # GPeg-style tree memoization support
    # Check if tree memoization is enabled
    def use_tree_memoization?
      @use_interval_cache
    end

    # Query tree memo cache for a given key and position
    # Returns [values, end_pos] if found, nil otherwise
    def query_tree_memo(cache_key, start_pos)
      return nil unless @use_interval_cache
      tree = @interval_cache[cache_key]
      # Query for any intervals that overlap with [start_pos, start_pos+1)
      # This will find intervals that start at start_pos
      overlapping = tree.query_overlapping(start_pos, start_pos + 1)
      # Find exact match where interval starts at start_pos
      result = overlapping.find { |interval, _data| interval[0] == start_pos }
      result ? result[1] : nil
    end

    # Store tree memo: cache array of values for repetition
    def store_tree_memo(cache_key, start_pos, values, end_pos)
      return unless @use_interval_cache
      tree = @interval_cache[cache_key]
      tree.insert(start_pos, end_pos, [values, end_pos])
    end

    # Cut operator support (Phase 46b)
    # Called when a cut operator succeeds. This enables aggressive cache eviction
    # by marking that we won't backtrack before this position.
    #
    # @param position [Integer] The position where the cut occurred
    def cut!(position)
      @last_cut_position = position

      # Aggressively evict all cache entries before the cut position
      # This is safe because we won't backtrack past the cut point
      # This is the key to achieving O(1) space complexity with cuts
      @cache.delete_if { |pos, _| pos < position }
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
