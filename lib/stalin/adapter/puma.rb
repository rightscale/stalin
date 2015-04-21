module Stalin::Adapter
  # A Stalin adapter that is suitable for use in Puma worker processes. Puma has two
  # execution models.
  # - "Cluster" spawns N worker processes; each responds to SIGTERM with graceful shutdown and SIGQUIT with abrupt shutdown
  # - "Single" runs a server in the one-and-only master process; it responds to SIGUSR2 with graceflu restart
  class Puma < Rack
    # Create a middleware instance.
    #
    # @param [#call] app inner Rack application
    # @param [Integer] min lower-bound worker memory consumption before restart
    # @param [Integer] max upper-bound worker memory consumption before restart
    # @param [Integer] cycle how frequently to check memory consumption (# requests)
    # @param [Boolean] verbose log extra information
    def initialize(app, min=1024**3, max=2*1024**3, cycle=16, verbose=false)
      # Puma has no singletons, so we need to grab a reference to its CLI object.
      # The CLI will not exist if puma was invoked through rackup.
      #
      # Since the master forks its workers, the CLI object also exists in workers.
      # By the time this code runs, we'll always be in a worker.
      cli = nil
      ObjectSpace.each_object(::Puma::CLI) { |o| cli = o } if defined?(::Puma::CLI)

      if cli && cli.clustered? && cli.options[:workers] > 0
        # Multiprocess model: send ourselves SIGTERM
        super(app, :TERM, :QUIT, min, max, cycle, verbose)
      else
        # Single-process model ("rackup," or "puma -w 0")
        super(app, :USR2, :USR1, min, max, cycle, verbose)
      end
    end
  end
end
