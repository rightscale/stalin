module Stalin
  # Kill a process by sending SIGQUIT several times, then SIGTERM, and finally SIGKILL.
  class Killer
    # Number of cumulative shutdown tries before we escalate to abrupt-shutdown
    MAX_GRACEFUL = 10
    # Number of cumulative shutdown tries before we escalate to untrappable SIGKILL
    MAX_ABRUPT = 15

    # @param [Integer] pid target process ID
    def initialize(pid, graceful, abrupt)
      @pid      = pid
      @graceful = graceful
      @abrupt   = abrupt
      @tries    = 0
    end

    # Try to kill the target process by sending it a shutdown signal.
    #
    # @return [Symbol] name of signal that we sent
    def kill
      case @tries
      when (0...MAX_GRACEFUL)
        sig = @graceful
      when (MAX_GRACEFUL...MAX_ABRUPT)
        sig = @abrupt
      else
        sig = :KILL
      end

      @tries += 1
      Process.kill(sig, @pid)
      sig
    end
  end
end
