module Stalin::Adapter
  # Abstract base class for server-specific Rack middlewares.
  # there is an app server that uses a signalling strategy not explicitly supported by Stalin.
  class Rack
    # Conversion constant for human-readable memory amounts in log messages.
    MB = Float(1024**2)

    # Create a middleware instance.
    #
    # @param [#call] app inner Rack application
    # @param [Symbol] graceful name of graceful-shutdown signal
    # @param [Symbol] abrupt name of abrupt-shutdown signal
    # @param [Integer] min lower-bound worker memory consumption before restart
    # @param [Integer] max upper-bound worker memory consumption before restart
    # @param [Integer] cycle how frequently to check memory consumption (# requests)
    # @param [Boolean] verbose log extra information
    # @param [Array] signals pair of two Symbol signal-names: one for "graceful shutdown please" and one for "terminate immediately"
    def initialize(app, graceful, abrupt, min, max, cycle, verbose)
      @app      = app
      @graceful = graceful
      @abrupt   = abrupt
      @min      = min
      @max      = max
      @cycle    = cycle
      @verbose  = verbose
      @req      = 0
    end

    def call(env)
      result = @app.call(env)

      logger = logger_for(env)

      begin
        if @req == 0
          # First-time initialization. Deferred until first request so we can
          # ensure that init-time log output goes to the right place.
          @lim     = @min + randomize(@max - @min + 1)
          @req     = 0
          @watcher = ::Stalin::Watcher.new(Process.pid)
          @killer  = ::Stalin::Killer.new(Process.pid, @graceful, @abrupt)
          logger.info "stalin (pid: %d) startup; limit=%.1f MB, graceful=SIG%s (abrupt=SIG%s after %d tries)" %
                        [Process.pid, @lim / MB, @graceful, @abrupt, Stalin::Killer::MAX_GRACEFUL]
        end

        @req += 1

        if @req % @cycle == 0
          if (used = @watcher.watch) > @lim
            sig = @killer.kill
            logger.info "stalin (pid: %d) send SIG%s; %.1f MB > %.1f MB" %
                          [Process.pid, sig, used / MB, @lim / MB]
          elsif @verbose
            logger.info "stalin (pid: %d) soldiers on; %.1f MB < %.1f MB" %
                           [Process.pid, used / MB, @lim / MB]
          end
        end
      rescue Exception => e
        logger.error "stalin (pid: %d) ERROR %s: %s (%s)" %
                      [Process.pid, e.class.name, e.message, e.backtrace.first]
      end

      result
    end

    private

    def randomize(integer)
      Random.rand(integer.abs)
    end

    def logger_for(env)
      env['rack.logger'] || (@logger ||= Logger.new(STDERR))
    end
  end
end
