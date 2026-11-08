# IRC history bot

`vocbot` is an IRC bot written in Oberon. It logs channel activity and keeps
recent messages available through private commands:

- `help` — show the commands.
- `last n` — return up to the last `n` remembered messages.
- `search [n] pattern` — return recent matches, showing ten by default.

Replies are spaced two seconds apart while the bot continues receiving IRC
traffic. Mentioning the bot in a channel prompts a private reply.

## Building

Use a current [VOC](https://github.com/vishaps/voc) installation with its
`Internet`, `Sockets`, `opts`, `StringList`, `strUtils`, `strTypes`, `IntStr`
and `oocStrings` libraries. The separate [IRC module](https://github.com/norayr/irc)
provides the protocol implementation.

```sh
git clone https://github.com/norayr/irc_bot
cd irc_bot
make get_deps
make
```

The build uses `../irc` when that checkout exists, otherwise `deps/irc`.
To choose another checkout, use `make IRC_DIR=/path/to/irc`. `VOC` and `BUILD`
can also be overridden. Only the IRC module and bot are compiled locally;
the remaining modules come from VOC. `make get_deps` fetches a missing IRC
checkout; it leaves existing checkouts unchanged.

## Running

```sh
build/vocbot -h irc.libera.chat -p 6667 -o owner -u vocbot \
  -n vocbot -r '#test' -l 200
```

`-l` sets the history limit (default 200). `-w password` optionally supplies
the IRC server password. Channel logs are named after their channels in the
working directory. On startup, the bot restores recent history from its log.
Keep running it from the same directory to reuse that history.

The IRC loop retries failed connections every 23 seconds, registers again,
and rejoins the configured channels after the server's welcome reply. It
also sends a PING after four idle minutes and reconnects if no matching PONG
arrives within one minute. Registration has a one-minute deadline.

Press Ctrl-C to close the connection and flush the logs. Pending bot replies
are bounded to twice the history limit plus sixteen messages; additional
replies are dropped while that queue is full.

### Selecting the installed VOC runtime

When multiple VOC installations coexist, the dynamic loader must select the
runtime matching the compiler and installed modules. If it selects an older
`/opt/voc/lib/libvoc-O2.so` instead of the current `/usr/lib64` installation,
run with:

```sh
LD_LIBRARY_PATH=/usr/lib64 build/vocbot -h irc.libera.chat -p 6667 \
  -o owner -u vocbot -n vocbot -r '#test'
```

## Testing

```sh
make tests
```

Tests require Python 3 and use a local fake IRC server. They cover fragmented
and combined messages, PING/PONG, failed initial connections, disconnects,
timeouts, rejoining, history loading, search and paced replies. They take
about a minute, including the production reconnect delay. Use the same
`LD_LIBRARY_PATH` setting as above if needed.
