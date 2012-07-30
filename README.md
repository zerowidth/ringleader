```plain
       _____
      (, /   ) ,          /)          /)
        /__ /   __   _   //  _  _   _(/  _  __
     ) /   \__(_/ (_(_/_(/__(/_(_(_(_(__(/_/ (_
    (_/            .-/
                  (_/
```

Ringleader is an application proxy for socket applications.

## Is it any good?

[Yes](http://news.ycombinator.com/item?id=3067434).

## What's it for?

I designed this for a large suite of apps running behind nginx with a somewhat
complex routing configuration in nginx. Additionally, many of the apps required
active [resque](https://github.com/defunkt/resque/) pollers to run properly.
Ultimately this meant having many terminal windows open just to make a few
requests to the apps. Instead, I wanted something to manage all that for me:

                                                        +-------+
                                                     +->| app 1 |
                                                     |  +-------+
                  +-----------+    +--------------+  |
      http        |           |    |              |  |  +-------+
    requests ---> |   nginx   +--->|  ringleader  +--+->| app 2 |
                  |           |    |              |  |  +-------+
                  +-----------+    +--------------+  |
                                                     |  +-------+
                                                     +->| app n |
                                                        +-------+

Ringleader is essentially a generalized replacement for [pow](http://pow.cx/),
and allows on-demand startup and proxying for any TCP server programs. It can
start a foreman or ruby or any other process which opens a socket. For example,
I started resque pollers alongside applications using foreman.

## Installation

    $ gem install ringleader
    $ ringleader --help

## Configuration

Ringleader requires a yml configuration file to start. It should look something
like this:

```yml
---
# name of app (used in logging)
main_app:
  # working directory, where to start the app from
  dir: "~/apps/main"
  # the command to run to start up the app server. Executed under "bash -c".
  command: "foreman start"
  # the host to listen on, defaults to 127.0.0.1
  host: 0.0.0.0
  # the port ringleader listens on
  server_port: 3000
  # the port the application listens on
  app_port: 4000
  # idle timeout in seconds
  idle_timeout: 6000
  # application startup timeout
  startup_timeout: 180
  # set the app to be disabled when ringleader starts
  disabled: true
other_app:
  [...]
```

## License

MIT, see `LICENSE`.

Top hat icon by [Luka Taylor](http://lukataylo.deviantart.com/gallery/#/d2g95fp)
under a Creative Commons Attribution/Non-commercial license.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
