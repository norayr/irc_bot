this is an IRC bot written in Oberon.

behavior
========
this bot can join the room(s), and log its activity.

its main purpose to remember channel history, and tell it to those who asks.

hopefully you can find `vocbot` at the `#oberon` channel on `irc.freenode.net` and can talk to it to understand how it works.

you are supposed talk to it privately.
if you don't talk to it privately, it'll open a private chat and suggest to chat there itself.

the most important command is `help` and bot will tell you how to use it.

in particular, you can ask for `last n` messages, if you want to know what was happening in the room recently.

keep in mind that all the messages are logged to the output log files in the directory you run it from.

the configuration should be done before compilation. sorry for that.
there is no separate config file now. more on that in the build section of this readme.

get the source
==============

```
git clone https://github.com/norayr/irc_bot
```
get submodules
```
cd irc_bot
git submodule update --init
```

build
=====

firstly, you need a compiler: [voc](https://github.com/vishaps/voc).
once you have it, and you have `voc` binary in your path, you can proceed.

configuration
============

no configuration, but you need to run it with commandline arguments.

see `test.sh` for an example.

there is a hardcoded configuration option, which may want to change

`strListLen = 100;`

this suggests how many lines bot will remember to tell later those who ask for the channel history.

once you changed the source `src/vocbot.Mod`, compile the project with `make`.

running
=======

see test.sh.
