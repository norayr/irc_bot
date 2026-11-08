# IRC history bot

`vocbot` is an Oberon example application for the `IRC`, `IRCTCP` and `IRCTLS`
libraries. It logs channel messages and answers private requests for history:

- `help` — show the commands.
- `last n` — return recent messages.
- `search [n] pattern` — search remembered messages, showing ten by default.

The bot owns history, log files, channel joining and reply pacing. It calls
`IRC.Poll` in its application loop and sends one queued reply every two
seconds, continuing to answer PINGs while history is being delivered. Message
text is preserved; long replies are split at UTF-8 boundaries. The reply queue
is bounded to twice the history limit plus sixteen frames.

## Building

Install VOC's Linux model-2 networking profile with `Sockets`, `DNS`, the
utility/options/list modules, and the updated resumable `TLS13Live` API.
Then:

```sh
git clone https://github.com/norayr/irc_bot
cd irc_bot
make get_deps
make
make tests
```

The build uses `../irc` when present, otherwise `deps/irc`. Set
`IRC_DIR=/path/to/irc` to choose a checkout. `make get_deps` only fetches a
missing IRC checkout. `VOC` and `BUILD` are overridable. During development,
the IRC build can compile the updated `../tls/src/TLS13Live.Mod`; see the
IRC README for `TLS_SOURCE` and installed-library builds.

## Running

Verified TLS is the default transport:

```sh
build/vocbot -h irc.libera.chat -p 6697 -o owner -u vocbot \
  -n vocbot -r '#test' -l 200
```

To require SASL PLAIN, set the password in an environment variable and add
the account name:

```sh
export IRC_SASL_PASSWORD='your-account-password'
build/vocbot -h irc.libera.chat -p 6697 -o owner -u vocbot \
  -n vocbot -r '#test' -a account-name
```

`-s NAME` chooses another password environment variable. `-w password`
supplies the separate IRC server PASS credential. SASL requires verified
TLS; authentication failures stop the client. The CA bundle is selected by
the TLS library's default or `SSL_CERT_FILE`. The underlying TLS library's
security and platform limitations apply; see its documentation.

For a controlled plaintext server, explicitly use `-x plain` and its port.
`-l` sets the history limit, default 200. Logs are named after the channel
in the working directory, and are restored on startup. Continue using the
same directory to keep history. Ctrl-C stops reconnecting and flushes logs.

Network failures reconnect with capped backoff, re-register and rejoin the
channel. Nickname conflicts and failed joins are reported. KICKs are reported
without automatically fighting channel policy by repeatedly rejoining.

## Tests and runtime selection

`make tests` runs the IRC library's standalone suite and local fake-server
application tests, including history, search, paced replies, UTF-8, restarts
and reconnects. Python 3 and the OpenSSL command-line tool are test dependencies.
The production reconnect test takes about 23 seconds.

If the loader selects an older `/opt/voc` runtime instead of the matching
`/usr/lib64` installation, use `LD_LIBRARY_PATH=/usr/lib64` when building
tests and running the executable. Rebuild dependent modules when updating
the TLS state layout.

## License

Copyright (C) 2017–2026 Norayr Chilingarian. Licensed under GNU GPL version 3
only (`GPL-3.0-only`); see `LICENSE`. The IRC library is LGPL-3.0-only.
