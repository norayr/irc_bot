MODULE vocbot; (* noch 13.4.2017 / 18.5.2017*)

IMPORT IRC, Out, Strings := ooc2Strings, Platform, StringList, oocIntStr, strutils, Files;

CONST
  strListLen = 100;
(* i am moving these to global section to make possible for interrupt handler to access instance *)

VAR
  inst: IRC.instance;
  channels : IRC.Channels;
  b: BOOLEAN;
  stringList: StringList.TStringList; (* buffer to store lines *)

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
PROCEDURE listToUser(VAR s : StringList.TStringList; user: ARRAY OF CHAR; num: LONGINT);
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
          Platform.Delay(1000); (* to prevent being killed for flood *)
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

PROCEDURE processPrivateMessage(VAR msg, user: ARRAY OF CHAR);
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
     Platform.Delay(1000);
     tlk := "Type 'last n' to get last n messages I remember. I do remember not more, than last ";
     oocIntStr.IntToStr(strListLen, num);
     Strings.Append(num, tlk);
     Strings.Append(" messages.", tlk);
     IRC.sendMsgToDst(inst, user, tlk);
     Platform.Delay(1000);
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
             listToUser(stringList, user, j);
         ELSE
           tlk := "I do remember only last ";
           oocIntStr.IntToStr(strListLen, num);
           Strings.Append(num, tlk);
           Strings.Append(" messages.", tlk);
           IRC.sendMsgToDst(inst, user, tlk);
           listToUser(stringList, user, strListLen);
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

PROCEDURE onPrivateMessage(VAR msg, msgtype, user, ident, host: ARRAY OF CHAR);
BEGIN
  Out.String("*** private message ***"); Out.Ln;
  Out.String("message: '"); Out.String(msg); Out.Char("'"); Out.Ln;
  Out.String("message type: '"); Out.String(msgtype); Out.Char("'"); Out.Ln;
  Out.String("user: '"); Out.String(user); Out.Char("'"); Out.Ln;
  Out.String("ident: '"); Out.String(ident); Out.Char("'"); Out.Ln;
  Out.String("host: '"); Out.String(host); Out.Char("'"); Out.Ln;
  Out.String("*** that's it ***"); Out.Ln;
  (*IRC.sendMsgToDst(inst, user, "hello, nice to meet you");*)
  processPrivateMessage(msg, user);
END onPrivateMessage;

PROCEDURE onPublicMessage(VAR msg, msgtype, user, ident, rcpt, host: ARRAY OF CHAR);
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

PROCEDURE onPublicMessageWithMention(VAR msg, msgtype, user, ident, rcpt, host: ARRAY OF CHAR);
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

PROCEDURE interrupt(i: LONGINT);
BEGIN
(* here we need to flush files to disk before exiting. and probably close the irc connection *)
   Out.String("interrupt caught."); Out.Ln;
   IRC.finalize(inst);
   HALT(0);
END interrupt;

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

BEGIN
  inst := IRC.Create("_tanakian", "mobot", "mobot", "irc.libera.chat", "6667", "", TRUE, onPrivateMessage, onPublicMessage, onPublicMessageWithMention);

  (*channel := IRC.AssignChannel(inst, "#fpc", TRUE);*)
  NEW(channels, 1);
  channels[0].channel := '#fpc';
  IRC.setLogging(inst, TRUE);
  IRC.initChannelList(inst, channels);

  Platform.SetInterruptHandler(interrupt);

  (* vocbot specific functionality, buffer to store last n messages *)
  stringList  := StringList.Create();
  log2strings(channels[0].channel, stringList);

  IF IRC.Connect(inst) # FALSE THEN
    b := IRC.Auth(inst);
    IRC.Loop(inst);
  END;

END vocbot.
