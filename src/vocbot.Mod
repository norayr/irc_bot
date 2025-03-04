MODULE vocbot; (* noch 13.4.2017 / 18.5.2017*)

IMPORT IRC, opts, Out, Strings := ooc2Strings, ethStrings, StringList, oocIntStr, strUtils, Files, Platform;

CONST
  delay = 2000; (*delay between sending the history messages to the user.*)
  defListLength = 200;
VAR
  stringList: StringList.TStringList; (* buffer to store lines *)
  inst: IRC.instance;
  strListLen: LONGINT;
  cmdHelp, cmdLast, cmdSearch: ARRAY 16 OF CHAR;

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

PROCEDURE MIN(i, j: LONGINT): LONGINT;
BEGIN
  IF i<=j THEN RETURN i ELSE RETURN j END
END MIN;

PROCEDURE processPrivateMessage(VAR inst: IRC.instance; VAR msg, user: ARRAY OF CHAR);
VAR
  tmp, tmp2, tmpLow, tmp2Low, num: ARRAY 16 OF CHAR;
  tlk: ARRAY 256 OF CHAR;
  i: INTEGER;
  j: LONGINT;
  res: SHORTINT;
  pstr: strUtils.pstring;
  (* Variables for search command *)
  restMsg, pattern, countStr, actualStr, msgTxt: ARRAY IRC.msgLen OF CHAR;
  searchCount, actualCount: LONGINT;
  collectedMatches: StringList.TStringList;
  e: StringList.Node;
  msgStr: ARRAY IRC.msgLen OF CHAR;
  found: BOOLEAN;
  pos: INTEGER;
  cmdHelpLength, cmdLastLength, cmdSearchLength: INTEGER;
BEGIN
  cmdHelpLength := Strings.Length(cmdHelp);
  cmdLastLength := Strings.Length(cmdLast);
  cmdSearchLength := Strings.Length(cmdSearch);
  Strings.Extract(msg, 0, cmdHelpLength, tmp);
  Strings.Extract(msg, 0, cmdSearchLength, tmp2);
  ethStrings.Lower(tmp, tmpLow);
  ethStrings.Lower(tmp2, tmp2Low);
  IF (tmpLow = cmdHelp) THEN
     tlk := "i'm a humble irc bot written in oberon. https://github.com/norayr/irc_bot/";
     IRC.sendMsgToDst(inst, user, tlk);
     Platform.Delay(delay);
     tlk := "Type 'last n' to get last n messages I remember. Type 'search [n] pattern' to search the last messages for a pattern. I do remember not more, than last ";
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
  ELSIF (tmpLow = cmdLast) THEN
     i := strUtils.WordCount(msg, ' ');
     IF i = 2 THEN
       pstr := strUtils.ExtractWord(2, msg, ' ');
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
  ELSIF (tmp2Low = cmdSearch) THEN (* 'search' is 6 letters, tmp is first 6 chars *)
     Strings.Extract(msg, cmdSearchLength, SHORT(LEN(msg)) - cmdSearchLength, restMsg);
     strUtils.RemoveLeftChars(restMsg, ' ');
     IF restMsg[0] = 0X THEN
        IRC.sendMsgToDst(inst, user, "Please provide a search pattern.");
        RETURN;
     END;
     (* Check if first word is a number *)
     pstr := strUtils.ExtractWord(1, restMsg, ' ');
     oocIntStr.StrToInt(pstr^, searchCount, res);
     IF res = 0 THEN
        (* Valid count, extract pattern *)
        Strings.FindNext(pstr^, restMsg, 0, found, pos);
        IF found THEN
           pos := pos + Strings.Length(pstr^);
           Strings.Extract(restMsg, pos, LEN(restMsg) - pos, pattern);
           strUtils.RemoveLeftChars(pattern, ' ');
        ELSE
           pattern[0] := 0X;
        END;
        IF pattern[0] = 0X THEN
           IRC.sendMsgToDst(inst, user, "Please provide a search pattern.");
           RETURN;
        END;
     ELSE
        (* Invalid count, use default *)
        searchCount := 10;
        COPY(restMsg, pattern);
        strUtils.RemoveLeftChars(pattern, ' ');
        IF pattern[0] = 0X THEN
           IRC.sendMsgToDst(inst, user, "Please provide a search pattern.");
           RETURN;
        END;
     END;
     (* Collect matches *)
     collectedMatches := StringList.Create();
     FOR i := 0 TO SHORT(stringList.Count) - 1 DO
        e := stringList.Get(stringList, i);
        COPY(e.obj(StringList.TString).str^, msgStr);
        IF strUtils.contains1(msgStr, pattern) THEN
           collectedMatches.AppendString(collectedMatches, msgStr);
        END;
     END;
     (* Process and send results *)
     IF collectedMatches.Count > 0 THEN
        actualCount := searchCount;
        IF actualCount <= 0 THEN
           actualCount := 10;
        END;
        actualCount := MIN(actualCount, collectedMatches.Count);
        (* Prepare summary message *)
        COPY("Found ", msgTxt);
        oocIntStr.IntToStr(collectedMatches.Count, num);
        Strings.Append(num, msgTxt);
        Strings.Append(" matches. Showing last ", msgTxt);
        oocIntStr.IntToStr(actualCount, actualStr);
        Strings.Append(actualStr, msgTxt);
        Strings.Append(":", msgTxt);
        IRC.sendMsgToDst(inst, user, msgTxt);
        Platform.Delay(delay);
        (* Send the matches *)
        listToUser(inst, collectedMatches, user, actualCount);
     ELSE
        IRC.sendMsgToDst(inst, user, "No matches found.");
     END;
     (* Free collectedMatches *)
     collectedMatches.Free(collectedMatches);
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
        strUtils.getTillEOL(msg, j+Strings.Length(IRC.msgACTION), str0);
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
  COPY(user, tmp);
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

PROCEDURE processOptions(VAR owner, user, nick, host, port, pass, room: ARRAY OF CHAR; VAR listLength: LONGINT);
VAR
  options: opts.Options;
 foptions: opts.Options;
      opt, fopt: opts.Option;
      lstLen: ARRAY 5 OF CHAR;
      res: oocIntStr.ConvResults;
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

  opt := opts.createOpt();
  opts.setOptName(opt, "-l");
  opts.setOptLName(opt, "--listlength");
  opts.setOptHasVal(opt, TRUE);
  opts.setOptRequired(opt, FALSE);
  opts.setOptDesc(opt, "how many lines to remember");
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
  opts.valOfOpt("-l", foptions, lstLen);
  oocIntStr.StrToInt(lstLen, listLength, res);
  IF res # oocIntStr.strAllRight THEN listLength := defListLength END;
END processOptions;

PROCEDURE entrance;
VAR
  channels : IRC.Channels;
  b: BOOLEAN;
  owner, user, nick, host, port, pass, room: ARRAY 32 OF CHAR;
BEGIN
    processOptions(owner, user, nick, host, port, pass, room, strListLen);
  Out.String("owner: "); Out.String(owner); Out.Ln;
  Out.String("user: "); Out.String(user); Out.Ln;
  Out.String("nick: "); Out.String(nick); Out.Ln;
  Out.String("host: "); Out.String(host); Out.Ln;
  Out.String("port: "); Out.String(port); Out.Ln;
  Out.String("room: "); Out.String(room); Out.Ln;
  Out.String("history length: "); Out.Int(strListLen, 0); Out.Ln;
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
  COPY("help", cmdHelp); COPY("last", cmdLast); COPY("search", cmdSearch);
  Platform.SetInterruptHandler(interrupt);
  entrance
END vocbot.
