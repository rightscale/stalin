# stalin

Given Ruby's proclivity for heap fragmentation, Web application worker processes tend to exhaust
all available memory unless the server is restarted periodically. When all of the workers restart
at once, downtime or bad request throughput may result.

Stalin is a gem that gracefully kills your workers before they cause swapping, resulting in better
availability for your application. Its design goals are modularity and compatibility with a range
of platforms and app servers.

Metrics include:
  - Resident Set Size (RSS)

Data sources include:
  - Linux ProcFS
  - Generic ps

Supported app servers include:
  - Rainbows (via Rack middleware + SIGQUIT) 
  - Unicorn (via Rack middleware + SIGQUIT)
  - Puma (via Rack middleware + SIGTERM/SIGUSR2 depending on execution model)

Servers known NOT to work:
  - Thin (no supervisor process; need an adapter that execs or something)

As you can see, we are far short of our _goal_ to support many servers! More to come as needed;
let me know what you need!

# User's Guide

## Installation

Just include stalin in your Gemfile.

    gem 'stalin'

## Usage

Decide on which application server you will use. Add some lines to your `config.ru` to
install a suitable Stalin middleware.

Because different app servers have different signal-handling and restart semantics, we
must specialize Stalin's behavior; this is done with an abstract base class 
(Stalin::Adapter::Rack) plus one derived class per supported application server.
 
    # Gem that kills app processes when their heap becomes too fragmented.
    require 'stalin'

    mb = 1024**2
    
    # Use the Unicorn adapter to ensure we send Unicorn-friendly kill signals.
    # Each worker will shutdown at some point between 192MB and 256MB of memory usage.
    use Stalin::Adapter::Unicorn, (192*mb), (256*mb)

## Tuning

Consult the documentation for your adapter's `#initialize` to learn how to tune Stalin's behavior.

# Developer's Guide

This gem is a work in progress; the docs are okay, but test coverage is
nonexistent. Whenever you make changes, please do some smoke tests by yourself.

## Smoke Tests

The `fixtures` subdirectory contains rackup files for both supported application
servers; you can use these to test the three supported permutations.

When you run puma or rainbows, it will begin listening on a port of its
choosing; use curl or similar to send it Web requests and cause a large
memory leak with every request. Each worker process should shutdown after the
first request, because the leak is large and the hardcoded limit for puma is
very small.

Verify that stalin is restarting the app servers and that your requests all
respond with 200 and not 502, 503 or other funny errors.

### Unicorn

    bundle exec unicorn fixtures/unicorn.ru 
### Single-Process Puma

    bundle exec puma fixtures/puma.ru
    
### Multi-Process Puma

    bundle exec puma -w 1 fixtures/puma.ru

# Special Thanks

- [@kzk](http://github.com/kzk/) for the [unicorn-worker-killer] gem which this is derived from
