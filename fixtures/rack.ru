require 'sinatra'

# Integration-test driver for generic Rack middleware. Leaks like a sieve so that Stalin will
# kill workers very quickly.

base = File.expand_path('../..', __FILE__)
if File.exist? File.join(base, 'stalin.gemspec')
  $: << File.join(base, 'lib')
end

require 'stalin'

min   = Stalin::Watcher.new(Process.pid).watch
max   = Integer(min * 1.10)
delta = (max - min) # guaranteed to hit max after the first request

leak = ''

get '/' do
  leak << ('L' * delta)
  'Leaked %d bytes; total is now %d bytes' % [delta, leak.length]
end

use Stalin::Adapter::Rack

run Sinatra::Application
