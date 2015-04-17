module Stalin::Adapter
  # A Stalin adapter that is suitable for use in Unicorn worker processes.
  class Unicorn < Rack
    # Create a middleware instance.
    #
    # @param [#call] app inner Rack application
    # @param [Integer] min lower-bound worker memory consumption before restart
    # @param [Integer] max upper-bound worker memory consumption before restart
    # @param [Integer] cycle how frequently to check memory consumption (# requests)
    # @param [Boolean] verbose log extra information
    def initialize(app, min=1024**3, max=2*1024**3, cycle=16, verbose=false)
      super(app, :QUIT, :TERM, min, max, cycle, verbose)
    end
  end
end
