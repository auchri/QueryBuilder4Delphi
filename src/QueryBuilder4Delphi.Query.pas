unit QueryBuilder4Delphi.Query;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core;

type
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
    function GetVariables: TDictionary<string, TValue>;

    function Condition(const Component: string; IsOr, IsNot: Boolean;
      Kind: TClauseKind): TClause;
    function CallbackQuery(const Callback: TQueryCallback): IQuery;
    function DataPairs(Data: TObject; ConsiderKeys: Boolean)
      : TArray<TPair<string, TValue>>;
  public
    constructor Create(const Table: string = ''; const Comment: string = '');
    destructor Destroy; override;
    function Execute(const Executor: IQueryExecutor;
      Mode: TQueryExecutionMode = emAuto): IQueryResult;
    function Clone: IQuery; virtual;
    function NewQuery: IQuery; virtual;
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

  TQuery = record
    class function Create(const Table: string = ''; const Comment: string = '')
      : IQuery; static;
  end;

implementation

uses
  System.StrUtils, QueryBuilder4Delphi.Query.Writes,
  QueryBuilder4Delphi.Query.DataMapper,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory;

class function TQuery.Create(const Table, Comment: string): IQuery;
begin
  Result := TQueryObject.Create(Table, Comment);
end;

function TQueryObject.Compile(Dialect: TSqlDialect): string;
var
  Compiler: ICompiler;
begin
  Compiler := TQueryCompilerFactory.CreateCompiler(Dialect);
  Result := Compiler.Compile(Self).ToString;
end;

function TQueryObject.GetEngineScope: string;
begin
  Result := FEngineScope;
end;

procedure TQueryObject.PutEngineScope(const Value: string);
begin
  FEngineScope := Value;
end;

function TQueryObject.GetQueryAlias: string;
begin
  Result := FQueryAlias;
end;

procedure TQueryObject.SetQueryAlias(const Value: string);
begin
  FQueryAlias := Value;
end;

function TQueryObject.GetMethod: string;
begin
  Result := FMethod;
end;

procedure TQueryObject.SetMethod(const Value: string);
begin
  FMethod := Value;
end;

function TQueryObject.GetJoinType: string;
begin
  Result := FJoinType;
end;

procedure TQueryObject.SetJoinType(const Value: string);
begin
  FJoinType := Value;
end;

function TQueryObject.GetIsDistinct: Boolean;
begin
  Result := FIsDistinct;
end;

procedure TQueryObject.SetIsDistinct(const Value: Boolean);
begin
  FIsDistinct := Value;
end;

function TQueryObject.GetClauses: TObjectList<TClause>;
begin
  Result := FClauses;
end;

function TQueryObject.GetVariables: TDictionary<string, TValue>;
begin
  Result := FVariables;
end;

constructor TQueryObject.Create(const Table, Comment: string);
begin
  inherited Create;
  FClauses := TObjectList<TClause>.Create(True);
  FVariables := TDictionary<string, TValue>.Create;
  Method := 'select';
  JoinType := 'INNER JOIN';
  FComment := Comment;
  if Table <> '' then
    &From(Table);
end;

destructor TQueryObject.Destroy;
begin
  FVariables.Free;
  FClauses.Free;
  inherited;
end;

function TQueryObject.Clone: IQuery;
var
  Pair: TPair<string, TValue>;
begin
  Result := NewQuery;
  Result.CopyClausesFrom(Self);
  Result.EngineScope := EngineScope;
  Result.QueryAlias := QueryAlias;
  Result.Method := Method;
  Result.JoinType := JoinType;
  Result.IsDistinct := IsDistinct;
  Result.Comment(FComment);
  for Pair in FVariables do
    Result.Variables.Add(Pair.Key, Pair.Value);
end;

function TQueryObject.CopyClausesFrom(Source: IQuery): IQuery;
var
  C: TClause;
begin
  if Source = (Self as IQuery) then
    Exit(Self);
  FClauses.Clear;
  for C in Source.Clauses do
    FClauses.Add(C.Clone);
  Result := Self;
end;

function TQueryObject.Execute(const Executor: IQueryExecutor;
  Mode: TQueryExecutionMode): IQueryResult;
var
  Query: IQuery;
begin
  Query := Self;
  if Executor = nil then
    raise EArgumentNilException.Create('Executor');
  Result := Executor.Execute(Query, Mode);
end;

function TQueryObject.NewQuery: IQuery;
begin
  Result := TQuery.Create;
end;

function TQueryObject.Add(const Component: string; Kind: TClauseKind): TClause;
begin
  Result := TClause.Create;
  Result.Component := Component;
  Result.Kind := Kind;
  Result.Engine := EngineScope;
  FClauses.Add(Result);
end;

procedure TQueryObject.Remove(const Component, Engine: string);
var
  I: Integer;
begin
  for I := FClauses.Count - 1 downto 0 do
    if (FClauses[I].Component = Component) and (FClauses[I].Engine = Engine)
    then
      FClauses.Delete(I);
end;

function TQueryObject.GetOne(const Component, Engine: string): TClause;
var
  C: TClause;
begin
  Result := nil;
  for C in FClauses do
    if C.Component = Component then
    begin
      if C.Engine = Engine then
        Exit(C);
      if (C.Engine = '') and (Result = nil) then
        Result := C;
    end;
end;

function TQueryObject.GetComponents(const Component, Engine: string)
  : TArray<TClause>;
var
  C: TClause;
  List: TList<TClause>;
begin
  List := TList<TClause>.Create;
  try
    for C in FClauses do
      if (C.Component = Component) and
        ((C.Engine = '') or (C.Engine = Engine) or (Engine = '')) then
        List.Add(C);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TQueryObject.HasComponent(const Component, Engine: string): Boolean;
begin
  Result := Length(GetComponents(Component, Engine)) > 0;
end;

function TQueryObject.ClearComponent(const Component, Engine: string): IQuery;
var
  I: Integer;
  E: string;
begin
  E := Engine;
  if E = '' then
    E := EngineScope;
  for I := FClauses.Count - 1 downto 0 do
    if (FClauses[I].Component = Component) and
      ((E = '') or (FClauses[I].Engine = '') or (FClauses[I].Engine = E)) then
      FClauses.Delete(I);
  Result := Self;
end;

function TQueryObject.HasConditions(const Engine: string): Boolean;
begin
  Result := HasComponent('where', Engine);
end;

function TQueryObject.Condition(const Component: string; IsOr, IsNot: Boolean;
  Kind: TClauseKind): TClause;
begin
  Result := Add(Component, Kind);
  Result.IsOr := IsOr or FOrFlag;
  Result.IsNot := IsNot or FNot;
  FOrFlag := False;
  FNot := False;
end;

function TQueryObject.CallbackQuery(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  if not Assigned(Callback) then
    raise EArgumentNilException.Create('Callback');
  Q := NewQuery;
  Q.EngineScope := EngineScope;
  if Callback(Q) <> Q then
    raise EQueryException.Create('Callback must return its supplied query');
  Result := Q;
end;

function TQueryObject.SetEngineScope(const Engine: string): IQuery;
begin
  EngineScope := Engine;
  Result := Self;
end;

function TQueryObject.&Or: IQuery;
begin
  FOrFlag := True;
  Result := Self;
end;

function TQueryObject.&And: IQuery;
begin
  FOrFlag := False;
  Result := Self;
end;

function TQueryObject.&Not(Flag: Boolean): IQuery;
begin
  FNot := Flag;
  Result := Self;
end;

function TQueryObject.&As(const Alias: string): IQuery;
begin
  QueryAlias := Alias;
  Result := Self;
end;

function TQueryObject.Comment(const Text: string): IQuery;
begin
  FComment := Text;
  Result := Self;
end;

function TQueryObject.GetComment: string;
begin
  Result := FComment;
end;

function TQueryObject.&For(const Engine: string;
  const Callback: TQueryCallback): IQuery;
var
  Previous: string;
begin
  Previous := EngineScope;
  EngineScope := Engine;
  try
    Result := Callback(Self);
    if Result <> (Self as IQuery) then
      raise EQueryException.Create('Callback must return its supplied query');
  finally
    EngineScope := Previous;
  end;
end;

function TQueryObject.When(Condition: Boolean;
  const WhenTrue, WhenFalse: TQueryCallback): IQuery;
begin
  Result := Self;
  if Condition and Assigned(WhenTrue) then
    Result := WhenTrue(Self)
  else if not Condition and Assigned(WhenFalse) then
    Result := WhenFalse(Self);
  if Result <> (Self as IQuery) then
    raise EQueryException.Create('Callback must return its supplied query');
end;

function TQueryObject.WhenNot(Condition: Boolean;
  const Callback: TQueryCallback): IQuery;
begin
  Result := When(not Condition, Callback);
end;

function TQueryObject.Define(const Name: string; const Value: TValue): IQuery;
begin
  FVariables.Add(Name, Value);
  Result := Self;
end;

function TQueryObject.FindVariable(const Name: string): TValue;
begin
  if not FVariables.TryGetValue(Name, Result) then
    raise EQueryException.CreateFmt('Variable ''%s'' not found', [Name]);
end;

function TQueryObject.&From(const Table: string): IQuery;
begin
  Remove('from', EngineScope);
  Add('from', ckIdentifier).Name := Table;
  Result := Self;
end;

function TQueryObject.&From(Query: IQuery; const Alias: string): IQuery;
var
  C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckQuery);
  C.Query := Query.Clone;
  if Alias <> '' then
    C.Query.&As(Alias);
  Result := Self;
end;

function TQueryObject.&From(const Callback: TQueryCallback;
  const Alias: string): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &From(Q, Alias);
end;

function TQueryObject.Select(Query: IQuery; const Alias: string): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckQuery);
  C.Query := Query.Clone.&As(Alias);
  Method := 'select';
  Result := Self;
end;

function TQueryObject.Select(const Callback: TQueryCallback;
  const Alias: string): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Select(Q, Alias);
end;

function TQueryObject.SelectAggregate(const Aggregate, Column: string;
  const Filter: TQueryCallback): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckAggregate);
  C.Op := Aggregate;
  C.Name := Column;
  if Assigned(Filter) then
    C.Query := CallbackQuery(Filter);
  Method := 'select';
  Result := Self;
end;

function TQueryObject.SelectAggregate(const Aggregate, Column: string;
  Filter: IQuery): IQuery;
var
  C: TClause;
begin
  C := Add('select', ckAggregate);
  C.Op := Aggregate;
  C.Name := Column;
  if Filter <> nil then
    C.Query := Filter.Clone;
  Method := 'select';
  Result := Self;
end;

function TQueryObject.&With(const Alias: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  if Trim(Alias) = '' then
    raise EQueryException.Create('No alias found for CTE');
  C := Add('cte', ckQuery);
  C.Alias := Trim(Alias);
  C.Query := Query.Clone;
  C.Query.QueryAlias := '';
  Result := Self;
end;

function TQueryObject.&With(Query: IQuery): IQuery;
begin
  Result := &With(Query.QueryAlias, Query);
end;

function TQueryObject.&With(const Alias: string;
  const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &With(Alias, Q);
end;

function TQueryObject.&With(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &With(Q);
end;

function TQueryObject.&With(const Alias: string; const Columns: array of string;
  const Rows: TRows): IQuery;
var
  C: TClause;
  Row: TValues;
  V: TValue;
  List: TList<TValue>;
begin
  if (Length(Columns) = 0) or (Length(Rows) = 0) then
    raise EQueryException.Create('Columns and rows cannot be empty');
  for Row in Rows do
    if Length(Row) <> Length(Columns) then
      raise EQueryException.Create('Column/value count mismatch');
  C := Add('cte', ckAdHoc);
  C.Alias := Alias;
  C.Columns := CopyStrings(Columns);
  List := TList<TValue>.Create;
  try
    for Row in Rows do
      for V in Row do
        List.Add(V);
    C.Values := List.ToArray;
  finally
    List.Free;
  end;
  Result := Self;
end;

function TQueryObject.WithRaw(const Alias, Sql: string;
  const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('cte', ckRaw);
  C.Alias := Alias;
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.WithRaw(const Alias, Sql: string): IQuery;
begin
  Result := WithRaw(Alias, Sql, []);
end;

function TQueryObject.Join(const Table, First, Second, Op,
  JoinType: string): IQuery;
var
  C: TClause;
begin
  C := Add('join', ckJoin);
  C.Query := NewQuery;
  C.Query.&From(Table).WhereColumns(First, Op, Second).AsType(JoinType);
  Result := Self;
end;

function TQueryObject.Join(const Table: string; const Callback: TQueryCallback;
  const JoinType: string): IQuery;
var
  C: TClause;
  Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone;
  Q.ClearComponent('where');
  C := Q.Add('where', ckNested);
  C.Query := Group;
  Q.&From(Table).AsType(JoinType);
  C := Add('join', ckJoin);
  C.Query := Q;

  Result := Self;
end;

function TQueryObject.Join(Query: IQuery; const Callback: TQueryCallback;
  const JoinType: string): IQuery;
var
  C: TClause;
  Q, Group: IQuery;
begin
  Q := CallbackQuery(Callback);
  Group := Q.Clone;
  Q.ClearComponent('where');
  C := Q.Add('where', ckNested);
  C.Query := Group;
  Q.&From(Query).AsType(JoinType);
  C := Add('join', ckJoin);
  C.Query := Q;

  Result := Self;
end;

function TQueryObject.LeftJoin(const Table, First, Second, Op: string): IQuery;
begin
  Result := Join(Table, First, Second, Op, 'left join');
end;

function TQueryObject.LeftJoin(const Table: string;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Table, Callback, 'left join');
end;

function TQueryObject.LeftJoin(Query: IQuery;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Query, Callback, 'left join');
end;

function TQueryObject.RightJoin(const Table, First, Second, Op: string): IQuery;
begin
  Result := Join(Table, First, Second, Op, 'right join');
end;

function TQueryObject.RightJoin(const Table: string;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Table, Callback, 'right join');
end;

function TQueryObject.RightJoin(Query: IQuery;
  const Callback: TQueryCallback): IQuery;
begin
  Result := Join(Query, Callback, 'right join');
end;

function TQueryObject.CrossJoin(const Table: string): IQuery;
var
  C: TClause;
begin
  C := Add('join', ckJoin);
  C.Query := NewQuery.&From(Table).AsCross;
  Result := Self;
end;

function TQueryObject.On(const First, Second, Op: string): IQuery;
begin
  Result := WhereColumns(First, Op, Second);
end;

function TQueryObject.OrOn(const First, Second, Op: string): IQuery;
begin
  Result := OrWhereColumns(First, Op, Second);
end;

function TQueryObject.JoinWith(const Table: string): IQuery;
begin
  Result := &From(Table);
end;

function TQueryObject.JoinWith(Query: IQuery; const Alias: string): IQuery;
begin
  Result := &From(Query, Alias);
end;

function TQueryObject.JoinWith(const Callback: TQueryCallback;
  const Alias: string): IQuery;
begin
  Result := &From(Callback, Alias);
end;

function TQueryObject.JoinWithRaw(const Sql: string;
  const Bindings: array of TValue): IQuery;
begin
  Result := FromRaw(Sql, Bindings);
end;

function TQueryObject.AsType(const Value: string): IQuery;
begin
  JoinType := UpperCase(Value);
  Result := Self;
end;

function TQueryObject.AsInner: IQuery;
begin
  Result := AsType('inner join');
end;

function TQueryObject.AsOuter: IQuery;
begin
  Result := AsType('outer join');
end;

function TQueryObject.AsLeft: IQuery;
begin
  Result := AsType('left join');
end;

function TQueryObject.AsRight: IQuery;
begin
  Result := AsType('right join');
end;

function TQueryObject.AsCross: IQuery;
begin
  Result := AsType('cross join');
end;

function TQueryObject.Limit(Value: Integer): IQuery;
begin
  Remove('limit', EngineScope);
  Add('limit', ckLimit).Value := Value;
  Result := Self;
end;

function TQueryObject.Offset(Value: Int64): IQuery;
begin
  Remove('offset', EngineScope);
  Add('offset', ckOffset).Value := Value;
  Result := Self;
end;

function TQueryObject.Take(Value: Integer): IQuery;
begin
  Result := Limit(Value);
end;

function TQueryObject.Skip(Value: Int64): IQuery;
begin
  Result := Offset(Value);
end;

function TQueryObject.ForPage(Page, PerPage: Integer): IQuery;
begin
  Result := Offset(Int64(Page - 1) * PerPage).Limit(PerPage);
end;

function TQueryObject.GetLimit(const Engine: string): Integer;
var
  C: TClause;
begin
  C := GetOne('limit', Engine);
  Result := 0;
  if C <> nil then
    Result := C.Value.AsInteger;
  if Result < 0 then
    Result := 0;
end;

function TQueryObject.GetOffset(const Engine: string): Int64;
var
  C: TClause;
begin
  C := GetOne('offset', Engine);
  Result := 0;
  if C <> nil then
    Result := C.Value.AsInt64;
  if Result < 0 then
    Result := 0;
end;

function TQueryObject.HasLimit(const Engine: string): Boolean;
begin
  Result := GetLimit(Engine) > 0;
end;

function TQueryObject.HasOffset(const Engine: string): Boolean;
begin
  Result := GetOffset(Engine) > 0;
end;

function TQueryObject.Distinct: IQuery;
begin
  IsDistinct := True;
  Result := Self;
end;

function TQueryObject.OrderByRandom: IQuery;
begin
  Add('order', ckRandom);
  Result := Self;
end;

function TQueryObject.OrderByRandom(Seed: Integer): IQuery;
begin
  Add('order', ckRandom).Value := Seed;
  Result := Self;
end;

function TQueryObject.Combine(const Operation: string; All: Boolean;
  Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Method <> 'select') or (Query.Method <> 'select') then
    raise EQueryException.Create('Only select queries can be combined');
  if not MatchText(Operation, ['union', 'except', 'intersect']) then
    raise EQueryException.Create('Invalid combine operation');
  C := Add('combine', ckCombine);
  C.Op := Operation;
  C.IsNot := All;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.AsAggregate(const Aggregate: string;
  const Columns: array of string): IQuery;
begin
  Result := TQueryWrites.AsAggregate(Self, Aggregate, Columns);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Values);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  const Rows: TRows): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Rows);
end;

function TQueryObject.AsInsert(const Columns: array of string;
  Query: IQuery): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Columns, Query);
end;

function TQueryObject.AsInsert(const Values: array of TPair<string, TValue>;
  ReturnId: Boolean): IQuery;
begin
  Result := TQueryWrites.AsInsert(Self, Values, ReturnId);
end;

function TQueryObject.AsUpdate(const Columns: array of string;
  const Values: array of TValue): IQuery;
begin
  Result := TQueryWrites.AsUpdate(Self, Columns, Values);
end;

function TQueryObject.AsUpdate(const Values
  : array of TPair<string, TValue>): IQuery;
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

function TQueryObject.DataPairs(Data: TObject; ConsiderKeys: Boolean)
  : TArray<TPair<string, TValue>>;
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
begin
  Result := AsInsert(DataPairs(Data, False), ReturnId);
end;

function TQueryObject.AsUpdate(Data: TObject): IQuery;
begin
  Result := AsUpdate(DataPairs(Data, True));
end;

function TQueryObject.Where(const Values: array of TPair<string,
  TValue>): IQuery;
var
  Pair: TPair<string, TValue>;
  OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag;
  NotFlag := FNot;
  for Pair in Values do
  begin
    FOrFlag := OrFlag;
    FNot := NotFlag;
    Where(Pair.Key, Pair.Value);
  end;
  Result := Self;
end;

function TQueryObject.Where(Data: TObject): IQuery;
begin
  Result := Where(DataPairs(Data, False));
end;

function TQueryObject.Having(const Values
  : array of TPair<string, TValue>): IQuery;
var
  Pair: TPair<string, TValue>;
  OrFlag, NotFlag: Boolean;
begin
  OrFlag := FOrFlag;
  NotFlag := FNot;
  for Pair in Values do
  begin
    FOrFlag := OrFlag;
    FNot := NotFlag;
    Having(Pair.Key, Pair.Value);
  end;
  Result := Self;
end;

function TQueryObject.Having(Data: TObject): IQuery;
begin
  Result := Having(DataPairs(Data, False));
end;

function TQueryObject.AsInsert(Data: TDictionary<string, TValue>;
ReturnId: Boolean): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := AsInsert(Data.ToArray, ReturnId);
end;

function TQueryObject.AsUpdate(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := AsUpdate(Data.ToArray);
end;

function TQueryObject.Where(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := Where(Data.ToArray);
end;

function TQueryObject.Having(Data: TDictionary<string, TValue>): IQuery;
begin
  if Data = nil then
    raise EArgumentNilException.Create('Data');
  Result := Having(Data.ToArray);
end;

// BEGIN GENERATED: fluent implementation
function TQueryObject.Where(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.Where(const Column: string; const Value: TValue): IQuery;

begin
  Result := Where(Column, '=', Value);
end;

function TQueryObject.Where(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Q);
end;

function TQueryObject.Where(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Where(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Where(Column, Op, Q);
end;

function TQueryObject.WhereNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.WhereFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.WhereBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereIn(Column, Q);
end;

function TQueryObject.WhereExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereExists(Q);
end;

function TQueryObject.WhereLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereDate(Column, '=', Value);
end;

function TQueryObject.WhereTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereTime(Column, '=', Value);
end;

function TQueryObject.WhereDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNot(Column, '=', Value);
end;

function TQueryObject.WhereNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Q);
end;

function TQueryObject.WhereNot(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNot(Column, Op, Q);
end;

function TQueryObject.WhereNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.WhereNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotIn(Column, Q);
end;

function TQueryObject.WhereNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.WhereNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := WhereNotExists(Q);
end;

function TQueryObject.WhereNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.WhereNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotDate(Column, '=', Value);
end;

function TQueryObject.WhereNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.WhereNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotTime(Column, '=', Value);
end;

function TQueryObject.WhereNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.WhereNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := WhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.WhereRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.WhereRaw(const Sql: string): IQuery;

begin
  Result := WhereRaw(Sql, []);
end;

function TQueryObject.WhereColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', False, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.WhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := WhereSub(Query, '=', Value);
end;

function TQueryObject.OrWhere(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhere(Column, '=', Value);
end;

function TQueryObject.OrWhere(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Q);
end;

function TQueryObject.OrWhere(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhere(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhere(Column, Op, Q);
end;

function TQueryObject.OrWhereNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.OrWhereFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.OrWhereBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereIn(Column, Q);
end;

function TQueryObject.OrWhereExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereExists(Q);
end;

function TQueryObject.OrWhereLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereDate(Column, '=', Value);
end;

function TQueryObject.OrWhereTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereTime(Column, '=', Value);
end;

function TQueryObject.OrWhereDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNot(Column, '=', Value);
end;

function TQueryObject.OrWhereNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Q);
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNot(Column, Op, Q);
end;

function TQueryObject.OrWhereNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrWhereNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotIn(Column, Q);
end;

function TQueryObject.OrWhereNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('where', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrWhereNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrWhereNotExists(Q);
end;

function TQueryObject.OrWhereNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotStarts(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrWhereNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotDate(Column, '=', Value);
end;

function TQueryObject.OrWhereNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrWhereNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotTime(Column, '=', Value);
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrWhereNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrWhereNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrWhereRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrWhereRaw(const Sql: string): IQuery;

begin
  Result := OrWhereRaw(Sql, []);
end;

function TQueryObject.OrWhereColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('where', True, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrWhereSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrWhereSub(Query, '=', Value);
end;

function TQueryObject.Having(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.Having(const Column: string; const Value: TValue): IQuery;

begin
  Result := Having(Column, '=', Value);
end;

function TQueryObject.Having(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Q);
end;

function TQueryObject.Having(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.Having(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Having(Column, Op, Q);
end;

function TQueryObject.HavingNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.HavingFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.HavingBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingIn(Column, Q);
end;

function TQueryObject.HavingExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingExists(Q);
end;

function TQueryObject.HavingLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingContains(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingDate(Column, '=', Value);
end;

function TQueryObject.HavingTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingTime(Column, '=', Value);
end;

function TQueryObject.HavingDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNot(Column, '=', Value);
end;

function TQueryObject.HavingNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Q);
end;

function TQueryObject.HavingNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNot(Column, Op, Q);
end;

function TQueryObject.HavingNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.HavingNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotIn(Column, Q);
end;

function TQueryObject.HavingNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', False, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.HavingNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := HavingNotExists(Q);
end;

function TQueryObject.HavingNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.HavingNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotDate(Column, '=', Value);
end;

function TQueryObject.HavingNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.HavingNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotTime(Column, '=', Value);
end;

function TQueryObject.HavingNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.HavingNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := HavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.HavingRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.HavingRaw(const Sql: string): IQuery;

begin
  Result := HavingRaw(Sql, []);
end;

function TQueryObject.HavingColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', False, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.HavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := HavingSub(Query, '=', Value);
end;

function TQueryObject.OrHaving(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHaving(Column, '=', Value);
end;

function TQueryObject.OrHaving(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Q);
end;

function TQueryObject.OrHaving(const Column, Op: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHaving(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHaving(Column, Op, Q);
end;

function TQueryObject.OrHavingNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingTrue(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column;
  C.Value := True;
  Result := Self;
end;

function TQueryObject.OrHavingFalse(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBoolean);
  C.Name := Column;
  C.Value := False;
  Result := Self;
end;

function TQueryObject.OrHavingBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string; Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingIn(Column, Q);
end;

function TQueryObject.OrHavingExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, False, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingExists(Q);
end;

function TQueryObject.OrHavingLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingStarts(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingDate(Column, '=', Value);
end;

function TQueryObject.OrHavingTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingTime(Column, '=', Value);
end;

function TQueryObject.OrHavingDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckBasic);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNot(Column, '=', Value);
end;

function TQueryObject.OrHavingNot(Group: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckNested);
  C.Query := Group.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Q);
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckQuery);
  C.Name := Column;
  C.Op := Op;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNot(const Column, Op: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNot(Column, Op, Q);
end;

function TQueryObject.OrHavingNotNull(const Column: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckNull);
  C.Name := Column;
  Result := Self;
end;

function TQueryObject.OrHavingNotBetween(const Column: string;
const Lower, Higher: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckBetween);
  C.Name := Column;
  C.Value := Lower;
  C.Value2 := Higher;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
const Values: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckIn);
  C.Name := Column;
  C.Values := DistinctValues(Values);
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
Query: IQuery): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckInQuery);
  C.Name := Column;
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotIn(const Column: string;
const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotIn(Column, Q);
end;

function TQueryObject.OrHavingNotExists(Query: IQuery): IQuery;
var
  C: TClause;
begin
  if (Query = nil) or not Query.HasComponent('from') then
    raise EQueryException.Create('EXISTS requires a FROM clause');
  C := Condition('having', True, True, ckExists);
  C.Query := Query.Clone;
  Result := Self;
end;

function TQueryObject.OrHavingNotExists(const Callback: TQueryCallback): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := OrHavingNotExists(Q);
end;

function TQueryObject.OrHavingNotLike(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'like';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotStarts(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'starts';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotEnds(const Column: string; const Value: TValue;
const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'ends';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotContains(const Column: string;
const Value: TValue; const EscapeCharacter: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckString);
  C.Name := Column;
  C.Value := Value;
  C.Op := 'contains';
  C.Extra := EscapeCharacter;
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'date';
  Result := Self;
end;

function TQueryObject.OrHavingNotDate(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotDate(Column, '=', Value);
end;

function TQueryObject.OrHavingNotTime(const Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := 'time';
  Result := Self;
end;

function TQueryObject.OrHavingNotTime(const Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotTime(Column, '=', Value);
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column, Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, True, ckDate);
  C.Name := Column;
  C.Op := Op;
  C.Value := Value;
  C.Extra := Part;
  Result := Self;
end;

function TQueryObject.OrHavingNotDatePart(const Part, Column: string;
const Value: TValue): IQuery;

begin
  Result := OrHavingNotDatePart(Part, Column, '=', Value);
end;

function TQueryObject.OrHavingRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrHavingRaw(const Sql: string): IQuery;

begin
  Result := OrHavingRaw(Sql, []);
end;

function TQueryObject.OrHavingColumns(const First, Op, Second: string): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckColumns);
  C.Name := First;
  C.Op := Op;
  C.Extra := Second;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Op: string;
const Value: TValue): IQuery;
var
  C: TClause;
begin
  C := Condition('having', True, False, ckSubQuery);
  C.Query := Query.Clone;
  C.Op := Op;
  C.Value := Value;
  Result := Self;
end;

function TQueryObject.OrHavingSub(Query: IQuery; const Value: TValue): IQuery;

begin
  Result := OrHavingSub(Query, '=', Value);
end;

function TQueryObject.Select(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('select', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Method := 'select';
  Result := Self;
end;

function TQueryObject.Select(const Column: string): IQuery;

begin
  Result := Select([Column]);
end;

function TQueryObject.GroupBy(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('group', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.GroupBy(const Column: string): IQuery;

begin
  Result := GroupBy([Column]);
end;

function TQueryObject.OrderBy(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier);
      C.Name := E;
      C.IsNot := False;
    end;
  Result := Self;
end;

function TQueryObject.OrderBy(const Column: string): IQuery;

begin
  Result := OrderBy([Column]);
end;

function TQueryObject.OrderByDesc(const Columns: array of string): IQuery;
var
  S, E: string;
  C: TClause;
begin
  for S in Columns do
    for E in ExpandExpression(S) do
    begin
      C := Add('order', ckIdentifier);
      C.Name := E;
      C.IsNot := True;
    end;
  Result := Self;
end;

function TQueryObject.OrderByDesc(const Column: string): IQuery;

begin
  Result := OrderByDesc([Column]);
end;

function TQueryObject.SelectRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  Method := 'select';
  C := Add('select', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.SelectRaw(const Sql: string): IQuery;

begin
  Result := SelectRaw(Sql, []);
end;

function TQueryObject.FromRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  Remove('from', EngineScope);
  C := Add('from', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.FromRaw(const Sql: string): IQuery;

begin
  Result := FromRaw(Sql, []);
end;

function TQueryObject.OrderByRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('order', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.OrderByRaw(const Sql: string): IQuery;

begin
  Result := OrderByRaw(Sql, []);
end;

function TQueryObject.GroupByRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  C := Add('group', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.GroupByRaw(const Sql: string): IQuery;

begin
  Result := GroupByRaw(Sql, []);
end;

function TQueryObject.CombineRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.CombineRaw(const Sql: string): IQuery;

begin
  Result := CombineRaw(Sql, []);
end;

function TQueryObject.UnionRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.UnionRaw(const Sql: string): IQuery;

begin
  Result := UnionRaw(Sql, []);
end;

function TQueryObject.ExceptRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.ExceptRaw(const Sql: string): IQuery;

begin
  Result := ExceptRaw(Sql, []);
end;

function TQueryObject.IntersectRaw(const Sql: string;
const Bindings: array of TValue): IQuery;
var
  C: TClause;
begin
  if Method <> 'select' then
    raise EQueryException.Create('Only select queries can be combined');
  C := Add('combine', ckRaw);
  C.Name := Sql;
  C.Values := CopyValues(Bindings);
  Result := Self;
end;

function TQueryObject.IntersectRaw(const Sql: string): IQuery;

begin
  Result := IntersectRaw(Sql, []);
end;

function TQueryObject.AsCount(const Columns: array of string): IQuery;

begin
  if Length(Columns) = 0 then
    Result := AsAggregate('count', ['*'])
  else
    Result := AsAggregate('count', Columns);
end;

function TQueryObject.AsCount(): IQuery;

begin
  Result := AsCount([]);
end;

function TQueryObject.AsSum(const Column: string): IQuery;

begin
  Result := AsAggregate('sum', [Column]);
end;

function TQueryObject.AsAvg(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsAverage(const Column: string): IQuery;

begin
  Result := AsAggregate('avg', [Column]);
end;

function TQueryObject.AsMin(const Column: string): IQuery;

begin
  Result := AsAggregate('min', [Column]);
end;

function TQueryObject.AsMax(const Column: string): IQuery;

begin
  Result := AsAggregate('max', [Column]);
end;

function TQueryObject.SelectSum(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('sum', Column, Filter);
end;

function TQueryObject.SelectCount(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('count', Column, Filter);
end;

function TQueryObject.SelectAvg(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('avg', Column, Filter);
end;

function TQueryObject.SelectMin(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('min', Column, Filter);
end;

function TQueryObject.SelectMax(const Column: string;
const Filter: TQueryCallback): IQuery;

begin
  Result := SelectAggregate('max', Column, Filter);
end;

function TQueryObject.Union(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('union', All, Query);
end;

function TQueryObject.Union(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Union(Q, All);
end;

function TQueryObject.UnionAll(Query: IQuery): IQuery;

begin
  Result := Union(Query, True);
end;

function TQueryObject.UnionAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Union(Callback, True);
end;

function TQueryObject.&Except(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('except', All, Query);
end;

function TQueryObject.&Except(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := &Except(Q, All);
end;

function TQueryObject.ExceptAll(Query: IQuery): IQuery;

begin
  Result := &Except(Query, True);
end;

function TQueryObject.ExceptAll(const Callback: TQueryCallback): IQuery;

begin
  Result := &Except(Callback, True);
end;

function TQueryObject.Intersect(Query: IQuery; All: Boolean): IQuery;

begin
  Result := Combine('intersect', All, Query);
end;

function TQueryObject.Intersect(const Callback: TQueryCallback;
All: Boolean): IQuery;
var
  Q: IQuery;
begin
  Q := CallbackQuery(Callback);
  Result := Intersect(Q, All);
end;

function TQueryObject.IntersectAll(Query: IQuery): IQuery;

begin
  Result := Intersect(Query, True);
end;

function TQueryObject.IntersectAll(const Callback: TQueryCallback): IQuery;

begin
  Result := Intersect(Callback, True);
end;

function TQueryObject.ForSqlServer(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.MSSql.EngineCode, Callback);
end;

function TQueryObject.ForPostgreSql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.PostgreSql.EngineCode, Callback);
end;

function TQueryObject.ForMySql(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.MySql.EngineCode, Callback);
end;

function TQueryObject.ForSqlite(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Sqlite.EngineCode, Callback);
end;

function TQueryObject.ForOracle(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Oracle.EngineCode, Callback);
end;

function TQueryObject.ForFirebird(const Callback: TQueryCallback): IQuery;

begin
  Result := &For(TSqlDialect.Firebird.EngineCode, Callback);
end;
// END GENERATED: fluent implementation

end.
