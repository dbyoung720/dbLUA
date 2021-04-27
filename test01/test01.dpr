program test01;

{$APPTYPE CONSOLE}

uses
  SysUtils,
  Classes,
  db.lmm in '..\src\db.lmm.pas',
  db.lua.api in '..\src\db.lua.api.pas',
  db.lua.int in '..\src\db.lua.int.pas';

var
  lua: TMMlua;

begin
  try
    lua := TMMlua.Create;
    lua.DoFile('..\..\example1.lua');
    lua.Free;
    Readln;

  except
    on E: Exception do
      WriteLN(E.ClassName, ': ', E.Message);
  end;

end.
