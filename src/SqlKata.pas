unit SqlKata;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections;

type
  EQueryException = class(Exception);
  TQuery = class;
  TQueryCallback = reference to function(Query: TQuery): TQuery;
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
    Query: TQuery;
    destructor Destroy; override;
    function Clone: TClause;
  end;

  TQuery = class
  private
    FClauses: TObjectList<TClause>;
    FVariables: TDictionary<string, TValue>;
    FOrFlag, FNot: Boolean;
    FComment: string;
    function Condition(const Component: string; IsOr, IsNot: Boolean;
      Kind: TClauseKind): TClause;
    function CallbackQuery(const Callback: TQueryCallback): TQuery;
    function DataPairs(Data: TObject; ConsiderKeys: Boolean): TArray<TPair<string,TValue>>;
  public
    EngineScope, QueryAlias, Method, JoinType: string;
    IsDistinct: Boolean;
    constructor Create(const Table: string = ''; const Comment: string = '');
    destructor Destroy; override;
    function Clone: TQuery; virtual;
    function NewQuery: TQuery; virtual;
    function CopyClausesFrom(Source: TQuery): TQuery;
    function Add(const Component: string; Kind: TClauseKind): TClause;
    procedure Remove(const Component, Engine: string);
    function GetOne(const Component, Engine: string): TClause;
    function GetComponents(const Component: string; const Engine: string = ''): TArray<TClause>;
    function HasComponent(const Component: string; const Engine: string = ''): Boolean;
    function ClearComponent(const Component: string; const Engine: string = ''): TQuery;
    function HasConditions(const Engine: string = ''): Boolean;
    function SetEngineScope(const Engine: string): TQuery;
    function &Or: TQuery;
    function &And: TQuery;
    function &Not(Flag: Boolean = True): TQuery;
    function &As(const Alias: string): TQuery;
    function Comment(const Text: string): TQuery;
    function GetComment: string;
    function &For(const Engine: string; const Callback: TQueryCallback): TQuery;
    function When(Condition: Boolean; const WhenTrue: TQueryCallback;
      const WhenFalse: TQueryCallback = nil): TQuery;
    function WhenNot(Condition: Boolean; const Callback: TQueryCallback): TQuery;
    function Define(const Name: string; const Value: TValue): TQuery;
    function FindVariable(const Name: string): TValue;
    function &From(const Table: string): TQuery; overload;
    function &From(Query: TQuery; const Alias: string = ''): TQuery; overload;
    function &From(const Callback: TQueryCallback; const Alias: string = ''): TQuery; overload;
    function Select(Query: TQuery; const Alias: string): TQuery; overload;
    function Select(const Callback: TQueryCallback; const Alias: string): TQuery; overload;
    function SelectAggregate(const Aggregate, Column: string; const Filter: TQueryCallback = nil): TQuery;
    function &With(const Alias: string; Query: TQuery): TQuery; overload;
    function &With(Query: TQuery): TQuery; overload;
    function &With(const Alias: string; const Callback: TQueryCallback): TQuery; overload;
    function &With(const Callback: TQueryCallback): TQuery; overload;
    function &With(const Alias: string; const Columns: array of string; const Rows: TRows): TQuery; overload;
    function WithRaw(const Alias, Sql: string; const Bindings: array of TValue): TQuery; overload;
    function WithRaw(const Alias, Sql: string): TQuery; overload;
    function Join(const Table, First, Second: string; const Op: string = '=';
      const JoinType: string = 'inner join'): TQuery; overload;
    function Join(const Table: string; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): TQuery; overload;
    function Join(Query: TQuery; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): TQuery; overload;
    function LeftJoin(const Table, First, Second: string; const Op: string = '='): TQuery; overload;
    function LeftJoin(const Table: string; const Callback: TQueryCallback): TQuery; overload;
    function LeftJoin(Query: TQuery; const Callback: TQueryCallback): TQuery; overload;
    function RightJoin(const Table, First, Second: string; const Op: string = '='): TQuery; overload;
    function RightJoin(const Table: string; const Callback: TQueryCallback): TQuery; overload;
    function RightJoin(Query: TQuery; const Callback: TQueryCallback): TQuery; overload;
    function CrossJoin(const Table: string): TQuery;
    function On(const First, Second: string; const Op: string = '='): TQuery;
    function OrOn(const First, Second: string; const Op: string = '='): TQuery;
    function JoinWith(const Table: string): TQuery; overload;
    function JoinWith(Query: TQuery; const Alias: string = ''): TQuery; overload;
    function JoinWithRaw(const Sql: string; const Bindings: array of TValue): TQuery;
    function AsType(const Value: string): TQuery;
    function AsInner: TQuery;
    function AsOuter: TQuery;
    function AsLeft: TQuery;
    function AsRight: TQuery;
    function AsCross: TQuery;
    function Limit(Value: Integer): TQuery;
    function Offset(Value: Int64): TQuery;
    function Take(Value: Integer): TQuery;
    function Skip(Value: Int64): TQuery;
    function ForPage(Page: Integer; PerPage: Integer = 15): TQuery;
    function GetLimit(const Engine: string = ''): Integer;
    function GetOffset(const Engine: string = ''): Int64;
    function HasLimit(const Engine: string = ''): Boolean;
    function HasOffset(const Engine: string = ''): Boolean;
    function Distinct: TQuery;
    function OrderByRandom: TQuery; overload;
    function OrderByRandom(Seed: Integer): TQuery; overload;
    function Combine(const Operation: string; All: Boolean; Query: TQuery): TQuery;
    function AsAggregate(const Aggregate: string; const Columns: array of string): TQuery;
    function AsInsert(const Columns: array of string; const Values: array of TValue): TQuery; overload;
    function AsInsert(const Columns: array of string; const Rows: TRows): TQuery; overload;
    function AsInsert(const Columns: array of string; Query: TQuery): TQuery; overload;
    function AsInsert(const Values: array of TPair<string,TValue>; ReturnId: Boolean = False): TQuery; overload;
    function AsInsert(Data: TObject; ReturnId: Boolean = False): TQuery; overload;
    function AsUpdate(const Columns: array of string; const Values: array of TValue): TQuery; overload;
    function AsUpdate(const Values: array of TPair<string,TValue>): TQuery; overload;
    function AsUpdate(Data: TObject): TQuery; overload;
    function AsDelete: TQuery;
    function AsIncrement(const Column: string; Value: Integer = 1): TQuery;
    function AsDecrement(const Column: string; Value: Integer = 1): TQuery;
    function Where(const Values: array of TPair<string,TValue>): TQuery; overload;
    function Where(Data: TObject): TQuery; overload;
    {$I SqlKata.Fluent.Declarations.inc}
    property Clauses: TObjectList<TClause> read FClauses;
    property Variables: TDictionary<string,TValue> read FVariables;
  end;

  // The fluent condition surface and join callbacks use the same owned model.
  TConditionGroup = TQuery;
  TJoin = TQuery;

function CopyValues(const Values: array of TValue): TValues;
function CopyStrings(const Values: array of string): TArray<string>;
function ExpandExpression(const Expression: string): TArray<string>;

implementation

uses System.StrUtils;

{$I SqlKata.Query.inc}
{$I SqlKata.Fluent.Implementation.inc}

end.

