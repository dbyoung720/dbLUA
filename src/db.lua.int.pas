unit db.lua.int;

interface

{$M+}

uses Winapi.Windows, System.Rtti, System.Classes, System.SysUtils, System.IOUtils, System.TypInfo, Generics.Collections, db.lua.api, db.lmm;

type
  HiddenAttribute           = class(TCustomAttribute);
  TOnLuaPrint               = procedure(Msg: String) of object;
  ELuaLibraryNotFound       = class(Exception);
  ELuaLibraryLoadError      = class(Exception);
  ELuaLibraryMethodNotFound = class(Exception);

  TMMLua = class(TObject)
  private
    FLuaState    : Lua_State;
    FOnPrint     : TOnLuaPrint;
    FOnError     : TOnLuaPrint;
    FFilePath    : String;
    FAutoRegister: boolean;
    FOpened      : boolean;
  protected
    procedure DoPrint(Msg: String); virtual;
    procedure DoError(Msg: String); virtual;
    function Report(L: Lua_State; Status: Integer): Integer; virtual;
    class procedure RegisterPackage(L: Lua_State; Data: Pointer; Code: Pointer; PackageName: String); overload; virtual;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure Open; virtual;
    procedure Close; virtual;
    class function ValidMethod(Method: TRttiMethod): boolean; virtual;
    class function ValidProperty(LProperty: TRttiProperty): boolean; virtual;
    function DoFile(Filename: String): Integer; virtual;
    function DoString(Value: String): Integer; virtual;
    function DoChunk(L: Lua_State; Status: Integer): Integer; virtual;
    function DoCall(L: Lua_State; NArg, NRes: Integer): Integer; virtual;
    function DoStream(Stream: TStream; Size: Int64 = 0; ChunkName: String = ''): Integer; virtual;
    function LoadFile(Filename: String): Integer; virtual;
    function LoadString(Value: String): Integer; virtual;
    function Run: Integer; virtual;
    class procedure PushFunction(L: Lua_State; Data, Code: Pointer; FuncName: String); overload;
    class procedure PushFunction(L: Lua_State; Data, Code: Pointer); overload;
    class procedure RegisterFunction(L: Lua_State; Func: lua_CFunction; FuncName: String); overload; virtual;
    procedure RegisterFunction(Func: lua_CFunction; FuncName: String); overload; virtual;
    class procedure RegisterFunction(L: Lua_State; Data: Pointer; Code: Pointer; FuncName: String); overload; virtual;
    class procedure RegisterFunction(L: Lua_State; AClass: TClass; Func, FuncName: String); overload; virtual;
    class procedure RegisterFunction(L: Lua_State; AObject: TObject; Func, FuncName: String); overload; virtual;
    class procedure RegisterTableFunction(L: Lua_State; Data: Pointer; Code: Pointer; FuncName: String); overload; virtual;
    class procedure RegisterTableFunction(L: Lua_State; AObject: TObject; Func: String); overload; virtual;
    class procedure RegisterClassFunction(L: Lua_State; AObject: TObject; Func, FuncName: String); overload; virtual;
    procedure RegisterFunction(AClass: TClass; Func: String); overload; virtual;
    procedure RegisterFunction(AClass: TClass; Func, FuncName: String); overload; virtual;
    procedure RegisterFunction(AObject: TObject; Func, FuncName: String); overload; virtual;
    procedure RegisterFunction(AObject: TObject; Func: String); overload; virtual;
    procedure RegisterFunction(Func: String); overload; virtual;
    procedure RegisterFunction(Func, FuncName: String); overload; virtual;
    class procedure RegisterFunctions(L: Lua_State; AClass: TClass); overload; virtual;
    class procedure RegisterFunctions(L: Lua_State; AObject: TObject); overload; virtual;
    class procedure RegisterTableFunctions(L: Lua_State; AObject: TObject); overload; virtual;
    procedure RegisterFunctions(AClass: TClass); overload; virtual;
    procedure RegisterFunctions(AObject: TObject); overload; virtual;
    class procedure RegisterPackageFunctions(L: Lua_State; AObject: TObject); overload; virtual;
    class procedure RegisterPackage(L: Lua_State; PackageName: String; InitFunc: lua_CFunction); overload; virtual;
    procedure RegisterPackage(PackageName: String; InitFunc: lua_CFunction); overload; inline;
    class procedure RegisterPackage(L: Lua_State; PackageName: String; AObject: TObject; PackageLoader: String); overload; virtual;
    procedure RegisterPackage(PackageName: String; AObject: TObject; PackageLoader: String); overload; inline;
    class procedure RegisterPackage(L: Lua_State; PackageName: String; AObject: TObject); overload; virtual;
    procedure RegisterPackage(PackageName: String; AObject: TObject); overload; inline;
    class procedure LoadLuaLibrary; virtual;
    class procedure FreeLuaLibrary; virtual;
    class function LuaLibraryLoaded: boolean; virtual;
    property AutoRegister: boolean read FAutoRegister write FAutoRegister;
    property FilePath: String read FFilePath write FFilePath;
    property OnPrint: TOnLuaPrint read FOnPrint write FOnPrint;
    property OnError: TOnLuaPrint read FOnError write FOnError;
    property Opened: boolean read FOpened;
    property LuaState: Lua_State read FLuaState write FLuaState;
  published
    function print(L: Lua_State): Integer; virtual;
  end;

implementation

const
  ChunkSize = 4096;

type
  TLuaProc = function(L: Lua_State): Integer of object;

  TLuaChunkStream = class(TObject)
  public
    Stream: TStream;
    Size  : Int64;
    Chunk : TMemoryStream;
    function Read(sz: Psize_t): Pointer;
    constructor Create; virtual;
    destructor Destroy; override;
  end;

var
  LibraryHandle: HMODULE;
  gMemDll      : TResourceStream;

function MsgHandler(L: Lua_State): Integer; cdecl;
var
  Msg: MarshaledAString;
begin
  Msg := lua_tostring(L, 1);
  if (Msg = NIL) then
    if (luaL_callmeta(L, 1, '__tostring') <> 0) and (lua_type(L, -1) = LUA_TSTRING) then
    begin
      Result := 1;
      Exit;
    end
    else
      Msg := lua_pushfstring(L, '(error object is a %s value)', [luaL_typename(L, 1)]);
  luaL_traceback(L, L, Msg, 1);
  Result := 1;
end;

function LuaCallBack(L: Lua_State): Integer; cdecl;
var
  Routine: TMethod;
begin
  Routine.Data := lua_topointer(L, lua_upvalueindex(1));
  Routine.Code := lua_topointer(L, lua_upvalueindex(2));
  Result       := TLuaProc(Routine)(L);
end;

function LuaLoadPackage(L: Lua_State): Integer; cdecl;
var
  Obj: TObject;
begin
  Obj := lua_topointer(L, lua_upvalueindex(1));
  lua_newtable(L);
  TMMLua.RegisterPackageFunctions(L, Obj);
  Result := 1;
end;

procedure TMMLua.Close;
begin
  if not FOpened then
    Exit;
  FOpened := False;
  Lua_Close(LuaState);
end;

constructor TMMLua.Create;
begin
  FAutoRegister := True;
{$IF defined(IOS)}
  FilePath := TPath.GetDocumentsPath + PathDelim;
{$ELSEIF defined(ANDROID)}
  LibraryPath := IncludeTrailingPathDelimiter(System.IOUtils.TPath.GetLibraryPath) + LUA_LIBRARY;
  FilePath    := TPath.GetDocumentsPath + PathDelim;
{$ENDIF}
end;

destructor TMMLua.Destroy;
begin
  Close;
  inherited;
end;

function TMMLua.DoChunk(L: Lua_State; Status: Integer): Integer;
begin
  if Status = LUA_OK then
    Status := DoCall(L, 0, LUA_MULTRET);
  Result   := Report(L, Status);
end;

procedure TMMLua.DoError(Msg: String);
begin
end;

function TMMLua.DoCall(L: Lua_State; NArg, NRes: Integer): Integer;
var
  Status: Integer;
  Base  : Integer;
begin
  Base := lua_gettop(L) - NArg;
  lua_pushcfunction(L, MsgHandler);
  lua_insert(L, Base);
  Status := lua_pcall(L, NArg, NRes, Base);
  lua_remove(L, Base);
  Result := Status;
end;

function TMMLua.DoFile(Filename: String): Integer;
var
  Marshall: TMarshaller;
  Path    : String;
begin
  if not Opened then
    Open;
  Path   := FilePath + Filename;
  Result := DoChunk(LuaState, lual_loadfile(LuaState, Marshall.AsAnsi(Path).ToPointer));
end;

procedure TMMLua.DoPrint(Msg: String);
begin
  if Assigned(FOnPrint) then
    FOnPrint(Msg)
  else
    Writeln(Msg);
end;

function TMMLua.DoString(Value: String): Integer;
var
  Marshall: TMarshaller;
begin
  if not Opened then
    Open;
  Result := luaL_dostring(LuaState, Marshall.AsAnsi(Value).ToPointer);
end;

function LuaReader(L: Lua_State; ud: Pointer; sz: Psize_t): Pointer; cdecl;
var
  ChunkStream: TLuaChunkStream;
begin
  ChunkStream := ud;
  Result      := ChunkStream.Read(sz);
end;

function TMMLua.DoStream(Stream: TStream; Size: Int64 = 0; ChunkName: String = ''): Integer;
var
  ChunkStream: TLuaChunkStream;
  Marshall   : TMarshaller;
begin
  if not Opened then
    Open;
  ChunkStream := TLuaChunkStream.Create;
  try
    ChunkStream.Stream := Stream;
    if Size = 0 then
      Size           := Stream.Size;
    ChunkStream.Size := Size;
    Result           := lua_load(LuaState, LuaReader, ChunkStream, Marshall.AsAnsi(ChunkName).ToPointer, NIL);
    if Result = 0 then
      Result := DoChunk(LuaState, Result);
    Result   := Report(LuaState, Result);
  finally
    ChunkStream.Free;
  end;
end;

function TMMLua.Run: Integer;
begin
  if not Opened then
    Open;
  Result := DoChunk(LuaState, LUA_OK);
end;

class procedure TMMLua.RegisterFunction(L: Lua_State; Func: lua_CFunction; FuncName: String);
var
  Marshall: TMarshaller;
begin
  lua_register(L, Marshall.AsAnsi(FuncName).ToPointer, Func);
end;

class procedure TMMLua.PushFunction(L: Lua_State; Data, Code: Pointer);
begin
  lua_pushlightuserdata(L, Data);
  lua_pushlightuserdata(L, Code);
  lua_pushcclosure(L, LuaCallBack, 2);
end;

class procedure TMMLua.PushFunction(L: Lua_State; Data, Code: Pointer; FuncName: String);
var
  Marshall: TMarshaller;
begin
  lua_pushstring(L, Marshall.AsAnsi(FuncName).ToPointer);
  PushFunction(L, Data, Code);
end;

class procedure TMMLua.RegisterFunction(L: Lua_State; Data, Code: Pointer; FuncName: String);
var
  Marshall: TMarshaller;
begin
  PushFunction(L, Data, Code, FuncName);
  lua_setglobal(L, Marshall.AsAnsi(FuncName).ToPointer);
end;

class procedure TMMLua.RegisterFunction(L: Lua_State; AObject: TObject; Func, FuncName: String);
begin
  RegisterFunction(L, AObject, AObject.MethodAddress(Func), FuncName);
end;

class procedure TMMLua.RegisterClassFunction(L: Lua_State; AObject: TObject; Func, FuncName: String);
begin
  RegisterFunction(L, Pointer(AObject.ClassType), AObject.ClassType.MethodAddress(Func), FuncName);
end;

class procedure TMMLua.RegisterFunction(L: Lua_State; AClass: TClass; Func, FuncName: String);
begin
  RegisterFunction(L, AClass, AClass.MethodAddress(Func), FuncName);
end;

procedure TMMLua.RegisterFunction(Func: lua_CFunction; FuncName: String);
begin
  RegisterFunction(LuaState, Func, FuncName);
end;

procedure TMMLua.RegisterFunction(AClass: TClass; Func: String);
begin
  RegisterFunction(LuaState, AClass, AClass.MethodAddress(Func), Func);
end;

procedure TMMLua.RegisterFunction(AClass: TClass; Func, FuncName: String);
begin
  RegisterFunction(LuaState, AClass, AClass.MethodAddress(Func), FuncName);
end;

procedure TMMLua.RegisterFunction(AObject: TObject; Func, FuncName: String);
begin
  RegisterFunction(LuaState, AObject, Func, FuncName);
end;

procedure TMMLua.RegisterFunction(AObject: TObject; Func: String);
begin
  RegisterFunction(LuaState, AObject, Func, Func);
end;

procedure TMMLua.RegisterFunction(Func: String);
begin
  RegisterFunction(LuaState, self, Func, Func);
end;

procedure TMMLua.RegisterFunction(Func, FuncName: String);
begin
  RegisterFunction(LuaState, self, Func, FuncName);
end;

class procedure TMMLua.RegisterFunctions(L: Lua_State; AClass: TClass);
var
  LContext: TRttiContext;
  LType   : TRttiType;
  LMethod : TRttiMethod;
begin
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AClass);
    for LMethod in LType.GetMethods do
      if ValidMethod(LMethod) then
        RegisterFunction(L, AClass, LMethod.Name, LMethod.Name);
  finally
    LContext.Free;
  end;
end;

class function TMMLua.ValidMethod(Method: TRttiMethod): boolean;
var
  Params   : TArray<TRttiParameter>;
  Param    : TRttiParameter;
  Attribute: TCustomAttribute;
begin
  Result := False;
  if (Method.Visibility <> mvPublished) or (not Assigned(Method.ReturnType)) or (Method.ReturnType.TypeKind <> tkInteger) then
    Exit;
  Params := Method.GetParameters;
  if Length(Params) <> 1 then
    Exit;
  Param := Params[0];
  if Param.ParamType.TypeKind <> tkPointer then
    Exit;
  for Attribute in Method.GetAttributes do
    if Attribute is HiddenAttribute then
      Exit;
  Result := True;
end;

class function TMMLua.ValidProperty(LProperty: TRttiProperty): boolean;
var
  Attribute: TCustomAttribute;
begin
  Result := False;
  if (LProperty.Visibility <> mvPublished) then
    Exit;
  for Attribute in LProperty.GetAttributes do
    if Attribute is HiddenAttribute then
      Exit;
  Result := True;
end;

class procedure TMMLua.RegisterFunctions(L: Lua_State; AObject: TObject);
var
  LContext: TRttiContext;
  LType   : TRttiType;
  LMethod : TRttiMethod;
begin
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    for LMethod in LType.GetMethods do
    begin
      if not ValidMethod(LMethod) then
        Continue;
      if LMethod.MethodKind = mkFunction then
        RegisterFunction(L, AObject, AObject.MethodAddress(LMethod.Name), LMethod.Name)
      else if LMethod.MethodKind = mkClassFunction then
        if (LMethod.IsStatic) and (LMethod.CallingConvention = ccCdecl) then
          RegisterFunction(L, lua_CFunction(AObject.MethodAddress(LMethod.Name)), LMethod.Name)
        else
          RegisterFunction(L, Pointer(AObject.ClassType), AObject.ClassType.MethodAddress(LMethod.Name), LMethod.Name);
    end;
  finally
    LContext.Free;
  end;
end;

class procedure TMMLua.RegisterPackageFunctions(L: Lua_State; AObject: TObject);
var
  LContext: TRttiContext;
  LType   : TRttiType;
  LMethod : TRttiMethod;
begin
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    for LMethod in LType.GetMethods do
    begin
      if not ValidMethod(LMethod) then
        Continue;
      PushFunction(L, AObject, LMethod.CodeAddress, LMethod.Name);
      lua_rawset(L, -3);
    end;
  finally
    LContext.Free;
  end;
end;

class procedure TMMLua.RegisterTableFunction(L: Lua_State; Data, Code: Pointer; FuncName: String);
var
  Marshall: TMarshaller;
begin
  PushFunction(L, Data, Code);
  lua_setfield(L, -2, Marshall.AsAnsi(FuncName).ToPointer);
end;

class procedure TMMLua.RegisterTableFunction(L: Lua_State; AObject: TObject; Func: String);
begin
  RegisterTableFunction(L, Pointer(AObject), AObject.MethodAddress(Func), Func);
end;

class procedure TMMLua.RegisterTableFunctions(L: Lua_State; AObject: TObject);
var
  LContext: TRttiContext;
  LType   : TRttiType;
  LMethod : TRttiMethod;
begin
  LContext := TRttiContext.Create;
  try
    LType := LContext.GetType(AObject.ClassType);
    for LMethod in LType.GetMethods do
    begin
      if not ValidMethod(LMethod) then
        Continue;
      if LMethod.MethodKind = mkFunction then
        RegisterTableFunction(L, AObject, AObject.MethodAddress(LMethod.Name), LMethod.Name)
    end;
  finally
    LContext.Free;
  end;
end;

function TMMLua.Report(L: Lua_State; Status: Integer): Integer;
var
  Msg: String;
begin
  if (Status <> LUA_OK) then
  begin
    Msg := UTF8ToString(lua_tostring(L, -1));
    DoError(Msg);
    if Assigned(FOnError) then
    begin
      FOnError(Msg);
    end;
    lua_pop(L, 1);
  end;
  Result := Status;
end;

class procedure TMMLua.RegisterPackage(L: Lua_State; PackageName: String; AObject: TObject);
var
  Marshall: TMarshaller;
begin
  lua_getglobal(L, 'package');
  lua_getfield(L, -1, 'preload');
  lua_pushlightuserdata(L, AObject);
  lua_pushcclosure(L, LuaLoadPackage, 1);
  lua_setfield(L, -2, Marshall.AsAnsi(PackageName).ToPointer);
  lua_pop(L, 2);
end;

procedure TMMLua.RegisterFunctions(AClass: TClass);
begin
  RegisterFunctions(LuaState, AClass);
end;

procedure TMMLua.RegisterFunctions(AObject: TObject);
begin
  RegisterFunctions(LuaState, AObject);
end;

class procedure TMMLua.RegisterPackage(L: Lua_State; PackageName: String; InitFunc: lua_CFunction);
var
  Marshall: TMarshaller;
begin
  lua_getglobal(L, 'package');
  lua_getfield(L, -1, 'preload');
  lua_pushcfunction(L, InitFunc);
  lua_setfield(L, -2, Marshall.AsAnsi(PackageName).ToPointer);
  lua_pop(L, 2);
end;

procedure TMMLua.RegisterPackage(PackageName: String; InitFunc: lua_CFunction);
begin
  RegisterPackage(LuaState, PackageName, InitFunc);
end;

class procedure TMMLua.RegisterPackage(L: Lua_State; Data, Code: Pointer; PackageName: String);
var
  Marshall: TMarshaller;
begin
  lua_getglobal(L, 'package');
  lua_getfield(L, -1, 'preload');
  lua_pushlightuserdata(L, Data);
  lua_pushlightuserdata(L, Code);
  lua_pushcclosure(L, LuaCallBack, 2);
  lua_setfield(L, -2, Marshall.AsAnsi(PackageName).ToPointer);
  lua_pop(L, 2);
end;

procedure TMMLua.RegisterPackage(PackageName: String; AObject: TObject);
begin
  RegisterPackage(LuaState, PackageName, AObject);
end;

class procedure TMMLua.RegisterPackage(L: Lua_State; PackageName: String; AObject: TObject; PackageLoader: String);
var
  LContext: TRttiContext;
  LType   : TRttiType;
  LMethod : TRttiMethod;
  Address : Pointer;
begin
  LContext := TRttiContext.Create;
  try
    LType   := LContext.GetType(AObject.ClassType);
    LMethod := LType.GetMethod(PackageLoader);
    Address := LMethod.CodeAddress;
    RegisterPackage(L, AObject, Address, PackageName);
  finally
    LContext.Free;
  end;
end;

procedure TMMLua.RegisterPackage(PackageName: String; AObject: TObject; PackageLoader: String);
begin
  RegisterPackage(LuaState, PackageName, AObject, PackageLoader);
end;

function GetAddress(Name: String): Pointer;
begin
  Result := MemGetProcAddress(LibraryHandle, PAnsiChar(AnsiString(Name)));
  if not Assigned(Result) then
    raise ELuaLibraryMethodNotFound.Create('Entry point "' + QuotedStr(Name) + '" not found');
end;

function TMMLua.LoadFile(Filename: String): Integer;
var
  Marshall: TMarshaller;
begin
  if not Opened then
    Open;
  Result := lual_loadfile(LuaState, Marshall.AsAnsi(Filename).ToPointer);
end;

class procedure TMMLua.LoadLuaLibrary;
begin
  FreeLuaLibrary;

{$IFDEF CPUX86}
  gMemDll := TResourceStream.Create(hinstance, 'LUAX86DLL', RT_RCDATA);
{$ELSE}
  gMemDll := TResourceStream.Create(hinstance, 'LUAX64DLL', RT_RCDATA);
{$ENDIF}
  LibraryHandle := MemLoadLibrary(gMemDll.Memory);
  if LibraryHandle = INVALID_HANDLE_VALUE then
    raise ELuaLibraryLoadError.Create('Failed to load Lua library error');
  lua_newstate          := GetAddress('lua_newstate');
  Lua_Close             := GetAddress('lua_close');
  lua_newthread         := GetAddress('lua_newthread');
  lua_atpanic           := GetAddress('lua_atpanic');
  lua_version           := GetAddress('lua_version');
  lua_absindex          := GetAddress('lua_absindex');
  lua_gettop            := GetAddress('lua_gettop');
  lua_settop            := GetAddress('lua_settop');
  lua_pushvalue         := GetAddress('lua_pushvalue');
  lua_rotate            := GetAddress('lua_rotate');
  lua_copy              := GetAddress('lua_copy');
  lua_checkstack        := GetAddress('lua_checkstack');
  lua_xmove             := GetAddress('lua_xmove');
  lua_isnumber          := GetAddress('lua_isnumber');
  lua_isstring          := GetAddress('lua_isstring');
  lua_iscfunction       := GetAddress('lua_iscfunction');
  lua_isinteger         := GetAddress('lua_isinteger');
  lua_isuserdata        := GetAddress('lua_isuserdata');
  lua_type              := GetAddress('lua_type');
  lua_typename          := GetAddress('lua_typename');
  lua_tonumberx         := GetAddress('lua_tonumberx');
  lua_tointegerx        := GetAddress('lua_tointegerx');
  lua_toboolean         := GetAddress('lua_toboolean');
  lua_tolstring         := GetAddress('lua_tolstring');
  lua_rawlen            := GetAddress('lua_rawlen');
  lua_tocfunction       := GetAddress('lua_tocfunction');
  lua_touserdata        := GetAddress('lua_touserdata');
  lua_tothread          := GetAddress('lua_tothread');
  lua_topointer         := GetAddress('lua_topointer');
  lua_arith             := GetAddress('lua_arith');
  lua_rawequal          := GetAddress('lua_rawequal');
  lua_compare           := GetAddress('lua_compare');
  lua_pushnil           := GetAddress('lua_pushnil');
  lua_pushnumber        := GetAddress('lua_pushnumber');
  lua_pushinteger       := GetAddress('lua_pushinteger');
  lua_pushlstring       := GetAddress('lua_pushlstring');
  lua_pushstring        := GetAddress('lua_pushstring');
  lua_pushvfstring      := GetAddress('lua_pushvfstring');
  lua_pushfstring       := GetAddress('lua_pushfstring');
  lua_pushcclosure      := GetAddress('lua_pushcclosure');
  lua_pushboolean       := GetAddress('lua_pushboolean');
  lua_pushlightuserdata := GetAddress('lua_pushlightuserdata');
  lua_pushthread        := GetAddress('lua_pushthread');
  lua_getglobal         := GetAddress('lua_getglobal');
  lua_gettable          := GetAddress('lua_gettable');
  lua_getfield          := GetAddress('lua_getfield');
  lua_geti              := GetAddress('lua_geti');
  lua_rawget            := GetAddress('lua_rawget');
  lua_rawgeti           := GetAddress('lua_rawgeti');
  lua_rawgetp           := GetAddress('lua_rawgetp');
  lua_createtable       := GetAddress('lua_createtable');
  lua_newuserdata       := GetAddress('lua_newuserdata');
  lua_getmetatable      := GetAddress('lua_getmetatable');
  lua_getuservalue      := GetAddress('lua_getuservalue');
  lua_setglobal         := GetAddress('lua_setglobal');
  lua_settable          := GetAddress('lua_settable');
  lua_setfield          := GetAddress('lua_setfield');
  lua_seti              := GetAddress('lua_seti');
  lua_rawset            := GetAddress('lua_rawset');
  lua_rawseti           := GetAddress('lua_rawseti');
  lua_rawsetp           := GetAddress('lua_rawsetp');
  lua_setmetatable      := GetAddress('lua_setmetatable');
  lua_setuservalue      := GetAddress('lua_setuservalue');
  lua_callk             := GetAddress('lua_callk');
  lua_pcallk            := GetAddress('lua_pcallk');
  lua_load              := GetAddress('lua_load');
  lua_dump              := GetAddress('lua_dump');
  lua_yieldk            := GetAddress('lua_yieldk');
  lua_resume            := GetAddress('lua_resume');
  lua_status            := GetAddress('lua_status');
  lua_isyieldable       := GetAddress('lua_isyieldable');
  lua_gc                := GetAddress('lua_gc');
  lua_error             := GetAddress('lua_error');
  lua_next              := GetAddress('lua_next');
  lua_concat            := GetAddress('lua_concat');
  lua_len               := GetAddress('lua_len');
  lua_stringtonumber    := GetAddress('lua_stringtonumber');
  lua_getallocf         := GetAddress('lua_getallocf');
  lua_setallocf         := GetAddress('lua_setallocf');
  lua_getstack          := GetAddress('lua_getstack');
  lua_getinfo           := GetAddress('lua_getinfo');
  lua_getlocal          := GetAddress('lua_getlocal');
  lua_setlocal          := GetAddress('lua_setlocal');
  lua_getupvalue        := GetAddress('lua_getupvalue');
  lua_setupvalue        := GetAddress('lua_setupvalue');
  lua_upvalueid         := GetAddress('lua_upvalueid');
  lua_upvaluejoin       := GetAddress('lua_upvaluejoin');
  lua_sethook           := GetAddress('lua_sethook');
  lua_gethook           := GetAddress('lua_gethook');
  lua_gethookmask       := GetAddress('lua_gethookmask');
  lua_gethookcount      := GetAddress('lua_gethookcount');
  luaopen_base          := GetAddress('luaopen_base');
  luaopen_coroutine     := GetAddress('luaopen_coroutine');
  luaopen_table         := GetAddress('luaopen_table');
  luaopen_io            := GetAddress('luaopen_io');
  luaopen_os            := GetAddress('luaopen_os');
  luaopen_string        := GetAddress('luaopen_string');
  luaopen_utf8          := GetAddress('luaopen_utf8');
  luaopen_bit32         := GetAddress('luaopen_bit32');
  luaopen_math          := GetAddress('luaopen_math');
  luaopen_debug         := GetAddress('luaopen_debug');
  luaopen_package       := GetAddress('luaopen_package');
  luaL_openlibs         := GetAddress('luaL_openlibs');
  luaL_checkversion_    := GetAddress('luaL_checkversion_');
  luaL_getmetafield     := GetAddress('luaL_getmetafield');
  luaL_callmeta         := GetAddress('luaL_callmeta');
  luaL_tolstring        := GetAddress('luaL_tolstring');
  luaL_argerror         := GetAddress('luaL_argerror');
  luaL_checklstring     := GetAddress('luaL_checklstring');
  luaL_optlstring       := GetAddress('luaL_optlstring');
  luaL_checknumber      := GetAddress('luaL_checknumber');
  luaL_optnumber        := GetAddress('luaL_optnumber');
  luaL_checkinteger     := GetAddress('luaL_checkinteger');
  luaL_optinteger       := GetAddress('luaL_optinteger');
  luaL_checkstack       := GetAddress('luaL_checkstack');
  luaL_checktype        := GetAddress('luaL_checktype');
  luaL_checkany         := GetAddress('luaL_checkany');
  luaL_newmetatable     := GetAddress('luaL_newmetatable');
  luaL_setmetatable     := GetAddress('luaL_setmetatable');
  luaL_testudata        := GetAddress('luaL_testudata');
  luaL_checkudata       := GetAddress('luaL_checkudata');
  luaL_where            := GetAddress('luaL_where');
  luaL_error            := GetAddress('luaL_error');
  luaL_checkoption      := GetAddress('luaL_checkoption');
  luaL_fileresult       := GetAddress('luaL_fileresult');
  luaL_execresult       := GetAddress('luaL_execresult');
  luaL_ref              := GetAddress('luaL_ref');
  luaL_unref            := GetAddress('luaL_unref');
  luaL_loadfilex        := GetAddress('luaL_loadfilex');
  luaL_loadbufferx      := GetAddress('luaL_loadbufferx');
  luaL_loadstring       := GetAddress('luaL_loadstring');
  luaL_newstate         := GetAddress('luaL_newstate');
  luaL_len              := GetAddress('luaL_len');
  luaL_gsub             := GetAddress('luaL_gsub');
  luaL_setfuncs         := GetAddress('luaL_setfuncs');
  luaL_getsubtable      := GetAddress('luaL_getsubtable');
  luaL_traceback        := GetAddress('luaL_traceback');
  luaL_requiref         := GetAddress('luaL_requiref');
  luaL_buffinit         := GetAddress('luaL_buffinit');
  luaL_prepbuffsize     := GetAddress('luaL_prepbuffsize');
  luaL_addlstring       := GetAddress('luaL_addlstring');
  luaL_addstring        := GetAddress('luaL_addstring');
  luaL_addvalue         := GetAddress('luaL_addvalue');
  luaL_pushresult       := GetAddress('luaL_pushresult');
  luaL_pushresultsize   := GetAddress('luaL_pushresultsize');
  luaL_buffinitsize     := GetAddress('luaL_buffinitsize');
end;

function TMMLua.LoadString(Value: String): Integer;
var
  Marshall: TMarshaller;
begin
  if not Opened then
    Open;
  Result := luaL_loadstring(LuaState, Marshall.AsAnsi(Value).ToPointer);
end;

class function TMMLua.LuaLibraryLoaded: boolean;
begin
  Result := (LibraryHandle <> 0);
end;

procedure TMMLua.Open;
begin
  if FOpened then
    Exit;

  FOpened := True;
  if not LuaLibraryLoaded then
    LoadLuaLibrary();
  LuaState := luaL_newstate;
  luaL_openlibs(LuaState);
  if FAutoRegister then
    RegisterFunctions(self);
end;

class procedure TMMLua.FreeLuaLibrary;
begin
  if LibraryHandle <> 0 then
  begin
    MemFreeLibrary(LibraryHandle);
    LibraryHandle := 0;
    gMemDll.Free;
    gMemDll := nil;
  end;
end;

function TMMLua.print(L: Lua_State): Integer;
var
  N, I: Integer;
  S   : MarshaledAString;
  sz  : size_t;
  Msg : String;
begin
  Msg := '';
  N   := lua_gettop(L);
  lua_getglobal(L, 'tostring');
  for I := 1 to N do
  begin
    lua_pushvalue(L, -1);
    lua_pushvalue(L, I);
    lua_call(L, 1, 1);
    S := lua_tolstring(L, -1, @sz);
    if S = NIL then
    begin
      Result := luaL_error(L, '"tostring" must return a string to "print"', []);
      Exit;
    end;
    if I > 1 then
      Msg := Msg + #9;
    Msg   := Msg + String(S);
    lua_pop(L, 1);
  end;
  Result := 0;
  DoPrint(Msg);
end;

constructor TLuaChunkStream.Create;
begin
  Chunk := TMemoryStream.Create;
end;

destructor TLuaChunkStream.Destroy;
begin
  Chunk.Free;
  inherited;
end;

function TLuaChunkStream.Read(sz: Psize_t): Pointer;
var
  LocalChunkSize: Int64;
begin
  Chunk.Clear;
  if Size >= ChunkSize then
    LocalChunkSize := ChunkSize
  else
    LocalChunkSize := Size;
  if LocalChunkSize > 0 then
  begin
    Chunk.CopyFrom(Stream, LocalChunkSize);
    Size := Size - LocalChunkSize;
  end;
  sz^    := LocalChunkSize;
  Result := Chunk.Memory;
end;

initialization
  LibraryHandle := 0;
  gMemDll       := nil;

finalization
  if LibraryHandle <> 0 then
    TMMLua.FreeLuaLibrary;

end.
