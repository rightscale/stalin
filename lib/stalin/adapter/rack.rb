module Stalin::Adapter
  # A low-tech but reliable solution that invokes stalin using Rack middleware.
  # This is suitable for application srvers that use a master-and-workers
  # process architecture, wohse workers respond to a graceful shutdown signal,
  # and whose masters spawn new workers as needed.
  #
  # This functions as a base class for server-specific middlewares, and can be used if
  # there is an app server that uses a signalling strategy not explicitly supported by Stalin.
  class Rack
    # Conversion constant for human-readable memory amounts in log messages.
    MB = Float(1024**2)

    # Construct a new middleware. If all six arguments are passed, construct an instance
    # of this class; otherwise, use a heuristic to construct an instance of a suitable
    # derived class.
    #
    # @raise [ArgumentError] if an incorrect number of arguments is passed
    # @raise [RuntimeError] if 0..5 arguments and the heuristic can't figure out which signals to use
    def self.new(*args)
      if self == Rack && args.length < 3 
        # Warn that this shim will go away in v1
        warn "Stalin::Adapter::Rack.new with fewer than 3 arguments is deprecated; please instantiate a derived class e.g. Unicorn or Puma"

        # Use a heuristic to decide on the correct adapter and instantiate a derived class.
        if defined?(::Unicorn)
          middleware = Unicorn.allocate
        elsif defined?(::Puma)
          middleware = Puma.allocate
        else
          raise RuntimeError, "Cannot determine a suitable Stalin adapter; please instantiate this class with six arguments"
        end

        # Initialize our new object (ugh)
        middleware.instance_eval { initialize(*args) }
        middleware
      else
        super 
      end
    end

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
    def initialize(app, graceful, abrupt, min=1024**3, max=2*1024**3, cycle=16, verbose=false)
      @app      = app
      @graceful = graceful
      @abrupt   = abrupt
      @min      = min
      @max      = max
      @cycle    = cycle
      @verbose  = verbose
    end

    def call(env)
      result = @app.call(env)

      logger = logger_for(env)

      begin
        @lim     ||= @min + randomize(@max - @min + 1)
        @req     ||= 0
        @req     += 1

        if @req % @cycle == 0
          @req = 0
          @watcher ||= ::Stalin::Watcher.new(Process.pid)
          @killer  ||= ::Stalin::Killer.new(Process.pid, @graceful, @abrupt)
          if (used = @watcher.watch) > @lim
            sig = @killer.kill
            @watcher.watch
            logger.info "stalin (pid: %d) send SIG%s; memory usage %.1f MB > %.1f MB" %
                          [Process.pid, sig, used / MB, @lim / MB]
            @cycle = 2
          elsif @verbose
            logger.info "stalin (pid: %d) soldiers on; memory usage %.1f MB < %.1f MB" %
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
      RUBY_VERSION > "1.9" ? Random.rand(integer.abs) : rand(integer)
    end

    def logger_for(env)
      env['rack.logger'] || (@logger ||= Logger.new(STDERR))
    end
  end
end
