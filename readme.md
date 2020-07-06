this is an IRC bot written in Oberon.

behavior
========
this bot can join the room(s), and log its activity.
you should talk to it privately, and ask for `last n` messages, if you want to know what was happening in the room recently.
however, all the messages are logged to the output log files, that are created in the directory, you run it from.
if you don't talk to it privately, it'll open a private chat and suggest to chat there itself.

the configuration should be done before compilation.
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

there is no configuration currently, so `src/vocbot.Mod` contains a line:

```
channels[0].channel := "#lazarus-ide";
```

change it to whichever channel you want to join.
also, make sure to change:

```
  inst.owner := "norayr_tanakian";
  inst.user := "norayr_tanakian";
  inst.nick := "vocbot";
  inst.host := "irc.freenode.net";
  inst.port := "6667";
```

you probably want to change `inst.owner`, `inst.user` and `inst.nick`.
you want to leave `inst.host` and `inst.port` if you connect to freenode.

the bot can connect to several rooms simultaneously.

you also may want to change ```strListLen = 100;``` in the beginning of the file.
this suggests how many lines bot will remember to tell later those who ask for the channel history.

once you changed the source `src/vocbot.Mod`, compile the project with `make`.

running
=======

just copy the binary wherever you want from `build/vocbot` and run.
