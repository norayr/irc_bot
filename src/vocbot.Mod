MODULE vocbot; (* noch 13.4.2017 / 18.5.2017*)

IMPORT IRC, opts, Out, Strings := ooc2Strings, StringList, oocIntStr, strutils, Files, Platform;

CONST
  strListLen = 100;
  delay = 2000; (*delay between sending the history messages to the user.*)
VAR
  stringList: StringList.TStringList; (* buffer to store lines *)
  inst: IRC.instance;

PROCEDURE interrupt(i: LONGINT);
BEGIN
 (* here we need to flush files to disk before exiting. and probably close the irc connection *)
   Out.String("interrupt caught."); Out.Ln;
   IRC.finalize(inst);
   HALT(0);
END interrupt;

(* for debug *)
PROCEDURE list(VAR s : StringList.TStringList);
VAR e : StringList.Node;
       i : INTEGER;
    L : StringList.TList;
BEGIN
   NEW(e);
   i := 0;
   NEW(L);
   L := s;
   REPEAT
      e := s.Get(L, i);
      IF e # NIL THEN Out.String (e.obj(StringList.TString).str^); Out.Ln END;
      (*Out.String (e.string); Out.Ln;*)
      INC(i);
   UNTIL i = s.Count;
END list;

(* sends list of messages to the requestor *)
PROCEDURE listToUser(VAR inst: IRC.instance; VAR s : StringList.TStringList; user: ARRAY OF CHAR; num: LONGINT);
VAR e : StringList.Node;
       i : INTEGER;
    L : StringList.TList;
    k : LONGINT;
BEGIN
   NEW(e);
   i := 0;
   NEW(L);
   L := s;
   k := s.Count - num;
   REPEAT
      e := s.Get(L, i);
      IF e # NIL THEN
        IF i >= k THEN
          Platform.Delay(delay); (* to prevent being killed for flood *)
          Out.String (e.obj(StringList.TString).str^); Out.Ln;
          IRC.sendMsgToDst(inst, user, e.obj(StringList.TString).str^);
        END;
      END;
      INC(i);
   UNTIL (i = s.Count);
END listToUser;


(*
PROCEDURE onMessage(VAR msg : ARRAY OF CHAR);
BEGIN
   Out.String("callback procedure is running, youhoo!"); Out.Ln;
   Out.String("input:"); Out.Ln;
   Out.String(msg); Out.String("|"); Out.Ln;
   Out.Ln;
END onMessage;
*)

PROCEDURE processPrivateMessage(VAR inst: IRC.instance; VAR msg, user: ARRAY OF CHAR);
VAR
  tmp, num: ARRAY 16 OF CHAR;
  tlk: ARRAY 128 OF CHAR;
  i: INTEGER;
  j: LONGINT;
  res: SHORTINT;
  pstr: strutils.pstring;
BEGIN
  Strings.Extract(msg, 0, 4, tmp);
  IF (tmp = "help") THEN
     tlk := "i'm a humble irc bot written in oberon. https://github.com/norayr/irc_bot/";
     IRC.sendMsgToDst(inst, user, tlk);
     Platform.Delay(delay);
     tlk := "Type 'last n' to get last n messages I remember. I do remember not more, than last ";
     oocIntStr.IntToStr(strListLen, num);
     Strings.Append(num, tlk);
     Strings.Append(" messages.", tlk);
     IRC.sendMsgToDst(inst, user, tlk);
     Platform.Delay(delay);
     tlk := "Currently I remember ";
     oocIntStr.IntToStr(stringList.Count, num);
     Strings.Append(num, tlk);
     Strings.Append(" lines.", tlk);
     IRC.sendMsgToDst(inst, user, tlk);
  ELSIF (tmp = "last") THEN
     i := strutils.WordCount(msg, ' ');
     IF i = 2 THEN
       pstr := strutils.ExtractWord(2, msg, ' ');
       oocIntStr.StrToInt(pstr^, j, res);
       IF res = 0 THEN
         IF j <= strListLen THEN
           IF (j > stringList.Count) & (stringList.Count < strListLen) THEN
             tlk:= "as i was started recently i only remember ";
             oocIntStr.IntToStr(stringList.Count, num);
             Strings.Append(num, tlk);
             Strings.Append(" lines.", tlk);
             IRC.sendMsgToDst(inst, user, tlk);
           END;
             listToUser(inst, stringList, user, j);
         ELSE
           tlk := "I do remember only last ";
           oocIntStr.IntToStr(strListLen, num);
           Strings.Append(num, tlk);
           Strings.Append(" messages.", tlk);
           IRC.sendMsgToDst(inst, user, tlk);
           listToUser(inst, stringList, user, strListLen);
         END;
       ELSE
         tlk := "number expected, but got '";
         Strings.Append(pstr^, tlk);
         Strings.Append("', please try again.", tlk);
         IRC.sendMsgToDst(inst, user, tlk);
       END;
     ELSE
       IRC.sendMsgToDst(inst, user, "wrong format of 'last' command.");
     END;
  ELSE
     IRC.sendMsgToDst(inst, user, "I am not a sophisticated bot.  Type 'help' for help.");
  END;
END processPrivateMessage;

PROCEDURE onPrivateMessage(VAR inst: IRC.instance; VAR msg, msgtype, user, ident, host: ARRAY OF CHAR);
BEGIN
  Out.String("*** private message ***"); Out.Ln;
  Out.String("message: '"); Out.String(msg); Out.Char("'"); Out.Ln;
  Out.String("message type: '"); Out.String(msgtype); Out.Char("'"); Out.Ln;
  Out.String("user: '"); Out.String(user); Out.Char("'"); Out.Ln;
  Out.String("ident: '"); Out.String(ident); Out.Char("'"); Out.Ln;
  Out.String("host: '"); Out.String(host); Out.Char("'"); Out.Ln;
  Out.String("*** that's it ***"); Out.Ln;
  (*IRC.sendMsgToDst(inst, user, "hello, nice to meet you");*)
  processPrivateMessage(inst, msg, user);
END onPrivateMessage;

PROCEDURE onPublicMessage(VAR inst: IRC.instance; VAR msg, msgtype, user, ident, rcpt, host: ARRAY OF CHAR);
VAR
  tmpstr: ARRAY IRC.msgLen OF CHAR;
  (* for handling ACTION messages *)
  b0: BOOLEAN;
  j: INTEGER;
  str0: ARRAY IRC.msgLen OF CHAR;
BEGIN
  Out.String("*** public message ***"); Out.Ln;
  Out.String("message: '"); Out.String(msg); Out.Char("'"); Out.Ln;
  Out.String("message type: '"); Out.String(msgtype); Out.Char("'"); Out.Ln;
  Out.String("user: '"); Out.String(user); Out.Char("'"); Out.Ln;
  Out.String("ident: '"); Out.String(ident); Out.Char("'"); Out.Ln;
  Out.String("recipient: '"); Out.String(rcpt); Out.Char("'"); Out.Ln;
  Out.String("host: '"); Out.String(host); Out.Char("'"); Out.Ln;
  Out.String("*** that's it ***"); Out.Ln;
  (*IF msgtype # IRC.msgJOIN THEN IRC.sendMsgToDst(inst, rcpt, "test back") END;*)
  IF msgtype = IRC.msgPRIVMSG THEN
     COPY("", tmpstr);
     b0 := FALSE;
     Strings.FindNext(IRC.msgACTION, msg, 1, b0, j);
     IF b0 THEN (* handle actions *)
        Strings.Append("***", tmpstr);
        Strings.Append(user, tmpstr);
        Strings.Append(" ", tmpstr);
        strutils.getTillEOL(msg, j+Strings.Length(IRC.msgACTION), str0);
        Strings.Append(str0, tmpstr);
     ELSE
        COPY(user, tmpstr);
        Strings.Append(": ", tmpstr);
        Strings.Append(msg, tmpstr);
     END;
     IF stringList.Count < strListLen THEN
       stringList.AppendString(stringList, tmpstr)
     ELSE
       stringList.Delete(stringList, 0);
       stringList.AppendString(stringList, tmpstr)
     END;
     Out.String("now list looks like:"); Out.Ln;
     list(stringList);
  END;
END onPublicMessage;

PROCEDURE onPublicMessageWithMention(VAR inst: IRC.instance; VAR msg, msgtype, user, ident, rcpt, host: ARRAY OF CHAR);
VAR
  tmp: ARRAY IRC.msgLen OF CHAR;
  tmpstr: ARRAY IRC.msgLen OF CHAR;
BEGIN
  Out.String("*** public message, bot name mentioned ***"); Out.Ln;
  Out.String("message: '"); Out.String(msg); Out.Char("'"); Out.Ln;
  Out.String("message type: '"); Out.String(msgtype); Out.Char("'"); Out.Ln;
  Out.String("user: '"); Out.String(user); Out.Char("'"); Out.Ln;
  Out.String("ident: '"); Out.String(ident); Out.Char("'"); Out.Ln;
  Out.String("recipient: '"); Out.String(rcpt); Out.Char("'"); Out.Ln;
  Out.String("host: '"); Out.String(host); Out.Char("'"); Out.Ln;
  Out.String("*** that's it ***"); Out.Ln;
  tmp := user;
  Strings.Append(": let's talk in private in order to not flood the channel. type 'help' for help.", tmp);
  IRC.sendMsgToDst(inst, user, tmp);
  (* log this *)
  IF msgtype = IRC.msgPRIVMSG THEN
      COPY(user, tmpstr);
      Strings.Append(": ", tmpstr);
      Strings.Append(inst.nick, tmpstr);
      Strings.Append(": ", tmpstr);
      Strings.Append(msg, tmpstr);
     IF stringList.Count < strListLen THEN
       stringList.AppendString(stringList, tmpstr)
     ELSE
       stringList.Delete(stringList, 0);
       stringList.AppendString(stringList, tmpstr)
     END;
     Out.String("now list looks like:"); Out.Ln;
     list(stringList)
  END
END onPublicMessageWithMention;

PROCEDURE readLine(VAR r : Files.Rider; VAR s: ARRAY OF CHAR);
VAR
  i : INTEGER;
  b : SHORTINT;
BEGIN
  i := 0;
  REPEAT
    Files.Read(r, b);
    (*IF b >= 32 THEN*)
      IF b = 10 THEN
        s[i] := 0X
      ELSE
        s[i] := CHR(b)
      END;
    (*END;*)
      INC(i)
  UNTIL (b = 10(*0AX*)) OR r.eof;
END readLine;

PROCEDURE log2strings(VAR filename: ARRAY OF CHAR; VAR strs: StringList.TStringList);
VAR
  f : Files.File;
  r : Files.Rider;
  tmpstr: ARRAY IRC.msgLen OF CHAR;
  s, t: ARRAY IRC.msgLen OF CHAR;
  pos: INTEGER;
  b : BOOLEAN;
BEGIN
  f := Files.Old(filename);
  IF f # NIL THEN
    Files.Set(r, f, 0);
    REPEAT
      readLine(r, s);
      COPY("joined ", t);
      Strings.Append(filename, t);
      Strings.FindNext(t, s, 0, b, pos);
      IF ~b THEN
        Strings.FindNext(") ", s, 0, b, pos);
        IF b THEN
          Strings.Extract(s, pos+2, Strings.Length(s) - pos+2, tmpstr);
          IF stringList.Count < strListLen THEN
            stringList.AppendString(stringList, tmpstr)
          ELSE
            stringList.Delete(stringList, 0);
            stringList.AppendString(stringList, tmpstr)
          END;
          Out.String("now list looks like:"); Out.Ln;
          list(stringList)
        END
      END
    UNTIL r.eof (*Files.Pos(r) >= Files.Length(f) - 1)*);
  END
END log2strings;

PROCEDURE processOptions(VAR owner, user, nick, host, port, pass, room: ARRAY OF CHAR);
VAR
  options: opts.Options;
 foptions: opts.Options;
      opt, fopt: opts.Option;
BEGIN
  options := opts.createOptions();
  foptions := opts.createOptions();
  opt := opts.createOpt();
  opts.setOptName(opt, "-h");
  opts.setOptLName(opt, "--host");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptDesc(opt, "IRC host name");
  opts.setOptRequired(opt, TRUE);
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-p");
  opts.setOptLName(opt, "--port");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, TRUE);
  opts.setOptDesc(opt, "server port");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-o");
  opts.setOptLName(opt, "--owner");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, TRUE);
  opts.setOptDesc(opt, "account owner");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-u");
  opts.setOptLName(opt, "--user");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, TRUE);
  opts.setOptDesc(opt, "account username");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-n");
  opts.setOptLName(opt, "--nick");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, TRUE);
  opts.setOptDesc(opt, "nick to use");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-r");
  opts.setOptLName(opt, "--room");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, TRUE);
  opts.setOptDesc(opt, "room to join");
  options.add(options, opt);

  opt := opts.createOpt();
  opts.setOptName(opt, "-w");
  opts.setOptLName(opt, "--password");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, FALSE);
  opts.setOptDesc(opt, "password");
  options.add(options, opt);

  foptions := opts.populateOptions(options);
  IF opts.reqsSatisfied(options, foptions) THEN
    Out.String("required options provided"); Out.Ln;
  ELSE
    Out.String("required options not provided"); Out.Ln;
    opts.showHelp(options);
    HALT(3);
  END;
  Out.Ln;
  
  opts.valOfOpt("-o", foptions, owner);
  opts.valOfOpt("-u", foptions, user);
  opts.valOfOpt("-n", foptions, nick);
  opts.valOfOpt("-h", foptions, host);
  opts.valOfOpt("-p", foptions, port);
  opts.valOfOpt("-r", foptions, room);
  opts.valOfOpt("-w", foptions, pass);
END processOptions;

PROCEDURE entrance;
VAR
  channels : IRC.Channels;
  b: BOOLEAN;
  owner, user, nick, host, port, pass, room: ARRAY 32 OF CHAR;
BEGIN
  processOptions(owner, user, nick, host, port, pass, room);
  Out.String("owner: "); Out.String(owner); Out.Ln;
  Out.String("user: "); Out.String(user); Out.Ln;
  Out.String("nick: "); Out.String(nick); Out.Ln;
  Out.String("host: "); Out.String(host); Out.Ln;
  Out.String("port: "); Out.String(port); Out.Ln;
  Out.String("room: "); Out.String(room); Out.Ln;
  IF pass = "" THEN Out.String("password not set") ELSE Out.String("password provided, will try to authenticate") END; Out.Ln;
  inst := IRC.Create(owner, user, nick, host, port, pass, TRUE, onPrivateMessage, onPublicMessage, onPublicMessageWithMention);
  (*inst := IRC.Create("inky", "mobot", "mobot_", "irc.libera.chat", "6667", "", TRUE, onPrivateMessage, onPublicMessage, onPublicMessageWithMention);*)

  NEW(channels, 1);
  channels[0].channel := room;
  IRC.setLogging(inst, TRUE);
  IRC.initChannelList(inst, channels);

  (* vocbot specific functionality, buffer to store last n messages *)
  stringList  := StringList.Create();
  log2strings(channels[0].channel, stringList);

  IF IRC.Connect(inst) # FALSE THEN
    b := IRC.Auth(inst);
    IRC.Loop(inst);
  END;

END entrance;

BEGIN
  Platform.SetInterruptHandler(interrupt);
  entrance
END vocbot.
