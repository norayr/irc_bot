MODULE TestList;
IMPORT StringList, Out(* := OakOut*);

VAR strs : StringList.TStringList;
str : StringList.TString;
l : LONGINT;
L0 : StringList.TList;

PROCEDURE list(VAR s : StringList.TStringList);
VAR
  e : StringList.Node;
  i : INTEGER;
  L : StringList.TList;
BEGIN
   NEW(e);
   i := 0;
   NEW(L);
   L := s;
   REPEAT
      e := s.Get(L, i);
      IF e # NIL THEN Out.String (e.obj(StringList.TString).str); Out.Ln END;
      (*Out.String (e.string); Out.Ln;*)
      INC(i);
   UNTIL i = s.Count;
END list;



BEGIN
   strs := StringList.Create();
   (*str.str := "000";*)
   l := strs.AddString(strs, "000");

   strs.AppendString(strs, "001");

   strs.AppendString(strs, "002");

   NEW(str);
   str.str := "003";
   NEW(L0);
   L0 := strs;
   strs.Append(L0, str);

   strs.AppendString(strs, "004");

   strs.AppendString(strs, "005");

   l := strs.AddString(strs, "006");

   Out.Int(strs.Count, 0); Out.Ln;

   list(strs);
   Out.Ln;
   NEW(str);
   str.str := "aaa";
   strs.Insert(L0, 6, str);

   list(strs);
   Out.Ln;
   l := strs.IndexOf(strs, "000");
   Out.String ("index "); Out.Int (l,0); Out.Ln;

   strs.Delete(L0,6);

   list(strs);

END TestList.
