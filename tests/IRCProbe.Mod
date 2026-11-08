MODULE IRCProbe;

IMPORT IRC, Args, Platform, Strings := oocStrings;

VAR inst: IRC.instance; channels: IRC.Channels; port, mode: IRC.chn; b: BOOLEAN;

PROCEDURE emit(VAR inst: IRC.instance; kind, message, command, user, ident, host: ARRAY OF CHAR);
VAR text: IRC.msg; destination: IRC.chn;
BEGIN
  COPY(kind, text); Strings.Append("|", text); Strings.Append(command, text);
  Strings.Append("|", text); Strings.Append(user, text);
  Strings.Append("|", text); Strings.Append(ident, text);
  Strings.Append("|", text); Strings.Append(host, text);
  Strings.Append("|", text); Strings.Append(message, text);
  destination := "#events"; IRC.sendMsgToDst(inst, destination, text)
END emit;

PROCEDURE private(VAR inst: IRC.instance; VAR message, command, user, ident, host: ARRAY OF CHAR);
BEGIN emit(inst, "private", message, command, user, ident, host) END private;

PROCEDURE public(VAR inst: IRC.instance; VAR message, command, user, ident, rcpt, host: ARRAY OF CHAR);
BEGIN emit(inst, rcpt, message, command, user, ident, host) END public;

PROCEDURE mention(VAR inst: IRC.instance; VAR message, command, user, ident, rcpt, host: ARRAY OF CHAR);
BEGIN emit(inst, "mention", message, command, user, ident, host) END mention;

PROCEDURE interrupt(i: LONGINT);
BEGIN IRC.finalize(inst); HALT(0) END interrupt;

BEGIN
  Args.Get(1, port); Args.Get(2, mode);
  inst := IRC.Create("owner", "testuser", "probe", "127.0.0.1", port,
    "secret-password", TRUE, private, public, mention);
  IRC.setTimeouts(inst, 400, 800, 200);
  NEW(channels, 2); channels[0].channel := "#one"; channels[1].channel := "#two";
  IRC.setLogging(inst, TRUE); IRC.initChannelList(inst, channels);
  Platform.SetInterruptHandler(interrupt);
  IF mode = "legacy" THEN b := IRC.Connect(inst); IF b THEN b := IRC.Auth(inst) END END;
  IRC.Loop(inst)
END IRCProbe.
