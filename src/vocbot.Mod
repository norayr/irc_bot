MODULE vocbot;

IMPORT IRC, opts, Out, Strings := oocStrings, StringList,
       IntStr, strUtils, strTypes, Files, Platform;

CONST
  delay = 2000; (* spacing between replies, in milliseconds *)
  defListLength = 200;

TYPE
  Reply = POINTER TO ReplyDesc;
  ReplyDesc = RECORD
    user: IRC.chn;
    text: ARRAY 512 OF CHAR;
    next: Reply
  END;

VAR
  history: StringList.TStringList;
  inst: IRC.instance;
  historyLength, replyCount, lastReply: LONGINT;
  firstReply, finalReply: Reply;
  haveReplied: BOOLEAN;

PROCEDURE interrupt(i: LONGINT);
BEGIN
  IRC.finalize(inst);
  HALT(0)
END interrupt;

PROCEDURE reply(user, text: ARRAY OF CHAR);
VAR item: Reply;
BEGIN
  IF replyCount >= 2 * historyLength + 16 THEN RETURN END;
  NEW(item); COPY(user, item.user); COPY(text, item.text); item.next := NIL;
  IF firstReply = NIL THEN firstReply := item ELSE finalReply.next := item END;
  finalReply := item;
  INC(replyCount)
END reply;

(* Called by the IRC loop so flood protection never blocks incoming PINGs. *)
PROCEDURE sendReply(VAR inst: IRC.instance);
VAR now, elapsed: LONGINT; item: Reply;
BEGIN
  IF firstReply = NIL THEN RETURN END;
  now := Platform.Time();
  IF now < lastReply THEN elapsed := (MAX(LONGINT) - lastReply) + now
  ELSE elapsed := now - lastReply
  END;
  IF haveReplied & (elapsed < delay) THEN RETURN END;
  item := firstReply;
  IRC.sendMsgToDst(inst, item.user, item.text);
  IF inst.connection < 0 THEN RETURN END;
  firstReply := item.next;
  IF firstReply = NIL THEN finalReply := NIL END;
  DEC(replyCount);
  lastReply := now; haveReplied := TRUE
END sendReply;

PROCEDURE remember(text: ARRAY OF CHAR);
BEGIN
  IF history.Count >= historyLength THEN history.Delete(history, 0) END;
  history.AppendString(history, text)
END remember;

PROCEDURE listToUser(list: StringList.TStringList; user: ARRAY OF CHAR; count: LONGINT);
VAR i: LONGINT; text: strTypes.pstring;
BEGIN
  IF count > list.Count THEN count := list.Count END;
  FOR i := list.Count - count TO list.Count - 1 DO
    text := list.GetString(list, i);
    reply(user, text^)
  END
END listToUser;

PROCEDURE processPrivateMessage(VAR message, user: ARRAY OF CHAR);
VAR
  command: ARRAY 16 OF CHAR;
  rest, pattern, text: IRC.msg;
  number: ARRAY 16 OF CHAR;
  word, line: strTypes.pstring;
  count, i: LONGINT;
  result: SHORTINT;
  matches: StringList.TStringList;
BEGIN
  strUtils.RemoveLeftChars(message, " ");
  word := strUtils.ExtractWord(1, message, " ");
  COPY(word^, command); Strings.Capitalize(command);
  IF command = "HELP" THEN
    reply(user, "i'm a humble irc bot written in oberon. https://github.com/norayr/irc_bot/");
    COPY("Type 'last n' for recent messages, or 'search [n] pattern' to search them. I remember up to ", text);
    IntStr.IntToStr(historyLength, number); Strings.Append(number, text); Strings.Append(" messages.", text);
    reply(user, text);
    COPY("Currently I remember ", text); IntStr.IntToStr(history.Count, number);
    Strings.Append(number, text); Strings.Append(" lines.", text); reply(user, text)
  ELSIF command = "LAST" THEN
    IF strUtils.WordCount(message, " ") # 2 THEN
      reply(user, "Use 'last n' with a positive message count."); RETURN
    END;
    word := strUtils.ExtractWord(2, message, " "); IntStr.StrToInt(word^, count, result);
    IF (result # 0) OR (count <= 0) THEN
      reply(user, "Use 'last n' with a positive message count."); RETURN
    END;
    IF count > historyLength THEN count := historyLength END;
    IF history.Count = 0 THEN reply(user, "I do not remember any messages yet.")
    ELSE listToUser(history, user, count)
    END
  ELSIF command = "SEARCH" THEN
    Strings.Extract(message, Strings.Length(command), Strings.Length(message), rest);
    strUtils.RemoveLeftChars(rest, " ");
    IF rest = "" THEN reply(user, "Please provide a search pattern."); RETURN END;
    word := strUtils.ExtractWord(1, rest, " "); IntStr.StrToInt(word^, count, result);
    IF result = 0 THEN
      Strings.Extract(rest, Strings.Length(word^), Strings.Length(rest), pattern);
      strUtils.RemoveLeftChars(pattern, " ")
    ELSE count := 10; COPY(rest, pattern)
    END;
    IF pattern = "" THEN reply(user, "Please provide a search pattern."); RETURN END;
    IF count <= 0 THEN count := 10 END;
    matches := StringList.Create();
    FOR i := 0 TO history.Count - 1 DO
      line := history.GetString(history, i);
      IF strUtils.contains1(line^, pattern) THEN matches.AppendString(matches, line^) END
    END;
    IF matches.Count = 0 THEN reply(user, "No matches found.")
    ELSE
      IF count > matches.Count THEN count := matches.Count END;
      COPY("Found ", text); IntStr.IntToStr(matches.Count, number); Strings.Append(number, text);
      Strings.Append(" matches. Showing last ", text); IntStr.IntToStr(count, number);
      Strings.Append(number, text); Strings.Append(":", text); reply(user, text);
      listToUser(matches, user, count)
    END;
    matches.Free(matches)
  ELSE reply(user, "Type 'help' for help.")
  END
END processPrivateMessage;

PROCEDURE onPrivateMessage(VAR inst: IRC.instance; VAR message, command, user, ident, host: ARRAY OF CHAR);
BEGIN
  IF command = IRC.msgPRIVMSG THEN processPrivateMessage(message, user) END
END onPrivateMessage;

PROCEDURE onPublicMessage(VAR inst: IRC.instance; VAR message, command, user, ident, rcpt, host: ARRAY OF CHAR);
VAR text, action: IRC.msg; found: BOOLEAN; pos, length: INTEGER;
BEGIN
  IF command # IRC.msgPRIVMSG THEN RETURN END;
  COPY(user, text); Strings.Append(": ", text);
  IF message[0] = IRC.ctcpChar THEN
    Strings.FindNext("ACTION ", message, 1, found, pos);
    IF found & (pos = 1) THEN
      length := Strings.Length(message);
      IF message[length - 1] = IRC.ctcpChar THEN DEC(length) END;
      Strings.Extract(message, 8, length - 8, action);
      COPY("***", text); Strings.Append(user, text); Strings.Append(" ", text);
      Strings.Append(action, text)
    ELSE Strings.Append(message, text)
    END
  ELSE Strings.Append(message, text)
  END;
  remember(text)
END onPublicMessage;

PROCEDURE onMention(VAR inst: IRC.instance; VAR message, command, user, ident, rcpt, host: ARRAY OF CHAR);
BEGIN
  onPublicMessage(inst, message, command, user, ident, rcpt, host);
  reply(user, "Let's talk in private to avoid flooding the channel. Type 'help' for help.")
END onMention;

PROCEDURE readLine(VAR rider: Files.Rider; VAR text: ARRAY OF CHAR);
VAR i: LONGINT; byte: SHORTINT;
BEGIN
  i := 0;
  LOOP
    Files.Read(rider, byte);
    IF rider.eof OR (byte = 10) THEN EXIT END;
    IF (byte # 13) & (i < LEN(text) - 1) THEN text[i] := CHR(byte); INC(i) END
  END;
  text[i] := 0X
END readLine;

PROCEDURE loadHistory(VAR filename: ARRAY OF CHAR);
VAR file: Files.File; rider: Files.Rider; text, line: IRC.msg; found: BOOLEAN; pos: INTEGER;
BEGIN
  file := Files.Old(filename);
  IF file = NIL THEN RETURN END;
  Files.Set(rider, file, 0);
  REPEAT
    readLine(rider, text);
    Strings.FindNext(") ", text, 0, found, pos);
    IF found THEN
      Strings.Extract(text, pos + 2, Strings.Length(text) - pos - 2, line);
      IF ~strUtils.contains1(line, " joined ") & ~strUtils.contains1(line, " left ") THEN remember(line) END
    END
  UNTIL rider.eof
END loadHistory;

PROCEDURE processOptions(VAR owner, user, nick, host, port, pass, room: ARRAY OF CHAR);
VAR options, filled: opts.Options; length: ARRAY 16 OF CHAR; result: SHORTINT;

  PROCEDURE add(short, long, description: ARRAY OF CHAR; required: BOOLEAN);
  VAR option: opts.Option;
  BEGIN
    option := opts.createOpt(); opts.setOptName(option, short); opts.setOptLName(option, long);
    opts.setOptHasVal(option, TRUE); opts.setOptDesc(option, description);
    opts.setOptRequired(option, required); options.add(options, option)
  END add;

BEGIN
  options := opts.createOptions();
  add("-h", "--host", "IRC host name", TRUE);
  add("-p", "--port", "server port", TRUE);
  add("-o", "--owner", "account owner", TRUE);
  add("-u", "--user", "account username", TRUE);
  add("-n", "--nick", "nick to use", TRUE);
  add("-r", "--room", "room to join", TRUE);
  add("-w", "--password", "server password", FALSE);
  add("-l", "--listlength", "how many lines to remember", FALSE);
  filled := opts.populateOptions(options);
  IF ~opts.reqsSatisfied(options, filled) THEN opts.showHelp(options); HALT(3) END;
  opts.valOfOpt("-o", filled, owner); opts.valOfOpt("-u", filled, user);
  opts.valOfOpt("-n", filled, nick); opts.valOfOpt("-h", filled, host);
  opts.valOfOpt("-p", filled, port); opts.valOfOpt("-r", filled, room);
  opts.valOfOpt("-w", filled, pass); opts.valOfOpt("-l", filled, length);
  IntStr.StrToInt(length, historyLength, result);
  IF (result # 0) OR (historyLength <= 0) OR (historyLength > MAX(INTEGER)) THEN
    historyLength := defListLength
  END
END processOptions;

PROCEDURE entrance;
VAR channels: IRC.Channels; owner, user, nick, host, port, pass, room: IRC.chn;
BEGIN
  processOptions(owner, user, nick, host, port, pass, room);
  history := StringList.Create();
  loadHistory(room);
  inst := IRC.Create(owner, user, nick, host, port, pass, pass # "",
    onPrivateMessage, onPublicMessage, onMention);
  inst.callbackIdle := sendReply;
  NEW(channels, 1); channels[0].channel := room;
  IRC.setLogging(inst, TRUE); IRC.initChannelList(inst, channels);
  Out.String("Remembering up to "); Out.Int(historyLength, 0); Out.String(" messages in "); Out.String(room); Out.Ln;
  IRC.Loop(inst)
END entrance;

BEGIN
  firstReply := NIL; finalReply := NIL; replyCount := 0; lastReply := 0; haveReplied := FALSE;
  Platform.SetInterruptHandler(interrupt);
  entrance
END vocbot.
