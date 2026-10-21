unit SqlKata;

interface

uses
  System.Rtti, QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query;

type
  // Compatibility facade: shared types and the query class live in regular units.
  EQueryException = QueryBuilder4Delphi.Query.Core.EQueryException;
  IQuery = QueryBuilder4Delphi.Query.Core.IQuery;
  TQueryCallback = QueryBuilder4Delphi.Query.Core.TQueryCallback;
  TValues = QueryBuilder4Delphi.Query.Core.TValues;
  TRows = QueryBuilder4Delphi.Query.Core.TRows;
  TUnsafeLiteral = QueryBuilder4Delphi.Query.Core.TUnsafeLiteral;
  TVariable = QueryBuilder4Delphi.Query.Core.TVariable;
  ColumnAttribute = QueryBuilder4Delphi.Query.Core.ColumnAttribute;
  KeyAttribute = QueryBuilder4Delphi.Query.Core.KeyAttribute;
  IgnoreAttribute = QueryBuilder4Delphi.Query.Core.IgnoreAttribute;
  TClauseKind = QueryBuilder4Delphi.Query.Core.TClauseKind;
  TClause = QueryBuilder4Delphi.Query.Core.TClause;
  IConditionGroup = QueryBuilder4Delphi.Query.Core.IConditionGroup;
  TConditionGroup = QueryBuilder4Delphi.Query.Core.TConditionGroup;
  IJoin = QueryBuilder4Delphi.Query.Core.IJoin;
  TJoin = QueryBuilder4Delphi.Query.Core.TJoin;
  TSqlValues = QueryBuilder4Delphi.Query.Core.TSqlValues;
  TQueryObject = QueryBuilder4Delphi.Query.TQueryObject;
  TQuery = QueryBuilder4Delphi.Query.TQuery;

const
  ckIdentifier = QueryBuilder4Delphi.Query.Core.ckIdentifier;
  ckRaw = QueryBuilder4Delphi.Query.Core.ckRaw;
  ckBasic = QueryBuilder4Delphi.Query.Core.ckBasic;
  ckNull = QueryBuilder4Delphi.Query.Core.ckNull;
  ckBoolean = QueryBuilder4Delphi.Query.Core.ckBoolean;
  ckColumns = QueryBuilder4Delphi.Query.Core.ckColumns;
  ckString = QueryBuilder4Delphi.Query.Core.ckString;
  ckDate = QueryBuilder4Delphi.Query.Core.ckDate;
  ckBetween = QueryBuilder4Delphi.Query.Core.ckBetween;
  ckIn = QueryBuilder4Delphi.Query.Core.ckIn;
  ckInQuery = QueryBuilder4Delphi.Query.Core.ckInQuery;
  ckQuery = QueryBuilder4Delphi.Query.Core.ckQuery;
  ckSubQuery = QueryBuilder4Delphi.Query.Core.ckSubQuery;
  ckNested = QueryBuilder4Delphi.Query.Core.ckNested;
  ckExists = QueryBuilder4Delphi.Query.Core.ckExists;
  ckJoin = QueryBuilder4Delphi.Query.Core.ckJoin;
  ckCombine = QueryBuilder4Delphi.Query.Core.ckCombine;
  ckLimit = QueryBuilder4Delphi.Query.Core.ckLimit;
  ckOffset = QueryBuilder4Delphi.Query.Core.ckOffset;
  ckAggregate = QueryBuilder4Delphi.Query.Core.ckAggregate;
  ckInsert = QueryBuilder4Delphi.Query.Core.ckInsert;
  ckIncrement = QueryBuilder4Delphi.Query.Core.ckIncrement;
  ckRandom = QueryBuilder4Delphi.Query.Core.ckRandom;
  ckAdHoc = QueryBuilder4Delphi.Query.Core.ckAdHoc;

function CopyValues(const Values: array of TValue): TValues;
function CopyStrings(const Values: array of string): TArray<string>;
function ExpandExpression(const Expression: string): TArray<string>;

implementation

function CopyValues(const Values: array of TValue): TValues;
begin
  Result := QueryBuilder4Delphi.Query.Core.CopyValues(Values);
end;

function CopyStrings(const Values: array of string): TArray<string>;
begin
  Result := QueryBuilder4Delphi.Query.Core.CopyStrings(Values);
end;

function ExpandExpression(const Expression: string): TArray<string>;
begin
  Result := QueryBuilder4Delphi.Query.Core.ExpandExpression(Expression);
end;

end.
