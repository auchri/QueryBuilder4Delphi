unit QueryBuilder4Delphi.Query.Core;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections;

type
  EQueryException = class(Exception);
  IQuery = interface;
  TQueryCallback = reference to function(Query: IQuery): IQuery;
  TValues = TArray<TValue>;
  TRows = TArray<TValues>;

  // Value records avoid ownership surprises in parameter lists.
  TUnsafeLiteral = record
    Value: string;
    constructor Create(const AValue: string; ReplaceQuotes: Boolean = True);
    class operator Implicit(const Literal: TUnsafeLiteral): TValue;
  end;
  TVariable = record
    Name: string;
    constructor Create(const AName: string);
    class operator Implicit(const Variable: TVariable): TValue;
  end;

  ColumnAttribute = class(TCustomAttribute)
  public
    Name: string;
    constructor Create(const AName: string);
  end;
  KeyAttribute = class(ColumnAttribute);
  IgnoreAttribute = class(TCustomAttribute);

  TClauseKind = (ckIdentifier, ckRaw, ckBasic, ckNull, ckBoolean,
    ckColumns, ckString, ckDate, ckBetween, ckIn, ckInQuery, ckQuery,
    ckSubQuery, ckNested, ckExists, ckJoin, ckCombine, ckLimit,
    ckOffset, ckAggregate, ckInsert, ckIncrement, ckRandom, ckAdHoc);

  TClause = class
  public
    Component, Engine, Name, Op, Extra, Alias: string;
    Kind: TClauseKind;
    IsOr, IsNot, ReturnId: Boolean;
    Value, Value2: TValue;
    Values: TValues;
    Columns: TArray<string>;
    Query: IQuery;
    function Clone: TClause;
  end;

  IQuery = interface
    ['{03A7DA22-0598-40E2-95FB-462812EDCA03}']
    function GetEngineScope: string;
    procedure PutEngineScope(const Value: string);
    function GetQueryAlias: string;
    procedure SetQueryAlias(const Value: string);
    function GetMethod: string;
    procedure SetMethod(const Value: string);
    function GetJoinType: string;
    procedure SetJoinType(const Value: string);
    function GetIsDistinct: Boolean;
    procedure SetIsDistinct(const Value: Boolean);
    function GetClauses: TObjectList<TClause>;
    function GetVariables: TDictionary<string,TValue>;
    function Clone: IQuery;
    function NewQuery: IQuery;
    function CopyClausesFrom(Source: IQuery): IQuery;
    function Add(const Component: string; Kind: TClauseKind): TClause;
    procedure Remove(const Component, Engine: string);
    function GetOne(const Component, Engine: string): TClause;
    function GetComponents(const Component: string; const Engine: string = ''): TArray<TClause>;
    function HasComponent(const Component: string; const Engine: string = ''): Boolean;
    function ClearComponent(const Component: string; const Engine: string = ''): IQuery;
    function HasConditions(const Engine: string = ''): Boolean;
    function SetEngineScope(const Engine: string): IQuery;
    function &Or: IQuery;
    function &And: IQuery;
    function &Not(Flag: Boolean = True): IQuery;
    function &As(const Alias: string): IQuery;
    function Comment(const Text: string): IQuery;
    function GetComment: string;
    function &For(const Engine: string; const Callback: TQueryCallback): IQuery;
    function When(Condition: Boolean; const WhenTrue: TQueryCallback;
      const WhenFalse: TQueryCallback = nil): IQuery;
    function WhenNot(Condition: Boolean; const Callback: TQueryCallback): IQuery;
    function Define(const Name: string; const Value: TValue): IQuery;
    function FindVariable(const Name: string): TValue;
    function &From(const Table: string): IQuery; overload;
    function &From(Query: IQuery; const Alias: string = ''): IQuery; overload;
    function &From(const Callback: TQueryCallback; const Alias: string = ''): IQuery; overload;
    function Select(Query: IQuery; const Alias: string): IQuery; overload;
    function Select(const Callback: TQueryCallback; const Alias: string): IQuery; overload;
    function SelectAggregate(const Aggregate, Column: string; const Filter: TQueryCallback = nil): IQuery; overload;
    function SelectAggregate(const Aggregate, Column: string; Filter: IQuery): IQuery; overload;
    function &With(const Alias: string; Query: IQuery): IQuery; overload;
    function &With(Query: IQuery): IQuery; overload;
    function &With(const Alias: string; const Callback: TQueryCallback): IQuery; overload;
    function &With(const Callback: TQueryCallback): IQuery; overload;
    function &With(const Alias: string; const Columns: array of string; const Rows: TRows): IQuery; overload;
    function WithRaw(const Alias, Sql: string; const Bindings: array of TValue): IQuery; overload;
    function WithRaw(const Alias, Sql: string): IQuery; overload;
    function Join(const Table, First, Second: string; const Op: string = '=';
      const JoinType: string = 'inner join'): IQuery; overload;
    function Join(const Table: string; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    function Join(Query: IQuery; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    function LeftJoin(const Table, First, Second: string; const Op: string = '='): IQuery; overload;
    function LeftJoin(const Table: string; const Callback: TQueryCallback): IQuery; overload;
    function LeftJoin(Query: IQuery; const Callback: TQueryCallback): IQuery; overload;
    function RightJoin(const Table, First, Second: string; const Op: string = '='): IQuery; overload;
    function RightJoin(const Table: string; const Callback: TQueryCallback): IQuery; overload;
    function RightJoin(Query: IQuery; const Callback: TQueryCallback): IQuery; overload;
    function CrossJoin(const Table: string): IQuery;
    function On(const First, Second: string; const Op: string = '='): IQuery;
    function OrOn(const First, Second: string; const Op: string = '='): IQuery;
    function JoinWith(const Table: string): IQuery; overload;
    function JoinWith(Query: IQuery; const Alias: string = ''): IQuery; overload;
    function JoinWith(const Callback: TQueryCallback; const Alias: string = ''): IQuery; overload;
    function JoinWithRaw(const Sql: string; const Bindings: array of TValue): IQuery;
    function AsType(const Value: string): IQuery;
    function AsInner: IQuery;
    function AsOuter: IQuery;
    function AsLeft: IQuery;
    function AsRight: IQuery;
    function AsCross: IQuery;
    function Limit(Value: Integer): IQuery;
    function Offset(Value: Int64): IQuery;
    function Take(Value: Integer): IQuery;
    function Skip(Value: Int64): IQuery;
    function ForPage(Page: Integer; PerPage: Integer = 15): IQuery;
    function GetLimit(const Engine: string = ''): Integer;
    function GetOffset(const Engine: string = ''): Int64;
    function HasLimit(const Engine: string = ''): Boolean;
    function HasOffset(const Engine: string = ''): Boolean;
    function Distinct: IQuery;
    function OrderByRandom: IQuery; overload;
    function OrderByRandom(Seed: Integer): IQuery; overload;
    function Combine(const Operation: string; All: Boolean; Query: IQuery): IQuery;
    function AsAggregate(const Aggregate: string; const Columns: array of string): IQuery;
    function AsInsert(const Columns: array of string; const Values: array of TValue): IQuery; overload;
    function AsInsert(const Columns: array of string; const Rows: TRows): IQuery; overload;
    function AsInsert(const Columns: array of string; Query: IQuery): IQuery; overload;
    function AsInsert(const Values: array of TPair<string,TValue>; ReturnId: Boolean = False): IQuery; overload;
    function AsInsert(Data: TObject; ReturnId: Boolean = False): IQuery; overload;
    function AsInsert(Data: TDictionary<string,TValue>; ReturnId: Boolean = False): IQuery; overload;
    function AsUpdate(const Columns: array of string; const Values: array of TValue): IQuery; overload;
    function AsUpdate(const Values: array of TPair<string,TValue>): IQuery; overload;
    function AsUpdate(Data: TObject): IQuery; overload;
    function AsUpdate(Data: TDictionary<string,TValue>): IQuery; overload;
    function AsDelete: IQuery;
    function AsIncrement(const Column: string; Value: Integer = 1): IQuery;
    function AsDecrement(const Column: string; Value: Integer = 1): IQuery;
    function Where(const Values: array of TPair<string,TValue>): IQuery; overload;
    function Where(Data: TObject): IQuery; overload;
    function Where(Data: TDictionary<string,TValue>): IQuery; overload;
    function Having(const Values: array of TPair<string,TValue>): IQuery; overload;
    function Having(Data: TObject): IQuery; overload;
    function Having(Data: TDictionary<string,TValue>): IQuery; overload;
    {$I SqlKata.Fluent.Declarations.inc}
    property EngineScope: string read GetEngineScope write PutEngineScope;
    property QueryAlias: string read GetQueryAlias write SetQueryAlias;
    property Method: string read GetMethod write SetMethod;
    property JoinType: string read GetJoinType write SetJoinType;
    property IsDistinct: Boolean read GetIsDistinct write SetIsDistinct;
    property Clauses: TObjectList<TClause> read GetClauses;
    property Variables: TDictionary<string,TValue> read GetVariables;
  end;

  // Condition and join callbacks share the reference-counted query model.
  IConditionGroup = IQuery;
  TConditionGroup = IQuery;
  IJoin = IQuery;
  TJoin = IQuery;

  TSqlValues = record
    class function &Of<T>(const Values: array of T): TValues; static;
  end;

function CopyValues(const Values: array of TValue): TValues;
function CopyStrings(const Values: array of string): TArray<string>;
function ExpandExpression(const Expression: string): TArray<string>;
function DistinctValues(const Values: array of TValue): TValues;

implementation

uses
  System.Variants;

class function TSqlValues.&Of<T>(const Values: array of T): TValues;
var I: Integer;
begin
  SetLength(Result,Length(Values));
  for I := 0 to High(Values) do Result[I] := TValue.From<T>(Values[I]);
end;

function CopyValues(const Values: array of TValue): TValues;
var I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do Result[I] := Values[I];
end;

function EqualValues(const A, B: TValue): Boolean;
begin
  if A.TypeInfo <> B.TypeInfo then Exit(False);
  if A.IsEmpty then Exit(True);
  case A.Kind of
    tkInteger, tkInt64, tkEnumeration: Result := A.AsOrdinal = B.AsOrdinal;
    tkFloat: Result := A.AsExtended = B.AsExtended;
    tkString, tkLString, tkWString, tkUString: Result := A.AsString = B.AsString;
    tkVariant: Result := VarSameValue(A.AsVariant,B.AsVariant);
    tkClass: Result := A.AsObject = B.AsObject;
  else Result := False; end;
end;

function DistinctValues(const Values: array of TValue): TValues;
var List: TList<TValue>; V, Other: TValue; Found: Boolean;
begin
  List := TList<TValue>.Create;
  try
    for V in Values do
    begin
      Found := False;
      for Other in List do if EqualValues(V, Other) then begin Found := True; Break; end;
      if not Found then List.Add(V);
    end;
    Result := List.ToArray;
  finally List.Free; end;
end;

function CopyStrings(const Values: array of string): TArray<string>;
var I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do Result[I] := Values[I];
end;

function ExpandExpression(const Expression: string): TArray<string>;
var P, I: Integer; Prefix: string;
begin
  P := Pos('.{', Expression);
  if (P = 0) or not Expression.EndsWith('}') then begin Result := TArray<string>.Create(Expression); Exit; end;
  Prefix := Copy(Expression, 1, P);
  Result := Copy(Expression, P+2, Length(Expression)-P-2).Split([',']);
  for I := 0 to High(Result) do Result[I] := Prefix + Trim(Result[I]);
end;

constructor TUnsafeLiteral.Create(const AValue: string; ReplaceQuotes: Boolean);
begin
  Value := AValue;
  if ReplaceQuotes then Value := StringReplace(Value, '''', '''''', [rfReplaceAll]);
end;

class operator TUnsafeLiteral.Implicit(const Literal: TUnsafeLiteral): TValue;
begin Result := TValue.From<TUnsafeLiteral>(Literal); end;

constructor TVariable.Create(const AName: string);
begin Name := AName; end;

class operator TVariable.Implicit(const Variable: TVariable): TValue;
begin Result := TValue.From<TVariable>(Variable); end;

constructor ColumnAttribute.Create(const AName: string);
begin inherited Create; Name := AName; end;

function TClause.Clone: TClause;
begin
  Result := TClause.Create;
  try
    Result.Component := Component; Result.Engine := Engine; Result.Kind := Kind;
    Result.Name := Name; Result.Op := Op; Result.Extra := Extra; Result.Alias := Alias;
    Result.IsOr := IsOr; Result.IsNot := IsNot; Result.ReturnId := ReturnId;
    Result.Value := Value; Result.Value2 := Value2;
    Result.Values := Copy(Values); Result.Columns := Copy(Columns);
    if Query <> nil then Result.Query := Query.Clone;
  except Result.Free; raise; end;
end;

end.
