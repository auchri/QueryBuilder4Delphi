unit QueryBuilder4Delphi.Query.Core;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections;

type
  EQueryException = class(Exception);
{$SCOPEDENUMS ON}
  TSqlDialect = (MSSql, MySql, PostgreSql, Sqlite, Oracle, Firebird);
{$SCOPEDENUMS OFF}

  TSqlDialectHelper = record helper for TSqlDialect
    function EngineCode: string;
  end;

  IQuery = interface;
  TQueryExecutionMode = (emAuto, emRows, emCommand);

  // Cursor starts before the first row; indices are zero based.
  // NULL is TValue.Empty. RowsAffected = -1 means unknown.
  IQueryResult = interface
    ['{09A2718A-2A84-4E10-9C65-E85FB4EF2508}']
    function Next: Boolean;
    function GetHasResultSet: Boolean;
    function GetRowsAffected: Int64;
    function GetColumnCount: Integer;
    function GetColumnName(Index: Integer): string;
    function GetColumnIndex(const Name: string): Integer;
    function GetValue(Index: Integer): TValue; overload;
    function GetValue(const Name: string): TValue; overload;
    function IsNull(Index: Integer): Boolean;
    property HasResultSet: Boolean read GetHasResultSet;
    property RowsAffected: Int64 read GetRowsAffected;
    property ColumnCount: Integer read GetColumnCount;
    property ColumnNames[Index: Integer]: string read GetColumnName;
  end;

  IQueryExecutor = interface
    ['{6793FB16-8CA0-4785-AB75-63C8DE7BC09A}']
    function Execute(const Query: IQuery; Mode: TQueryExecutionMode = emAuto)
      : IQueryResult;
  end;

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

  TClauseKind = (ckIdentifier, ckRaw, ckBasic, ckNull, ckBoolean, ckColumns,
    ckString, ckDate, ckBetween, ckIn, ckInQuery, ckQuery, ckSubQuery, ckNested,
    ckExists, ckJoin, ckCombine, ckLimit, ckOffset, ckAggregate, ckInsert,
    ckIncrement, ckRandom, ckAdHoc);

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
    ['{408F2E7B-CA64-4B3A-B88D-972214A15CAA}']
    function Execute(const Executor: IQueryExecutor;
      Mode: TQueryExecutionMode = emAuto): IQueryResult;
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
    function GetVariables: TDictionary<string, TValue>;
    function Clone: IQuery;
    function NewQuery: IQuery;
    function Compile(Dialect: TSqlDialect = TSqlDialect.MSSql): string;
    function CopyClausesFrom(Source: IQuery): IQuery;
    function Add(const Component: string; Kind: TClauseKind): TClause;
    procedure Remove(const Component, Engine: string);
    function GetOne(const Component, Engine: string): TClause;
    function GetComponents(const Component: string; const Engine: string = '')
      : TArray<TClause>;
    function HasComponent(const Component: string;
      const Engine: string = ''): Boolean;
    function ClearComponent(const Component: string;
      const Engine: string = ''): IQuery;
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
    function WhenNot(Condition: Boolean;
      const Callback: TQueryCallback): IQuery;
    function Define(const Name: string; const Value: TValue): IQuery;
    function FindVariable(const Name: string): TValue;
    function &From(const Table: string): IQuery; overload;
    function &From(Query: IQuery; const Alias: string = ''): IQuery; overload;
    function &From(const Callback: TQueryCallback; const Alias: string = '')
      : IQuery; overload;
    function Select(Query: IQuery; const Alias: string): IQuery; overload;
    function Select(const Callback: TQueryCallback; const Alias: string)
      : IQuery; overload;
    function SelectAggregate(const Aggregate, Column: string;
      const Filter: TQueryCallback = nil): IQuery; overload;
    function SelectAggregate(const Aggregate, Column: string; Filter: IQuery)
      : IQuery; overload;
    function &With(const Alias: string; Query: IQuery): IQuery; overload;
    function &With(Query: IQuery): IQuery; overload;
    function &With(const Alias: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function &With(const Callback: TQueryCallback): IQuery; overload;
    function &With(const Alias: string; const Columns: array of string;
      const Rows: TRows): IQuery; overload;
    function WithRaw(const Alias, Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function WithRaw(const Alias, Sql: string): IQuery; overload;
    function Join(const Table, First, Second: string; const Op: string = '=';
      const JoinType: string = 'inner join'): IQuery; overload;
    function Join(const Table: string; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    function Join(Query: IQuery; const Callback: TQueryCallback;
      const JoinType: string = 'inner join'): IQuery; overload;
    function LeftJoin(const Table, First, Second: string;
      const Op: string = '='): IQuery; overload;
    function LeftJoin(const Table: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function LeftJoin(Query: IQuery; const Callback: TQueryCallback)
      : IQuery; overload;
    function RightJoin(const Table, First, Second: string;
      const Op: string = '='): IQuery; overload;
    function RightJoin(const Table: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function RightJoin(Query: IQuery; const Callback: TQueryCallback)
      : IQuery; overload;
    function CrossJoin(const Table: string): IQuery;
    function On(const First, Second: string; const Op: string = '='): IQuery;
    function OrOn(const First, Second: string; const Op: string = '='): IQuery;
    function JoinWith(const Table: string): IQuery; overload;
    function JoinWith(Query: IQuery; const Alias: string = ''): IQuery;
      overload;
    function JoinWith(const Callback: TQueryCallback; const Alias: string = '')
      : IQuery; overload;
    function JoinWithRaw(const Sql: string;
      const Bindings: array of TValue): IQuery;
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
    function Combine(const Operation: string; All: Boolean;
      Query: IQuery): IQuery;
    function AsAggregate(const Aggregate: string;
      const Columns: array of string): IQuery;
    function AsInsert(const Columns: array of string;
      const Values: array of TValue): IQuery; overload;
    function AsInsert(const Columns: array of string; const Rows: TRows)
      : IQuery; overload;
    function AsInsert(const Columns: array of string; Query: IQuery)
      : IQuery; overload;
    function AsInsert(const Values: array of TPair<string, TValue>;
      ReturnId: Boolean = False): IQuery; overload;
    function AsInsert(Data: TObject; ReturnId: Boolean = False)
      : IQuery; overload;
    function AsInsert(Data: TDictionary<string, TValue>;
      ReturnId: Boolean = False): IQuery; overload;
    function AsUpdate(const Columns: array of string;
      const Values: array of TValue): IQuery; overload;
    function AsUpdate(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    function AsUpdate(Data: TObject): IQuery; overload;
    function AsUpdate(Data: TDictionary<string, TValue>): IQuery; overload;
    function AsDelete: IQuery;
    function AsIncrement(const Column: string; Value: Integer = 1): IQuery;
    function AsDecrement(const Column: string; Value: Integer = 1): IQuery;
    function Where(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    function Where(Data: TObject): IQuery; overload;
    function Where(Data: TDictionary<string, TValue>): IQuery; overload;
    function Having(const Values: array of TPair<string, TValue>)
      : IQuery; overload;
    function Having(Data: TObject): IQuery; overload;
    function Having(Data: TDictionary<string, TValue>): IQuery; overload;
    // BEGIN GENERATED: fluent declarations
    function Where(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function Where(const Column: string; const Value: TValue): IQuery; overload;
    function Where(Group: IQuery): IQuery; overload;
    function Where(const Callback: TQueryCallback): IQuery; overload;
    function Where(const Column, Op: string; Query: IQuery): IQuery; overload;
    function Where(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function WhereNull(const Column: string): IQuery;
    function WhereTrue(const Column: string): IQuery;
    function WhereFalse(const Column: string): IQuery;
    function WhereBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function WhereIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function WhereIn(const Column: string; Query: IQuery): IQuery; overload;
    function WhereIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function WhereExists(Query: IQuery): IQuery; overload;
    function WhereExists(const Callback: TQueryCallback): IQuery; overload;
    function WhereLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereDatePart(const Part, Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereNot(Group: IQuery): IQuery; overload;
    function WhereNot(const Callback: TQueryCallback): IQuery; overload;
    function WhereNot(const Column, Op: string; Query: IQuery): IQuery;
      overload;
    function WhereNot(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function WhereNotNull(const Column: string): IQuery;
    function WhereNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function WhereNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function WhereNotIn(const Column: string; Query: IQuery): IQuery; overload;
    function WhereNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function WhereNotExists(Query: IQuery): IQuery; overload;
    function WhereNotExists(const Callback: TQueryCallback): IQuery; overload;
    function WhereNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function WhereNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function WhereNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function WhereRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function WhereRaw(const Sql: string): IQuery; overload;
    function WhereColumns(const First, Op, Second: string): IQuery;
    function WhereSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    function WhereSub(Query: IQuery; const Value: TValue): IQuery; overload;
    function OrWhere(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhere(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhere(Group: IQuery): IQuery; overload;
    function OrWhere(const Callback: TQueryCallback): IQuery; overload;
    function OrWhere(const Column, Op: string; Query: IQuery): IQuery; overload;
    function OrWhere(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrWhereNull(const Column: string): IQuery;
    function OrWhereTrue(const Column: string): IQuery;
    function OrWhereFalse(const Column: string): IQuery;
    function OrWhereBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function OrWhereIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function OrWhereIn(const Column: string; Query: IQuery): IQuery; overload;
    function OrWhereIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrWhereExists(Query: IQuery): IQuery; overload;
    function OrWhereExists(const Callback: TQueryCallback): IQuery; overload;
    function OrWhereLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function OrWhereDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNot(Group: IQuery): IQuery; overload;
    function OrWhereNot(const Callback: TQueryCallback): IQuery; overload;
    function OrWhereNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    function OrWhereNot(const Column, Op: string;
      const Callback: TQueryCallback): IQuery; overload;
    function OrWhereNotNull(const Column: string): IQuery;
    function OrWhereNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function OrWhereNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function OrWhereNotIn(const Column: string; Query: IQuery): IQuery;
      overload;
    function OrWhereNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrWhereNotExists(Query: IQuery): IQuery; overload;
    function OrWhereNotExists(const Callback: TQueryCallback): IQuery; overload;
    function OrWhereNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrWhereNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function OrWhereNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function OrWhereRaw(const Sql: string): IQuery; overload;
    function OrWhereColumns(const First, Op, Second: string): IQuery;
    function OrWhereSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    function OrWhereSub(Query: IQuery; const Value: TValue): IQuery; overload;
    function Having(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function Having(const Column: string; const Value: TValue): IQuery;
      overload;
    function Having(Group: IQuery): IQuery; overload;
    function Having(const Callback: TQueryCallback): IQuery; overload;
    function Having(const Column, Op: string; Query: IQuery): IQuery; overload;
    function Having(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function HavingNull(const Column: string): IQuery;
    function HavingTrue(const Column: string): IQuery;
    function HavingFalse(const Column: string): IQuery;
    function HavingBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function HavingIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function HavingIn(const Column: string; Query: IQuery): IQuery; overload;
    function HavingIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function HavingExists(Query: IQuery): IQuery; overload;
    function HavingExists(const Callback: TQueryCallback): IQuery; overload;
    function HavingLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingDatePart(const Part, Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingNot(Group: IQuery): IQuery; overload;
    function HavingNot(const Callback: TQueryCallback): IQuery; overload;
    function HavingNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    function HavingNot(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function HavingNotNull(const Column: string): IQuery;
    function HavingNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function HavingNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function HavingNotIn(const Column: string; Query: IQuery): IQuery; overload;
    function HavingNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function HavingNotExists(Query: IQuery): IQuery; overload;
    function HavingNotExists(const Callback: TQueryCallback): IQuery; overload;
    function HavingNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function HavingNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function HavingNotDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function HavingRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function HavingRaw(const Sql: string): IQuery; overload;
    function HavingColumns(const First, Op, Second: string): IQuery;
    function HavingSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    function HavingSub(Query: IQuery; const Value: TValue): IQuery; overload;
    function OrHaving(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHaving(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHaving(Group: IQuery): IQuery; overload;
    function OrHaving(const Callback: TQueryCallback): IQuery; overload;
    function OrHaving(const Column, Op: string; Query: IQuery): IQuery;
      overload;
    function OrHaving(const Column, Op: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrHavingNull(const Column: string): IQuery;
    function OrHavingTrue(const Column: string): IQuery;
    function OrHavingFalse(const Column: string): IQuery;
    function OrHavingBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function OrHavingIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function OrHavingIn(const Column: string; Query: IQuery): IQuery; overload;
    function OrHavingIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrHavingExists(Query: IQuery): IQuery; overload;
    function OrHavingExists(const Callback: TQueryCallback): IQuery; overload;
    function OrHavingLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function OrHavingDatePart(const Part, Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNot(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNot(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNot(Group: IQuery): IQuery; overload;
    function OrHavingNot(const Callback: TQueryCallback): IQuery; overload;
    function OrHavingNot(const Column, Op: string; Query: IQuery)
      : IQuery; overload;
    function OrHavingNot(const Column, Op: string;
      const Callback: TQueryCallback): IQuery; overload;
    function OrHavingNotNull(const Column: string): IQuery;
    function OrHavingNotBetween(const Column: string;
      const Lower, Higher: TValue): IQuery;
    function OrHavingNotIn(const Column: string; const Values: array of TValue)
      : IQuery; overload;
    function OrHavingNotIn(const Column: string; Query: IQuery)
      : IQuery; overload;
    function OrHavingNotIn(const Column: string; const Callback: TQueryCallback)
      : IQuery; overload;
    function OrHavingNotExists(Query: IQuery): IQuery; overload;
    function OrHavingNotExists(const Callback: TQueryCallback): IQuery;
      overload;
    function OrHavingNotLike(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingNotStarts(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingNotEnds(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingNotContains(const Column: string; const Value: TValue;
      const EscapeCharacter: string = ''): IQuery;
    function OrHavingNotDate(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNotDate(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNotTime(const Column, Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNotTime(const Column: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingNotDatePart(const Part, Column, Op: string;
      const Value: TValue): IQuery; overload;
    function OrHavingNotDatePart(const Part, Column: string;
      const Value: TValue): IQuery; overload;
    function OrHavingRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function OrHavingRaw(const Sql: string): IQuery; overload;
    function OrHavingColumns(const First, Op, Second: string): IQuery;
    function OrHavingSub(Query: IQuery; const Op: string; const Value: TValue)
      : IQuery; overload;
    function OrHavingSub(Query: IQuery; const Value: TValue): IQuery; overload;
    function Select(const Columns: array of string): IQuery; overload;
    function Select(const Column: string): IQuery; overload;
    function GroupBy(const Columns: array of string): IQuery; overload;
    function GroupBy(const Column: string): IQuery; overload;
    function OrderBy(const Columns: array of string): IQuery; overload;
    function OrderBy(const Column: string): IQuery; overload;
    function OrderByDesc(const Columns: array of string): IQuery; overload;
    function OrderByDesc(const Column: string): IQuery; overload;
    function SelectRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function SelectRaw(const Sql: string): IQuery; overload;
    function FromRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function FromRaw(const Sql: string): IQuery; overload;
    function OrderByRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function OrderByRaw(const Sql: string): IQuery; overload;
    function GroupByRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function GroupByRaw(const Sql: string): IQuery; overload;
    function CombineRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function CombineRaw(const Sql: string): IQuery; overload;
    function UnionRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function UnionRaw(const Sql: string): IQuery; overload;
    function ExceptRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function ExceptRaw(const Sql: string): IQuery; overload;
    function IntersectRaw(const Sql: string; const Bindings: array of TValue)
      : IQuery; overload;
    function IntersectRaw(const Sql: string): IQuery; overload;
    function AsCount(const Columns: array of string): IQuery; overload;
    function AsCount(): IQuery; overload;
    function AsSum(const Column: string): IQuery;
    function AsAvg(const Column: string): IQuery;
    function AsAverage(const Column: string): IQuery;
    function AsMin(const Column: string): IQuery;
    function AsMax(const Column: string): IQuery;
    function SelectSum(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    function SelectCount(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    function SelectAvg(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    function SelectMin(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    function SelectMax(const Column: string;
      const Filter: TQueryCallback = nil): IQuery;
    function Union(Query: IQuery; All: Boolean = False): IQuery; overload;
    function Union(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    function UnionAll(Query: IQuery): IQuery; overload;
    function UnionAll(const Callback: TQueryCallback): IQuery; overload;
    function &Except(Query: IQuery; All: Boolean = False): IQuery; overload;
    function &Except(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    function ExceptAll(Query: IQuery): IQuery; overload;
    function ExceptAll(const Callback: TQueryCallback): IQuery; overload;
    function Intersect(Query: IQuery; All: Boolean = False): IQuery; overload;
    function Intersect(const Callback: TQueryCallback; All: Boolean = False)
      : IQuery; overload;
    function IntersectAll(Query: IQuery): IQuery; overload;
    function IntersectAll(const Callback: TQueryCallback): IQuery; overload;
    function ForSqlServer(const Callback: TQueryCallback): IQuery;
    function ForPostgreSql(const Callback: TQueryCallback): IQuery;
    function ForMySql(const Callback: TQueryCallback): IQuery;
    function ForSqlite(const Callback: TQueryCallback): IQuery;
    function ForOracle(const Callback: TQueryCallback): IQuery;
    function ForFirebird(const Callback: TQueryCallback): IQuery;
    // END GENERATED: fluent declarations
    property EngineScope: string read GetEngineScope write PutEngineScope;
    property QueryAlias: string read GetQueryAlias write SetQueryAlias;
    property Method: string read GetMethod write SetMethod;
    property JoinType: string read GetJoinType write SetJoinType;
    property IsDistinct: Boolean read GetIsDistinct write SetIsDistinct;
    property Clauses: TObjectList<TClause> read GetClauses;
    property Variables: TDictionary<string, TValue> read GetVariables;
  end;

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

function TSqlDialectHelper.EngineCode: string;
const
  Codes: array [TSqlDialect] of string = ('sqlsrv', 'mysql', 'postgres',
    'sqlite', 'oracle', 'firebird');
begin
  Result := Codes[Self];
end;

class function TSqlValues.&Of<T>(const Values: array of T): TValues;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := TValue.From<T>(Values[I]);
end;

function CopyValues(const Values: array of TValue): TValues;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function EqualValues(const A, B: TValue): Boolean;
begin
  if A.TypeInfo <> B.TypeInfo then
    Exit(False);
  if A.IsEmpty then
    Exit(True);
  case A.Kind of
    tkInteger, tkInt64, tkEnumeration:
      Result := A.AsOrdinal = B.AsOrdinal;
    tkFloat:
      Result := A.AsExtended = B.AsExtended;
    tkString, tkLString, tkWString, tkUString:
      Result := A.AsString = B.AsString;
    tkVariant:
      Result := VarSameValue(A.AsVariant, B.AsVariant);
    tkClass:
      Result := A.AsObject = B.AsObject;
  else
    Result := False;
  end;
end;

function DistinctValues(const Values: array of TValue): TValues;
var
  List: TList<TValue>;
  V, Other: TValue;
  Found: Boolean;
begin
  List := TList<TValue>.Create;
  try
    for V in Values do
    begin
      Found := False;
      for Other in List do
        if EqualValues(V, Other) then
        begin
          Found := True;
          Break;
        end;
      if not Found then
        List.Add(V);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function CopyStrings(const Values: array of string): TArray<string>;
var
  I: Integer;
begin
  SetLength(Result, Length(Values));
  for I := 0 to High(Values) do
    Result[I] := Values[I];
end;

function ExpandExpression(const Expression: string): TArray<string>;
var
  P, I: Integer;
  Prefix: string;
begin
  P := Pos('.{', Expression);
  if (P = 0) or not Expression.EndsWith('}') then
  begin
    Result := TArray<string>.Create(Expression);
    Exit;
  end;
  Prefix := Copy(Expression, 1, P);
  Result := Copy(Expression, P + 2, Length(Expression) - P - 2).Split([',']);
  for I := 0 to High(Result) do
    Result[I] := Prefix + Trim(Result[I]);
end;

constructor TUnsafeLiteral.Create(const AValue: string; ReplaceQuotes: Boolean);
begin
  Value := AValue;
  if ReplaceQuotes then
    Value := StringReplace(Value, '''', '''''', [rfReplaceAll]);
end;

class operator TUnsafeLiteral.Implicit(const Literal: TUnsafeLiteral): TValue;
begin
  Result := TValue.From<TUnsafeLiteral>(Literal);
end;

constructor TVariable.Create(const AName: string);
begin
  Name := AName;
end;

class operator TVariable.Implicit(const Variable: TVariable): TValue;
begin
  Result := TValue.From<TVariable>(Variable);
end;

constructor ColumnAttribute.Create(const AName: string);
begin
  inherited Create;
  Name := AName;
end;

function TClause.Clone: TClause;
begin
  Result := TClause.Create;
  try
    Result.Component := Component;
    Result.Engine := Engine;
    Result.Kind := Kind;
    Result.Name := Name;
    Result.Op := Op;
    Result.Extra := Extra;
    Result.Alias := Alias;
    Result.IsOr := IsOr;
    Result.IsNot := IsNot;
    Result.ReturnId := ReturnId;
    Result.Value := Value;
    Result.Value2 := Value2;
    Result.Values := Copy(Values);
    Result.Columns := Copy(Columns);
    if Query <> nil then
      Result.Query := Query.Clone;
  except
    Result.Free;
    raise;
  end;
end;

end.
