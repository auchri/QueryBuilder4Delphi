unit SqlKata;

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

  TQueryObject = class(TInterfacedObject, IQuery)
  private
    FClauses: TObjectList<TClause>;
    FVariables: TDictionary<string, TValue>;
    FOrFlag, FNot: Boolean;
    FComment, FEngineScope, FQueryAlias, FMethod, FJoinType: string;
    FIsDistinct: Boolean;
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

    function Condition(const Component: string; IsOr, IsNot: Boolean;
      Kind: TClauseKind): TClause;
    function CallbackQuery(const Callback: TQueryCallback): IQuery;
    function DataPairs(Data: TObject; ConsiderKeys: Boolean): TArray<TPair<string,TValue>>;
  public
    constructor Create(const Table: string = ''; const Comment: string = '');
    destructor Destroy; override;
    function Clone: IQuery; virtual;
    function NewQuery: IQuery; virtual;
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

  TQuery = record
    class function Create(const Table: string = ''; const Comment: string = ''): IQuery; static;
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

implementation

uses System.StrUtils, System.Variants,
  QueryBuilder4Delphi.Query.Writes, QueryBuilder4Delphi.Query.DataMapper;

class function TSqlValues.&Of<T>(const Values: array of T): TValues;
var I: Integer;
begin
  SetLength(Result,Length(Values));
  for I := 0 to High(Values) do Result[I] := TValue.From<T>(Values[I]);
end;

class function TQuery.Create(const Table, Comment: string): IQuery;
begin Result := TQueryObject.Create(Table, Comment); end;

function TQueryObject.GetEngineScope: string;
begin Result := FEngineScope; end;
procedure TQueryObject.PutEngineScope(const Value: string);
begin FEngineScope := Value; end;
function TQueryObject.GetQueryAlias: string;
begin Result := FQueryAlias; end;
procedure TQueryObject.SetQueryAlias(const Value: string);
begin FQueryAlias := Value; end;
function TQueryObject.GetMethod: string;
begin Result := FMethod; end;
procedure TQueryObject.SetMethod(const Value: string);
begin FMethod := Value; end;
function TQueryObject.GetJoinType: string;
begin Result := FJoinType; end;
procedure TQueryObject.SetJoinType(const Value: string);
begin FJoinType := Value; end;
function TQueryObject.GetIsDistinct: Boolean;
begin Result := FIsDistinct; end;
procedure TQueryObject.SetIsDistinct(const Value: Boolean);
begin FIsDistinct := Value; end;
function TQueryObject.GetClauses: TObjectList<TClause>;
begin Result := FClauses; end;
function TQueryObject.GetVariables: TDictionary<string,TValue>;
begin Result := FVariables; end;

function TQueryObject.AsAggregate(const Aggregate: string; const Columns: array of string): IQuery;
begin
  Result := TQueryWrites.AsAggregate(Self, Aggregate, Columns);
end;

function TQueryObject.AsInsert(const Columns: array of string; const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Values);
end;

function TQueryObject.AsInsert(const Columns: array of string; const Rows: TRows): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Rows);
end;

function TQueryObject.AsInsert(const Columns: array of string; Query: IQuery): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Query);
end;

function TQueryObject.AsInsert(const Values: array of TPair<string,TValue>; ReturnId: Boolean): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Values, ReturnId);
end;

function TQueryObject.AsUpdate(const Columns: array of string; const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsUpdate(Self, Columns, Values);
end;

function TQueryObject.AsUpdate(const Values: array of TPair<string,TValue>): IQuery;
begin
  Result := TQueryWrites.AsUpdate(Self, Values);
end;

function TQueryObject.AsDelete: IQuery;
begin
  Result := TQueryWrites.AsDelete(Self);
end;

function TQueryObject.AsIncrement(const Column: string; Value: Integer): IQuery;
begin
  Result := TQueryWrites.AsIncrement(Self, Column, Value);
end;

function TQueryObject.AsDecrement(const Column: string; Value: Integer): IQuery;
begin
  Result := TQueryWrites.AsDecrement(Self, Column, Value);
end;

function TQueryObject.DataPairs(Data: TObject; ConsiderKeys: Boolean): TArray<TPair<string,TValue>>;
begin
  if ConsiderKeys then
    Result := TQueryDataMapper.GetPairs(Data,
      procedure(Name: string; Value: TValue)
      begin
        Where(Name, Value);
      end)
  else
    Result := TQueryDataMapper.GetPairs(Data);
end;

function TQueryObject.AsInsert(Data: TObject; ReturnId: Boolean): IQuery;
begin Result := AsInsert(DataPairs(Data, False), ReturnId); end;

function TQueryObject.AsUpdate(Data: TObject): IQuery;
begin Result := AsUpdate(DataPairs(Data, True)); end;

function TQueryObject.Where(const Values: array of TPair<string,TValue>): IQuery;
var Pair: TPair<string,TValue>; OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag; NotFlag := FNot;
  for Pair in Values do begin FOrFlag := OrFlag; FNot := NotFlag; Where(Pair.Key, Pair.Value); end;
  Result := Self;
end;

function TQueryObject.Where(Data: TObject): IQuery;
begin Result := Where(DataPairs(Data, False)); end;

function TQueryObject.Having(const Values: array of TPair<string,TValue>): IQuery;
var Pair: TPair<string,TValue>; OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag; NotFlag := FNot;
  for Pair in Values do begin FOrFlag := OrFlag; FNot := NotFlag; Having(Pair.Key, Pair.Value); end;
  Result := Self;
end;

function TQueryObject.Having(Data: TObject): IQuery;
begin Result := Having(DataPairs(Data, False)); end;

function TQueryObject.AsInsert(Data: TDictionary<string,TValue>; ReturnId: Boolean): IQuery;
begin
  if Data = nil then raise EArgumentNilException.Create('Data');
  Result := AsInsert(Data.ToArray,ReturnId);
end;

function TQueryObject.AsUpdate(Data: TDictionary<string,TValue>): IQuery;
begin
  if Data = nil then raise EArgumentNilException.Create('Data');
  Result := AsUpdate(Data.ToArray);
end;

function TQueryObject.Where(Data: TDictionary<string,TValue>): IQuery;
begin
  if Data = nil then raise EArgumentNilException.Create('Data');
  Result := Where(Data.ToArray);
end;

function TQueryObject.Having(Data: TDictionary<string,TValue>): IQuery;
begin
  if Data = nil then raise EArgumentNilException.Create('Data');
  Result := Having(Data.ToArray);
end;

{$I SqlKata.Query.inc}
{$I SqlKata.Fluent.Implementation.inc}

end.

