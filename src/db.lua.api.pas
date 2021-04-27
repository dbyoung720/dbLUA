unit db.lua.api;

interface

uses
  System.Classes, Winapi.Windows, System.SysUtils, System.IOUtils;

const
  LUA_IDSIZE          = 60;
  LUAI_FIRSTPSEUDOIDX = -1001000;
  LUA_VERSION_MAJOR   = '5';
  LUA_VERSION_MINOR   = '3';
  LUA_VERSION_NUM     = 503;
  LUA_VERSION_RELEASE = '0';
  LUA_VERSION_        = 'Lua ' + LUA_VERSION_MAJOR + '.' + LUA_VERSION_MINOR;
  LUA_RELEASE         = LUA_VERSION_ + '.' + LUA_VERSION_RELEASE;
  LUA_COPYRIGHT       = LUA_RELEASE + '  Copyright (C) 1994-2015 Lua.org, PUC-Rio';
  LUA_AUTHORS         = 'R. Ierusalimschy, L. H. de Figueiredo, W. Celes';
  LUA_SIGNATURE       = #$1b'Lua';
  LUA_MULTRET         = -1;
  LUA_REGISTRYINDEX   = LUAI_FIRSTPSEUDOIDX;
  LUA_OK              = 0;
  LUA_YIELD_          = 1;
  LUA_ERRRUN          = 2;
  LUA_ERRSYNTAX       = 3;
  LUA_ERRMEM          = 4;
  LUA_ERRGCMM         = 5;
  LUA_ERRERR          = 6;
  LUA_TNONE           = (-1);
  LUA_TNIL            = 0;
  LUA_TBOOLEAN        = 1;
  LUA_TLIGHTUSERDATA  = 2;
  LUA_TNUMBER         = 3;
  LUA_TSTRING         = 4;
  LUA_TTABLE          = 5;
  LUA_TFUNCTION       = 6;
  LUA_TUSERDATA       = 7;
  LUA_TTHREAD         = 8;
  LUA_NUMTAGS         = 9;
  LUA_MINSTACK        = 20;
  LUA_RIDX_MAINTHREAD = 1;
  LUA_RIDX_GLOBALS    = 2;
  LUA_RIDX_LAST       = LUA_RIDX_GLOBALS;
  LUA_OPADD           = 0;
  LUA_OPSUB           = 1;
  LUA_OPMUL           = 2;
  LUA_OPMOD           = 3;
  LUA_OPPOW           = 4;
  LUA_OPDIV           = 5;
  LUA_OPIDIV          = 6;
  LUA_OPBAND          = 7;
  LUA_OPBOR           = 8;
  LUA_OPBXOR          = 9;
  LUA_OPSHL           = 10;
  LUA_OPSHR           = 11;
  LUA_OPUNM           = 12;
  LUA_OPBNOT          = 13;
  LUA_OPEQ            = 0;
  LUA_OPLT            = 1;
  LUA_OPLE            = 2;
  LUA_GCSTOP          = 0;
  LUA_GCRESTART       = 1;
  LUA_GCCOLLECT       = 2;
  LUA_GCCOUNT         = 3;
  LUA_GCCOUNTB        = 4;
  LUA_GCSTEP          = 5;
  LUA_GCSETPAUSE      = 6;
  LUA_GCSETSTEPMUL    = 7;
  LUA_GCISRUNNING     = 9;
  LUA_HOOKCALL        = 0;
  LUA_HOOKRET         = 1;
  LUA_HOOKLINE        = 2;
  LUA_HOOKCOUNT       = 3;
  LUA_HOOKTAILCALL    = 4;
  LUA_MASKCALL        = (1 SHL LUA_HOOKCALL);
  LUA_MASKRET         = (1 SHL LUA_HOOKRET);
  LUA_MASKLINE        = (1 SHL LUA_HOOKLINE);
  LUA_MASKCOUNT       = (1 SHL LUA_HOOKCOUNT);
  LUA_COLIBNAME       = 'coroutine';
  LUA_TABLIBNAME      = 'table';
  LUA_IOLIBNAME       = 'io';
  LUA_OSLIBNAME       = 'os';
  LUA_STRLIBNAME      = 'string';
  LUA_UTF8LIBNAME     = 'utf8';
  LUA_BITLIBNAME      = 'bit32';
  LUA_MATHLIBNAME     = 'math';
  LUA_DBLIBNAME       = 'debug';
  LUA_LOADLIBNAME     = 'package';
  LUAL_NUMSIZES       = sizeof(NativeInt) * 16 + sizeof(Double);
  LUA_NOREF           = -2;
  LUA_REFNIL          = -1;
  LUAL_BUFFERSIZE     = Integer($80 * sizeof(Pointer) * sizeof(NativeInt));
  LUA_FILEHANDLE      = 'FILE*';

type
  lua_State     = Pointer;
  ptrdiff_t     = NativeInt;
  lua_Number    = Double;
  lua_Integer   = Int64;
  lua_Unsigned  = Uint64;
  lua_KContext  = ptrdiff_t;
  lua_CFunction = function(L: lua_State)                                       : Integer; cdecl;
  lua_KFunction = function(L: lua_State; status: Integer; ctx: lua_KContext)   : Integer; cdecl;
  lua_Reader    = function(L: lua_State; ud: Pointer; sz: Psize_t)                : Pointer; cdecl;
  lua_Writer    = function(L: lua_State; p: Pointer; sz: size_t; ud: Pointer)     : Integer; cdecl;
  lua_Alloc     = function(ud: Pointer; ptr: Pointer; osize: size_t; nsize: size_t): Pointer; cdecl;

  lua_Debug = record
    event: Integer;
    name: MarshaledAString;
    namewhat: MarshaledAString;
    what: MarshaledAString;
    source: MarshaledAString;
    currentline: Integer;
    linedefined: Integer;
    lastlinedefined: Integer;
    nups: Byte;
    nparams: Byte;
    isvararg: ByteBool;
    istailcall: ByteBool;
    short_src: array [0 .. LUA_IDSIZE - 1] of Char;
    i_ci: Pointer;
  end;

  Plua_Debug = ^lua_Debug;
  lua_Hook   = procedure(L: lua_State; ar: Plua_Debug); cdecl;

  luaL_Reg = record
    name: MarshaledAString;
    func: lua_CFunction;
  end;

  PluaL_Reg = ^luaL_Reg;

  luaL_Buffer = record
    b: MarshaledAString;
    size: size_t;
    n: size_t;
    L: lua_State;
    initb: array [0 .. LUAL_BUFFERSIZE - 1] of Byte;
  end;

  Plual_Buffer = ^luaL_Buffer;

  luaL_Stream = record
    f: Pointer;
    closef: lua_CFunction;
  end;

var
  lua_newstate         : function(f: lua_Alloc; ud: Pointer): lua_State; cdecl;
  lua_close            : procedure(L: lua_State); cdecl;
  lua_newthread        : function(L: lua_State): lua_State; cdecl;
  lua_atpanic          : function(L: lua_State; panicf: lua_CFunction): lua_CFunction; cdecl;
  lua_version          : function(L: lua_State): lua_Number; cdecl;
  lua_absindex         : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_gettop           : function(L: lua_State): Integer; cdecl;
  lua_settop           : procedure(L: lua_State; idx: Integer); cdecl;
  lua_pushvalue        : procedure(L: lua_State; idx: Integer); cdecl;
  lua_rotate           : procedure(L: lua_State; idx: Integer; n: Integer); cdecl;
  lua_copy             : procedure(L: lua_State; fromidx: Integer; toidx: Integer); cdecl;
  lua_checkstack       : function(L: lua_State; n: Integer): Integer; cdecl;
  lua_xmove            : procedure(from: lua_State; to_: lua_State; n: Integer); cdecl;
  lua_isnumber         : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_isstring         : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_iscfunction      : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_isinteger        : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_isuserdata       : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_type             : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_typename         : function(L: lua_State; tp: Integer): MarshaledAString; cdecl;
  lua_tonumberx        : function(L: lua_State; idx: Integer; isnum: PLongBool): lua_Number; cdecl;
  lua_tointegerx       : function(L: lua_State; idx: Integer; isnum: PLongBool): lua_Integer; cdecl;
  lua_toboolean        : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_tolstring        : function(L: lua_State; idx: Integer; len: Psize_t): MarshaledAString; cdecl;
  lua_rawlen           : function(L: lua_State; idx: Integer): size_t; cdecl;
  lua_tocfunction      : function(L: lua_State; idx: Integer): lua_CFunction; cdecl;
  lua_touserdata       : function(L: lua_State; idx: Integer): Pointer; cdecl;
  lua_tothread         : function(L: lua_State; idx: Integer): lua_State; cdecl;
  lua_topointer        : function(L: lua_State; idx: Integer): Pointer; cdecl;
  lua_arith            : procedure(L: lua_State; op: Integer); cdecl;
  lua_rawequal         : function(L: lua_State; idx1: Integer; idx2: Integer): Integer; cdecl;
  lua_compare          : function(L: lua_State; idx1: Integer; idx2: Integer; op: Integer): Integer; cdecl;
  lua_pushnil          : procedure(L: lua_State); cdecl;
  lua_pushnumber       : procedure(L: lua_State; n: lua_Number); cdecl;
  lua_pushinteger      : procedure(L: lua_State; n: lua_Integer); cdecl;
  lua_pushlstring      : function(L: lua_State; s: MarshaledAString; len: size_t): MarshaledAString; cdecl;
  lua_pushstring       : function(L: lua_State; s: MarshaledAString): MarshaledAString; cdecl;
  lua_pushvfstring     : function(L: lua_State; fmt: MarshaledAString; argp: Pointer): MarshaledAString; cdecl;
  lua_pushfstring      : function(L: lua_State; fmt: MarshaledAString; args: array of const): MarshaledAString; cdecl;
  lua_pushcclosure     : procedure(L: lua_State; fn: lua_CFunction; n: Integer); cdecl;
  lua_pushboolean      : procedure(L: lua_State; b: Integer); cdecl;
  lua_pushlightuserdata: procedure(L: lua_State; p: Pointer); cdecl;
  lua_pushthread       : function(L: lua_State): Integer; cdecl;
  lua_getglobal        : function(L: lua_State; const name: MarshaledAString): Integer; cdecl;
  lua_gettable         : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_getfield         : function(L: lua_State; idx: Integer; k: MarshaledAString): Integer; cdecl;
  lua_geti             : function(L: lua_State; idx: Integer; n: lua_Integer): Integer; cdecl;
  lua_rawget           : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_rawgeti          : function(L: lua_State; idx: Integer; n: lua_Integer): Integer; cdecl;
  lua_rawgetp          : function(L: lua_State; idx: Integer; p: Pointer): Integer; cdecl;
  lua_createtable      : procedure(L: lua_State; narr: Integer; nrec: Integer); cdecl;
  lua_newuserdata      : function(L: lua_State; sz: size_t): Pointer; cdecl;
  lua_getmetatable     : function(L: lua_State; objindex: Integer): Integer; cdecl;
  lua_getuservalue     : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_setglobal        : procedure(L: lua_State; name: MarshaledAString); cdecl;
  lua_settable         : procedure(L: lua_State; idx: Integer); cdecl;
  lua_setfield         : procedure(L: lua_State; idx: Integer; k: MarshaledAString); cdecl;
  lua_seti             : procedure(L: lua_State; idx: Integer; n: lua_Integer); cdecl;
  lua_rawset           : procedure(L: lua_State; idx: Integer); cdecl;
  lua_rawseti          : procedure(L: lua_State; idx: Integer; n: lua_Integer); cdecl;
  lua_rawsetp          : procedure(L: lua_State; idx: Integer; p: Pointer); cdecl;
  lua_setmetatable     : function(L: lua_State; objindex: Integer): Integer; cdecl;
  lua_setuservalue     : procedure(L: lua_State; idx: Integer); cdecl;
  lua_callk            : procedure(L: lua_State; nargs: Integer; nresults: Integer; ctx: lua_KContext; k: lua_KFunction); cdecl;
  lua_pcallk           : function(L: lua_State; nargs: Integer; nresults: Integer; errfunc: Integer; ctx: lua_KContext; k: lua_KFunction): Integer; cdecl;
  lua_load             : function(L: lua_State; reader: lua_Reader; dt: Pointer; const chunkname: MarshaledAString; const mode: MarshaledAString): Integer; cdecl;
  lua_dump             : function(L: lua_State; writer: lua_Writer; data: Pointer; strip: Integer): Integer; cdecl;
  lua_yieldk           : function(L: lua_State; nresults: Integer; ctx: lua_KContext; k: lua_KFunction): Integer; cdecl;
  lua_resume           : function(L: lua_State; from: lua_State; narg: Integer): Integer; cdecl;
  lua_status           : function(L: lua_State): Integer; cdecl;
  lua_isyieldable      : function(L: lua_State): Integer; cdecl;
  lua_gc               : function(L: lua_State; what: Integer; data: Integer): Integer; cdecl;
  lua_error            : function(L: lua_State): Integer; cdecl;
  lua_next             : function(L: lua_State; idx: Integer): Integer; cdecl;
  lua_concat           : procedure(L: lua_State; n: Integer); cdecl;
  lua_len              : procedure(L: lua_State; idx: Integer); cdecl;
  lua_stringtonumber   : function(L: lua_State; const s: MarshaledAString): size_t; cdecl;
  lua_getallocf        : function(L: lua_State; ud: PPointer): lua_Alloc; cdecl;
  lua_setallocf        : procedure(L: lua_State; f: lua_Alloc; ud: Pointer); cdecl;
  lua_getstack         : function(L: lua_State; level: Integer; ar: Plua_Debug): Integer; cdecl;
  lua_getinfo          : function(L: lua_State; const what: MarshaledAString; ar: Plua_Debug): Integer; cdecl;
  lua_getlocal         : function(L: lua_State; const ar: Plua_Debug; n: Integer): MarshaledAString; cdecl;
  lua_setlocal         : function(L: lua_State; const ar: Plua_Debug; n: Integer): MarshaledAString; cdecl;
  lua_getupvalue       : function(L: lua_State; funcindex, n: Integer): MarshaledAString; cdecl;
  lua_setupvalue       : function(L: lua_State; funcindex, n: Integer): MarshaledAString; cdecl;
  lua_upvalueid        : function(L: lua_State; fidx, n: Integer): Pointer; cdecl;
  lua_upvaluejoin      : procedure(L: lua_State; fix1, n1, fidx2, n2: Integer); cdecl;
  lua_sethook          : procedure(L: lua_State; func: lua_Hook; mask: Integer; count: Integer); cdecl;
  lua_gethook          : function(L: lua_State): lua_Hook; cdecl;
  lua_gethookmask      : function(L: lua_State): Integer; cdecl;
  lua_gethookcount     : function(L: lua_State): Integer; cdecl;
  luaopen_base         : function(L: lua_State): Integer; cdecl;
  luaopen_coroutine    : function(L: lua_State): Integer; cdecl;
  luaopen_table        : function(L: lua_State): Integer; cdecl;
  luaopen_io           : function(L: lua_State): Integer; cdecl;
  luaopen_os           : function(L: lua_State): Integer; cdecl;
  luaopen_string       : function(L: lua_State): Integer; cdecl;
  luaopen_utf8         : function(L: lua_State): Integer; cdecl;
  luaopen_bit32        : function(L: lua_State): Integer; cdecl;
  luaopen_math         : function(L: lua_State): Integer; cdecl;
  luaopen_debug        : function(L: lua_State): Integer; cdecl;
  luaopen_package      : function(L: lua_State): Integer; cdecl;
  luaL_openlibs        : procedure(L: lua_State); cdecl;
  luaL_checkversion_   : procedure(L: lua_State; ver: lua_Number; sz: size_t); cdecl;
  luaL_getmetafield    : function(L: lua_State; obj: Integer; e: MarshaledAString): Integer; cdecl;
  luaL_callmeta        : function(L: lua_State; obj: Integer; e: MarshaledAString): Integer; cdecl;
  luaL_tolstring       : function(L: lua_State; idx: Integer; len: Psize_t): MarshaledAString; cdecl;
  luaL_argerror        : function(L: lua_State; arg: Integer; extramsg: MarshaledAString): Integer; cdecl;
  luaL_checklstring    : function(L: lua_State; arg: Integer; l_: Psize_t): MarshaledAString; cdecl;
  luaL_optlstring      : function(L: lua_State; arg: Integer; const def: MarshaledAString; l_: Psize_t): MarshaledAString; cdecl;
  luaL_checknumber     : function(L: lua_State; arg: Integer): lua_Number; cdecl;
  luaL_optnumber       : function(L: lua_State; arg: Integer; def: lua_Number): lua_Number; cdecl;
  luaL_checkinteger    : function(L: lua_State; arg: Integer): lua_Integer; cdecl;
  luaL_optinteger      : function(L: lua_State; arg: Integer; def: lua_Integer): lua_Integer; cdecl;
  luaL_checkstack      : procedure(L: lua_State; sz: Integer; const msg: MarshaledAString); cdecl;
  luaL_checktype       : procedure(L: lua_State; arg: Integer; t: Integer); cdecl;
  luaL_checkany        : procedure(L: lua_State; arg: Integer); cdecl;
  luaL_newmetatable    : function(L: lua_State; const tname: MarshaledAString): Integer; cdecl;
  luaL_setmetatable    : procedure(L: lua_State; const tname: MarshaledAString); cdecl;
  luaL_testudata       : procedure(L: lua_State; ud: Integer; const tname: MarshaledAString); cdecl;
  luaL_checkudata      : function(L: lua_State; ud: Integer; const tname: MarshaledAString): Pointer; cdecl;
  luaL_where           : procedure(L: lua_State; lvl: Integer); cdecl;
  luaL_error           : function(L: lua_State; fmt: MarshaledAString; args: array of const): Integer; cdecl;
  luaL_checkoption     : function(L: lua_State; arg: Integer; const def: MarshaledAString; const lst: PMarshaledAString): Integer; cdecl;
  luaL_fileresult      : function(L: lua_State; stat: Integer; fname: MarshaledAString): Integer; cdecl;
  luaL_execresult      : function(L: lua_State; stat: Integer): Integer; cdecl;
  luaL_ref             : function(L: lua_State; t: Integer): Integer; cdecl;
  luaL_unref           : procedure(L: lua_State; t: Integer; ref: Integer); cdecl;
  luaL_loadfilex       : function(L: lua_State; const filename: MarshaledAString; const mode: MarshaledAString): Integer; cdecl;
  luaL_loadbufferx     : function(L: lua_State; const buff: MarshaledAString; sz: size_t; const name: MarshaledAString; const mode: MarshaledAString): Integer; cdecl;
  luaL_loadstring      : function(L: lua_State; const s: MarshaledAString): Integer; cdecl;
  luaL_newstate        : function(): lua_State; cdecl;
  luaL_len             : function(L: lua_State; idx: Integer): lua_Integer; cdecl;
  luaL_gsub            : function(L: lua_State; const s: MarshaledAString; const p: MarshaledAString; const r: MarshaledAString): MarshaledAString; cdecl;
  luaL_setfuncs        : procedure(L: lua_State; const l_: PluaL_Reg; nup: Integer); cdecl;
  luaL_getsubtable     : function(L: lua_State; idx: Integer; const fname: MarshaledAString): Integer; cdecl;
  luaL_traceback       : procedure(L: lua_State; L1: lua_State; const msg: MarshaledAString; level: Integer); cdecl;
  luaL_requiref        : procedure(L: lua_State; const modname: MarshaledAString; openf: lua_CFunction; glb: Integer); cdecl;
  luaL_buffinit        : procedure(L: lua_State; b: Plual_Buffer); cdecl;
  luaL_prepbuffsize    : function(b: Plual_Buffer; sz: size_t): Pointer; cdecl;
  luaL_addlstring      : procedure(b: Plual_Buffer; const s: MarshaledAString; L: size_t); cdecl;
  luaL_addstring       : procedure(b: Plual_Buffer; const s: MarshaledAString); cdecl;
  luaL_addvalue        : procedure(b: Plual_Buffer); cdecl;
  luaL_pushresult      : procedure(b: Plual_Buffer); cdecl;
  luaL_pushresultsize  : procedure(b: Plual_Buffer; sz: size_t); cdecl;
  luaL_buffinitsize    : function(L: lua_State; b: Plual_Buffer; sz: size_t): Pointer; cdecl;
function lua_tonumber(L: lua_State; idx: Integer): lua_Number; inline;
function lua_tointeger(L: lua_State; idx: Integer): lua_Integer; inline;
procedure lua_pop(L: lua_State; n: Integer); inline;
procedure lua_newtable(L: lua_State); inline;
procedure lua_register(L: lua_State; const n: MarshaledAString; f: lua_CFunction); inline;
procedure lua_pushcfunction(L: lua_State; f: lua_CFunction); inline;
function lua_isfunction(L: lua_State; n: Integer): Boolean; inline;
function lua_istable(L: lua_State; n: Integer): Boolean; inline;
function lua_islightuserdata(L: lua_State; n: Integer): Boolean; inline;
function lua_isnil(L: lua_State; n: Integer): Boolean; inline;
function lua_isboolean(L: lua_State; n: Integer): Boolean; inline;
function lua_isthread(L: lua_State; n: Integer): Boolean; inline;
function lua_isnone(L: lua_State; n: Integer): Boolean; inline;
function lua_isnoneornil(L: lua_State; n: Integer): Boolean; inline;
procedure lua_pushliteral(L: lua_State; s: MarshaledAString); inline;
procedure lua_pushglobaltable(L: lua_State); inline;
function lua_tostring(L: lua_State; i: Integer): MarshaledAString;
procedure lua_insert(L: lua_State; idx: Integer); inline;
procedure lua_remove(L: lua_State; idx: Integer); inline;
procedure lua_replace(L: lua_State; idx: Integer); inline;
procedure luaL_newlibtable(L: lua_State; lr: array of luaL_Reg); overload;
procedure luaL_newlibtable(L: lua_State; lr: PluaL_Reg); overload;
procedure luaL_newlib(L: lua_State; lr: array of luaL_Reg); overload;
procedure luaL_newlib(L: lua_State; lr: PluaL_Reg); overload;
procedure luaL_argcheck(L: lua_State; cond: Boolean; arg: Integer; extramsg: MarshaledAString);
function luaL_checkstring(L: lua_State; n: Integer): MarshaledAString;
function luaL_optstring(L: lua_State; n: Integer; d: MarshaledAString): MarshaledAString;
function luaL_typename(L: lua_State; i: Integer): MarshaledAString;
function luaL_dofile(L: lua_State; const fn: MarshaledAString): Integer;
function luaL_dostring(L: lua_State; const s: MarshaledAString): Integer;
procedure luaL_getmetatable(L: lua_State; n: MarshaledAString);
function luaL_loadbuffer(L: lua_State; const s: MarshaledAString; sz: size_t; const n: MarshaledAString): Integer;
procedure lua_call(L: lua_State; nargs: Integer; nresults: Integer); inline;
function lua_pcall(L: lua_State; nargs: Integer; nresults: Integer; errfunc: Integer): Integer; inline;
function lua_yield(L: lua_State; nresults: Integer): Integer; inline;
function lua_upvalueindex(i: Integer): Integer; inline;
procedure luaL_checkversion(L: lua_State); inline;
function lual_loadfile(L: lua_State; const filename: MarshaledAString): Integer; inline;
function luaL_prepbuffer(b: Plual_Buffer): MarshaledAString; inline;

implementation

function lua_tonumber(L: lua_State; idx: Integer): lua_Number; inline;
begin
  Result := lua_tonumberx(L, idx, NIL);
end;

function lua_tointeger(L: lua_State; idx: Integer): lua_Integer; inline;
begin
  Result := lua_tointegerx(L, idx, NIL);
end;

procedure lua_pop(L: lua_State; n: Integer); inline;
begin
  lua_settop(L, -(n) - 1);
end;

procedure lua_newtable(L: lua_State); inline;
begin
  lua_createtable(L, 0, 0);
end;

procedure lua_register(L: lua_State; const n: MarshaledAString; f: lua_CFunction);
begin
  lua_pushcfunction(L, f);
  lua_setglobal(L, n);
end;

procedure lua_pushcfunction(L: lua_State; f: lua_CFunction);
begin
  lua_pushcclosure(L, f, 0);
end;

function lua_isfunction(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TFUNCTION);
end;

function lua_istable(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TTABLE);
end;

function lua_islightuserdata(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TLIGHTUSERDATA);
end;

function lua_isnil(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TNIL);
end;

function lua_isboolean(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TBOOLEAN);
end;

function lua_isthread(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TTHREAD);
end;

function lua_isnone(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) = LUA_TNONE);
end;

function lua_isnoneornil(L: lua_State; n: Integer): Boolean;
begin
  Result := (lua_type(L, n) <= 0);
end;

procedure lua_pushliteral(L: lua_State; s: MarshaledAString);
begin
  lua_pushlstring(L, s, Length(s));
end;

procedure lua_pushglobaltable(L: lua_State);
begin
  lua_rawgeti(L, LUA_REGISTRYINDEX, LUA_RIDX_GLOBALS);
end;

function lua_tostring(L: lua_State; i: Integer): MarshaledAString;
begin
  Result := lua_tolstring(L, i, NIL);
end;

procedure lua_insert(L: lua_State; idx: Integer);
begin
  lua_rotate(L, idx, 1);
end;

procedure lua_remove(L: lua_State; idx: Integer);
begin
  lua_rotate(L, idx, -1);
  lua_pop(L, 1);
end;

procedure lua_replace(L: lua_State; idx: Integer);
begin
  lua_copy(L, -1, idx);
  lua_pop(L, 1);
end;

procedure lua_call(L: lua_State; nargs: Integer; nresults: Integer); inline;
begin
  lua_callk(L, nargs, nresults, 0, NIL);
end;

function lua_pcall(L: lua_State; nargs: Integer; nresults: Integer; errfunc: Integer): Integer; inline;
begin
  Result := lua_pcallk(L, nargs, nresults, errfunc, 0, NIL);
end;

function lua_yield(L: lua_State; nresults: Integer): Integer; inline;
begin
  Result := lua_yieldk(L, nresults, 0, NIL);
end;

function lua_upvalueindex(i: Integer): Integer; inline;
begin
  Result := LUA_REGISTRYINDEX - i;
end;

procedure luaL_newlibtable(L: lua_State; lr: array of luaL_Reg); overload;
begin
  lua_createtable(L, 0, High(lr));
end;

procedure luaL_newlibtable(L: lua_State; lr: PluaL_Reg); overload;
var
  n: Integer;
begin
  n := 0;
  while lr^.name <> nil do
  begin
    inc(n);
    inc(lr);
  end;
  lua_createtable(L, 0, n);
end;

procedure luaL_newlib(L: lua_State; lr: array of luaL_Reg); overload;
begin
  luaL_newlibtable(L, lr);
  luaL_setfuncs(L, @lr, 0);
end;

procedure luaL_newlib(L: lua_State; lr: PluaL_Reg); overload;
begin
  luaL_newlibtable(L, lr);
  luaL_setfuncs(L, lr, 0);
end;

procedure luaL_argcheck(L: lua_State; cond: Boolean; arg: Integer; extramsg: MarshaledAString);
begin
  if not cond then
    luaL_argerror(L, arg, extramsg);
end;

function luaL_checkstring(L: lua_State; n: Integer): MarshaledAString;
begin
  Result := luaL_checklstring(L, n, nil);
end;

function luaL_optstring(L: lua_State; n: Integer; d: MarshaledAString): MarshaledAString;
begin
  Result := luaL_optlstring(L, n, d, nil);
end;

function luaL_typename(L: lua_State; i: Integer): MarshaledAString;
begin
  Result := lua_typename(L, lua_type(L, i));
end;

function luaL_dofile(L: lua_State; const fn: MarshaledAString): Integer;
begin
  Result := lual_loadfile(L, fn);
  if Result = 0 then
    Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;

function luaL_dostring(L: lua_State; const s: MarshaledAString): Integer;
begin
  Result := luaL_loadstring(L, s);
  if Result = 0 then
    Result := lua_pcall(L, 0, LUA_MULTRET, 0);
end;

procedure luaL_getmetatable(L: lua_State; n: MarshaledAString);
begin
  lua_getfield(L, LUA_REGISTRYINDEX, n);
end;

function luaL_loadbuffer(L: lua_State; const s: MarshaledAString; sz: size_t; const n: MarshaledAString): Integer;
begin
  Result := luaL_loadbufferx(L, s, sz, n, NIL);
end;

procedure luaL_checkversion(L: lua_State); inline;
begin
  luaL_checkversion_(L, LUA_VERSION_NUM, LUAL_NUMSIZES);
end;

function lual_loadfile(L: lua_State; const filename: MarshaledAString): Integer; inline;
begin
  Result := luaL_loadfilex(L, filename, NIL);
end;

function luaL_prepbuffer(b: Plual_Buffer): MarshaledAString; inline;
begin
  Result := luaL_prepbuffsize(b, LUAL_BUFFERSIZE);
end;

end.
