unit FireDAC.Tests;

interface

uses
  DUnitX.TestFramework, FireDAC.Comp.Client, QueryBuilder4Delphi.Query.Core;

type

  [TestFixture]
  TFireDACExecutionTests = class
  private
    FConnection: TFDConnection;
    FExecutor: IQueryExecutor;
    function Rows: IQueryResult;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure SelectRowsAndBindings;
    [Test]
    procedure EmptyAndCursorErrors;
    [Test]
    procedure CrudAndRowsAffected;
    [Test]
    procedure RepeatedAndIndependentResults;
    [Test]
    procedure NullAndBinary;
    [Test]
    procedure NamedNullAccess;
    [Test]
    procedure MetadataErrorsAndDuplicates;
    [Test]
    procedure TransactionRollback;
    [Test]
    procedure FailuresReleaseResources;
    [Test]
    procedure ExplicitModesAndCte;
    [Test]
    procedure TypedValues;
    [Test]
    procedure NilArgumentsAndDisconnected;
    [Test]
    procedure EarlyReleaseAndExecutorLifetime;
    [TestCase('MSSql', '0')]
    [TestCase('MySql', '1')]
    [TestCase('PostgreSql', '2')]
    [TestCase('Sqlite', '3')]
    [TestCase('Oracle', '4')]
    [TestCase('Firebird', '5')]
    procedure ParameterDialects(DialectIndex: Integer);
    [Test]
    procedure BindingTypes;
    [Test]
    procedure VariantsAndNulls;
    [Test]
    procedure RejectsUnsupportedVariant;
    [Test]
    procedure PreservesRawCharacters;
    [Test]
    procedure EmptyBinaryAndTypedNullExecution;
    [Test]
    procedure CursorAfterLast;
    [TestCase('Positive', '123456789.12345678')]
    [TestCase('Negative', '-123456789.12345678')]
    [TestCase('Large', '1234567890123456789012345678.12345678')]
    [TestCase('LeadingZero', '0.00000001')]
    [TestCase('TrailingZeros', '-000123.45000000')]
    procedure ExactDecimal(const Text: string);
    [Test]
    procedure ExactTimestampsAndFloats;
    [Test]
    procedure OracleClobAndUnsupportedTypes;
    [Test]
    procedure PortableNullsAndEmptyValues;
    [Test]
    procedure RejectsParameterConventionMismatch;
    [Test]
    procedure DmlReturning;
    [Test]
    procedure InvalidAndMismatchedModes;
    [Test]
    procedure RejectsLossyBcdDefinition;
    [Test]
    procedure LiteralAndNestedBindings;
    [Test]
    procedure DocumentationExecutionExamples;
    [Test]
    procedure ObjectMappingExamples;
    [Test]
    procedure FluentMappingLifetimeAndErrors;
    [Test]
    procedure ConsecutiveFluentQueries;
    [Test]
    procedure SharedPartialFluentResult;
    [Test]
    procedure AutoClosePreservesCachedRows;
    [Test]
    procedure NullableObjectMapping;
    [Test]
    procedure MappingNativeFieldValues;
    [Test]
    procedure MappingConvenienceAndStreaming;
    [Test]
    procedure MappingDocumentedExamples;

  end;

implementation

uses
  DUnitX.Assert, System.Generics.Collections, System.SysUtils, System.Classes,
  System.Rtti, System.TypInfo, System.Variants, Data.DB, Data.FmtBcd,
  Data.SqlTimSt,
  FireDAC.Stan.Param, FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.ConsoleUI.Wait,
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.Factory,
  QueryBuilder4Delphi.Providers.FireDAC,
  QueryBuilder4Delphi.Providers.FireDAC.Parameters,
  QueryBuilder4Delphi.Providers.FireDAC.Values,
  QueryBuilder4Delphi.Compilers.SqliteCompiler, ExecutionExamples,
  MappingExamples, MappingApiExamples, NullableMappingExamples,
  QueryBuilder4Delphi.Nullable,
  Execution.Mock,
  QueryBuilder4Delphi.Mapping;

type
  TExactBCDField = class(TBCDField)
  protected
    function GetIsNull: Boolean; override;
    function GetAsBCD: TBcd; override;
    function GetAsCurrency: Currency; override;
  public
    Decimal: TBcd;
  end;

  TOracleTextField = class(TStringField)
  public
    constructor Create(AOwner: TComponent); override;
  protected
    function GetIsNull: Boolean; override;
    function GetAsString: string; override;
  end;

  TUnsupportedField = class(TField)
  public
    constructor Create(AOwner: TComponent); override;
  protected
    function GetIsNull: Boolean; override;
  end;

  TReturningCompiler = class(TSqliteCompiler)
  public
    function Compile(Query: IQuery): ISqlResult; overload; override;
  end;

  TReturningExecutor = class(TFireDACQueryExecutor)
  protected
    function CreateCompiler: ICompiler; override;
  end;

{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}

  TNativeFieldDTO = class
  private
    FDecimal: TBcd;
    FStamp: TSQLTimeStamp;
    FOffset: TSQLTimeStampOffset;
  public
    property Decimal: TBcd read FDecimal write FDecimal;
    property Stamp: TSQLTimeStamp read FStamp write FStamp;
    property Offset: TSQLTimeStampOffset read FOffset write FOffset;
  end;
{$RTTI INHERIT}

procedure TFireDACExecutionTests.NullableObjectMapping;
var
  Books: TObjectList<TRatedBook>;
  Book: TRatedBook;
begin
  FConnection.ExecSQL
    ('create table NullableBooks (Id integer, Rating integer, Title text, Payload blob)');
  FConnection.ExecSQL('insert into NullableBooks values (1, NULL, NULL, NULL)');
  FConnection.ExecSQL
    ('insert into NullableBooks values (2, 0, '''', X''00FF2A'')');
  Books := LoadRatedBooks(FExecutor);
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.IsFalse(Books[0].Rating.HasValue);
    Assert.IsFalse(Books[0].Title.HasValue);
    Assert.IsFalse(Books[0].Payload.HasValue);
    Assert.IsTrue(Books[1].Rating.HasValue);
    Assert.AreEqual(0, Books[1].Rating.Value);
    Assert.IsTrue(Books[1].Title.HasValue);
    Assert.AreEqual('', Books[1].Title.Value);
    Assert.IsTrue(Books[1].Payload.HasValue);
    Assert.AreEqual<NativeInt>(3, Length(Books[1].Payload.Value));
    Assert.AreEqual<Byte>(255, Books[1].Payload.Value[1]);
  finally
    Books.Free;
  end;
  Book := TQuery.Create('NullableBooks').Where('Id', 1).Execute(FExecutor)
    .FirstOrDefault<TRatedBook>();
  try
    Assert.IsNotNull(Book);
    Assert.IsFalse(Book.Rating.HasValue);
    Assert.IsFalse(Book.Title.HasValue);
    Assert.IsFalse(Book.Payload.HasValue);
  finally
    Book.Free;
  end;
end;

procedure TFireDACExecutionTests.MappingNativeFieldValues;
var
  M: TFDMemTable;
  R: IQueryResult;
  Item: TNativeFieldDTO;
  Decimal: TBcd;
  Stamp: TSQLTimeStamp;
  Offset: TSQLTimeStampOffset;
begin
  // FireDAC memory fields -> existing field reader -> mock result -> mapper.
  // This checks driver-independent field handling, not a server round trip.
  Decimal := StrToBcd('1234567890123456789012345678.12345678',
    TFormatSettings.Invariant);
  Stamp := DateTimeToSQLTimeStamp(EncodeDate(2026, 10, 24));
  Stamp.Fractions := 123456789;
  Offset := DateTimeToSQLTimeStampOffset(EncodeDate(2026, 10, 24), 5, 45);
  Offset.Fractions := 987654321;
  M := TFDMemTable.Create(nil);
  try
    with M.FieldDefs.AddFieldDef do
    begin
      Name := 'Decimal';
      DataType := ftFMTBcd;
      Precision := 38;
      Size := 8;
    end;
    M.FieldDefs.Add('Stamp', ftTimeStamp);
    M.FieldDefs.Add('Offset', ftTimeStampOffset);
    M.CreateDataSet;
    M.Append;
    M.Fields[0].AsBCD := Decimal;
    M.Fields[1].AsSQLTimeStamp := Stamp;
    M.Fields[2].AsSQLTimeStampOffset := Offset;
    M.Post;
    R := TMockQueryResult.Create(['Decimal', 'Stamp', 'Offset'], nil,
      TRows.Create(TValues.Create(TFireDACFieldReader.ReadValue(M.Fields[0]),
      TFireDACFieldReader.ReadValue(M.Fields[1]),
      TFireDACFieldReader.ReadValue(M.Fields[2]))), True, -1);
    Item := TQueryMapper.FirstOrDefault<TNativeFieldDTO>(R);
    try
      R := nil;
      Assert.AreEqual(0, BcdCompare(Decimal, Item.Decimal));
      Assert.AreEqual<Cardinal>(Stamp.Fractions, Item.Stamp.Fractions);
      Assert.AreEqual<Cardinal>(Offset.Fractions, Item.Offset.Fractions);
      Assert.AreEqual<SmallInt>(5, Item.Offset.TimeZoneHour);
      Assert.AreEqual<SmallInt>(45, Item.Offset.TimeZoneMinute);
    finally
      Item.Free;
    end;
  finally
    M.Free;
  end;
end;

function TExactBCDField.GetIsNull: Boolean;
begin
  Result := False;
end;

function TExactBCDField.GetAsBCD: TBcd;
begin
  Result := Decimal;
end;

function TExactBCDField.GetAsCurrency: Currency;
begin
  raise EQueryException.Create
    ('Currency conversion must never be used for BCD');
end;

constructor TOracleTextField.Create(AOwner: TComponent);
begin
  inherited;
  SetDataType(ftOraClob);
end;

function TOracleTextField.GetIsNull: Boolean;
begin
  Result := False;
end;

function TOracleTextField.GetAsString: string;
begin
  Result := 'Oracle CLOB ' + #$03A9;
end;

constructor TUnsupportedField.Create(AOwner: TComponent);
begin
  inherited;
  SetDataType(ftOraInterval);
end;

function TUnsupportedField.GetIsNull: Boolean;
begin
  Result := False;
end;

function TReturningCompiler.Compile(Query: IQuery): ISqlResult;
begin
  Result := inherited Compile(Query);
  Result.Sql := Result.Sql + ' RETURNING Id';
  Result.RawSql := Result.RawSql + ' RETURNING Id';
end;

function TReturningExecutor.CreateCompiler: ICompiler;
begin
  Result := TReturningCompiler.Create;
  Result.ParameterPrefix := ':p';
end;

procedure TFireDACExecutionTests.Setup;
begin
  FConnection := TFDConnection.Create(nil);
  FConnection.DriverName := 'SQLite';
  FConnection.Params.Values['Database'] := ':memory:';
  FConnection.LoginPrompt := False;
  FConnection.Connected := True;
  FConnection.ExecSQL
    ('create table Books (Id integer primary key, Title text, Price numeric, Payload blob)');
  FConnection.ExecSQL('insert into Books values (1, ''Alpha'', 12.5, NULL)');
  FConnection.ExecSQL('insert into Books values (2, ''Beta'', NULL, NULL)');
  FExecutor := TFireDACQueryExecutor.Create(FConnection, TSqlDialect.SQLite);
end;

procedure TFireDACExecutionTests.TearDown;
begin
  FExecutor := nil;
  FConnection.Free;
end;

function TFireDACExecutionTests.Rows: IQueryResult;
begin
  Result := TQuery.Create('Books').Select(['Id', 'Title']).OrderBy('Id')
    .Execute(FExecutor);
end;

procedure TFireDACExecutionTests.SelectRowsAndBindings;
var
  R: IQueryResult;
begin
  R := Rows;
  Assert.IsTrue(R.HasResultSet);
  Assert.AreEqual(2, R.ColumnCount);
  Assert.AreEqual('Title', R.ColumnNames[1]);
  Assert.AreEqual(1, R.GetColumnIndex('title'));
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Alpha', R.GetValue('Title').AsString);
  Assert.AreEqual<Int64>(1, R.GetValue(0).AsInt64);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Beta', R.GetValue(1).AsString);
  Assert.IsFalse(R.Next);
  Assert.IsFalse(R.Next);
  R := TQuery.Create('Books').Where('Id', 2).Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Beta', R.GetValue('Title').AsString);
  Assert.IsFalse(R.Next);
end;

procedure TFireDACExecutionTests.EmptyAndCursorErrors;
var
  R: IQueryResult;
begin
  R := Rows;
  Assert.WillRaise(
    procedure
    begin
      R.GetValue(0);
    end, EQueryException);
  R := TQuery.Create('Books').Where('Id', -1).Execute(FExecutor);
  Assert.AreEqual(4, R.ColumnCount);
  Assert.IsFalse(R.Next);
  Assert.IsFalse(R.Next);
  Assert.WillRaise(
    procedure
    begin
      R.IsNull(0);
    end, EQueryException);
end;

procedure TFireDACExecutionTests.CrudAndRowsAffected;
var
  R: IQueryResult;
begin
  R := TQuery.Create('Books').AsInsert(['Id', 'Title'], [3, 'Gamma'])
    .Execute(FExecutor);
  Assert.IsFalse(R.HasResultSet);
  Assert.AreEqual<Int64>(1, R.RowsAffected);
  Assert.WillRaise(
    procedure
    begin
      R.Next;
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnCount;
    end, EQueryException);
  R := TQuery.Create('Books').Where('Id', 3).AsUpdate(['Title'], ['Changed'])
    .Execute(FExecutor);
  Assert.AreEqual<Int64>(1, R.RowsAffected);
  R := TQuery.Create('Books').Where('Id', 3).AsDelete.Execute(FExecutor);
  Assert.AreEqual<Int64>(1, R.RowsAffected);
  R := TQuery.Create('Books').Where('Id', 3).AsDelete.Execute(FExecutor);
  Assert.AreEqual<Int64>(0, R.RowsAffected);
end;

procedure TFireDACExecutionTests.RepeatedAndIndependentResults;
var
  Q: IQuery;
  A, B: IQueryResult;
  Sql: string;
begin
  Q := TQuery.Create('Books').OrderBy('Id');
  Sql := Q.Compile;
  A := Q.Execute(FExecutor);
  Assert.IsTrue(A.Next);
  B := Q.Execute(FExecutor);
  Assert.IsTrue(B.Next);
  Assert.IsTrue(A.Next);
  Assert.AreEqual('Beta', A.GetValue('Title').AsString);
  Assert.AreEqual('Alpha', B.GetValue('Title').AsString);
  Assert.AreEqual(Sql, Q.Compile);
end;

procedure TFireDACExecutionTests.NullAndBinary;
var
  R: IQueryResult;
  B: TBytes;
begin
  R := TQuery.Create('Books').Where('Id', 2).Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.IsTrue(R.IsNull(R.GetColumnIndex('Price')));
  Assert.IsTrue(R.GetValue('Price').IsEmpty);
  R := nil;
  B := TBytes.Create(0, 127, 255);
  TQuery.Create('Books').Where('Id', 1).AsUpdate(['Payload'],
    [TValue.From<TBytes>(B)]).Execute(FExecutor);
  R := TQuery.Create('Books').Where('Id', 1).Execute(FExecutor);
  Assert.IsTrue(R.Next);
  B := R.GetValue('Payload').AsType<TBytes>;
  Assert.AreEqual<NativeInt>(3, Length(B));
  Assert.AreEqual(255, Integer(B[2]));
end;

procedure TFireDACExecutionTests.NamedNullAccess;
var
  R: IQueryResult;
  procedure CheckCursorError;
  begin
    Assert.WillRaise(
      procedure
      begin
        R.IsNull(1);
      end, EQueryException);
    Assert.WillRaise(
      procedure
      begin
        R.IsNull('Title');
      end, EQueryException);
  end;

begin
  FConnection.ExecSQL('UPDATE Books SET Title = NULL WHERE Id = 1');
  R := Rows;
  CheckCursorError;
  Assert.IsTrue(R.Next);
  Assert.IsTrue(R.IsNull('Title'));
  Assert.IsTrue(R.IsNull(1) = R.IsNull('tItLe'));
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.GetValue('missing');
    end, EQueryException, 'Column not found: missing');
  Assert.WillRaiseWithMessage(
    procedure
    begin
      R.IsNull('missing');
    end, EQueryException, 'Column not found: missing');
  Assert.IsTrue(R.Next);
  Assert.IsFalse(R.IsNull('Title'));
  Assert.IsTrue(R.IsNull(1) = R.IsNull('TITLE'));
  Assert.IsFalse(R.Next);
  CheckCursorError;
end;

procedure TFireDACExecutionTests.MetadataErrorsAndDuplicates;
var
  R: IQueryResult;
begin
  R := Rows;
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnName(-1);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetValue(2);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      R.GetColumnIndex('missing');
    end, EQueryException);
  R := TQuery.Create.SelectRaw('1 as X, 2 as X').Execute(FExecutor);
  Assert.AreEqual(2, R.ColumnCount);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(1, R.GetValue(0).AsInt64);
  Assert.AreEqual<Int64>(2, R.GetValue(1).AsInt64);
  // FireDAC can disambiguate duplicate aliases into distinct field names.
  // If aliases remain ambiguous, both name APIs must reject them identically.
  if SameText(R.GetColumnName(0), R.GetColumnName(1)) then
  begin
    Assert.WillRaiseWithMessage(
      procedure
      begin
        R.GetValue('X');
      end, EQueryException, 'Ambiguous column name: X; use its index');
    Assert.WillRaiseWithMessage(
      procedure
      begin
        R.IsNull('X');
      end, EQueryException, 'Ambiguous column name: X; use its index');
  end
  else
  begin
    Assert.IsTrue(R.IsNull(0) = R.IsNull(R.GetColumnName(0)));
    Assert.IsTrue(R.IsNull(1) = R.IsNull(R.GetColumnName(1)));
  end;
end;

procedure TFireDACExecutionTests.TransactionRollback;
var
  R: IQueryResult;
begin
  FConnection.StartTransaction;
  TQuery.Create('Books').AsInsert(['Id', 'Title'], [3, 'Rolled back'])
    .Execute(FExecutor);
  Assert.IsTrue(FConnection.InTransaction);
  FConnection.Rollback;
  R := TQuery.Create('Books').Where('Id', 3).Execute(FExecutor);
  Assert.IsFalse(R.Next);
end;

procedure TFireDACExecutionTests.FailuresReleaseResources;
var
  Before: Integer;
begin
  Before := FConnection.DataSetCount;
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('MissingTable').Execute(FExecutor);
    end);
  Assert.AreEqual(Before, FConnection.DataSetCount);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').Where('Id', TValue.From<TObject>(FConnection))
        .Execute(FExecutor);
    end, EQueryException);
  Assert.AreEqual(Before, FConnection.DataSetCount);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').AsInsert(['Id'], [1]).Execute(FExecutor);
    end);
  Assert.AreEqual(Before, FConnection.DataSetCount);
  Assert.IsTrue(FConnection.Connected);
end;

procedure TFireDACExecutionTests.ExplicitModesAndCte;
var
  R: IQueryResult;
begin
  R := TQuery.Create('Books').Execute(FExecutor, emRows);
  Assert.IsTrue(R.Next);
  R := nil;
  R := TQuery.Create('Books').Where('Id', 99).AsDelete.Execute(FExecutor,
    emCommand);
  Assert.IsFalse(R.HasResultSet);
  R := TQuery.Create('b').&With('b', TQuery.Create('Books').Where('Id', 1))
    .Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Alpha', R.GetValue('Title').AsString);
  R := nil;
  R := TQuery.Create('Books').AsCount.Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(2, R.GetValue(0).AsInt64);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').AsInsert([TPair<string, TValue>.Create('Title',
        'Identity')], True).Execute(FExecutor, emRows);
    end, EQueryException);
end;

procedure TFireDACExecutionTests.TypedValues;
var
  R: IQueryResult;
begin
  FConnection.ExecSQL
    ('create table Typed (Flag boolean, Stamp datetime, Amount currency, Number bigint, TextValue text)');
  TQuery.Create('Typed').AsInsert(['Flag', 'Stamp', 'Amount', 'Number',
    'TextValue'], [True, TValue.From<TDateTime>(EncodeDate(2026, 10, 22)),
    TValue.From<Currency>(12.5), TValue.From<Int64>(5000000000),
    'Gr' + #$00FC + #$00DF + 'e']).Execute(FExecutor);
  R := TQuery.Create('Typed').Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.IsTrue(R.GetValue('Flag').AsBoolean);
  Assert.AreEqual(EncodeDate(2026, 10, 22), R.GetValue('Stamp')
    .AsType<TDateTime>);
  Assert.AreEqual<Int64>(5000000000, R.GetValue('Number').AsInt64);
  Assert.AreEqual('Gr' + #$00FC + #$00DF + 'e', R.GetValue('TextValue')
    .AsString);
  Assert.IsFalse(R.IsNull(2));
end;

procedure TFireDACExecutionTests.NilArgumentsAndDisconnected;
var
  E: IQueryExecutor;
begin
  Assert.WillRaise(
    procedure
    begin
      FExecutor.Execute(nil);
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create.Execute(nil);
    end, EArgumentNilException);
  Assert.WillRaise(
    procedure
    begin
      E := TFireDACQueryExecutor.Create(nil);
    end, EArgumentNilException);
  FConnection.Connected := False;
  Assert.WillRaise(
    procedure
    begin
      Rows;
    end, EQueryException);
end;

procedure TFireDACExecutionTests.EarlyReleaseAndExecutorLifetime;
var
  R: IQueryResult;
  Before: Integer;
begin
  Before := FConnection.DataSetCount;
  R := Rows;
  Assert.IsTrue(R.Next);
  FExecutor := nil;
  Assert.IsTrue(R.Next);
  R := nil;
  Assert.AreEqual(Before, FConnection.DataSetCount);
  Assert.IsTrue(FConnection.Connected);
end;

procedure TFireDACExecutionTests.ParameterDialects(DialectIndex: Integer);
var
  C: ICompiler;
  S: ISqlResult;
  P: TFDParams;
begin
  C := TQueryCompilerFactory.CreateCompiler(TSqlDialect(DialectIndex));
  C.ParameterPrefix := ':p';
  S := C.Compile(TQuery.Create('Books').Where('Title', 'O''Brien').Limit(3));
  P := TFireDACParameterBinder.Bind(S);
  try
    Assert.IsTrue(Pos(':p0', S.Sql) > 0);
    Assert.AreEqual<NativeInt>(S.Bindings.Count, P.Count);
    Assert.AreEqual(S.Bindings[0].ToString, P.ParamByName('p0').AsString);
  finally
    P.Free;
  end;
end;

procedure TFireDACExecutionTests.BindingTypes;
var
  C: ICompiler;
  P: TFDParams;
  G: TGUID;
  B: TBcd;
begin
  C := TQueryCompilerFactory.CreateCompiler;
  C.ParameterPrefix := ':p';
  G := StringToGUID('{03629984-43D7-41EE-8028-EE7774970E92}');
  B := StrToBcd('12345.6789', TFormatSettings.Invariant);
  P := TFireDACParameterBinder.Bind
    (C.Compile(TQuery.Create('Typed').AsInsert(['Text', 'Int', 'Big',
    'Unsigned', 'Flag', 'Date', 'Money', 'Float', 'Guid', 'Bcd', 'Bytes'],
    ['Unicode', 42, TValue.From<Int64>(High(Int64)),
    TValue.From<UInt64>(High(UInt64)), True,
    TValue.From<TDateTime>(EncodeDate(2026, 10, 22)),
    TValue.From<Currency>(12.34), TValue.From<Double>(1.25),
    TValue.From<TGUID>(G), TValue.From<TBcd>(B),
    TValue.From<TBytes>(TBytes.Create(0, 127, 255))])));
  try
    Assert.AreEqual(42, P[1].AsInteger);
    Assert.AreEqual<Int64>(High(Int64), P[2].AsLargeInt);
    Assert.IsTrue(BcdCompare(StrToBcd('18446744073709551615'),
      P[3].AsFMTBCD) = 0);
    Assert.IsTrue(P[4].AsBoolean);
    Assert.IsTrue(P[5].DataType = ftDateTime);
    Assert.AreEqual<Currency>(12.34, P[6].AsCurrency);
    Assert.AreEqual<Double>(1.25, Double(P[7].AsExtended));
    Assert.IsTrue(IsEqualGUID(G, P[8].AsGUID));
    Assert.IsTrue(BcdCompare(B, P[9].AsFMTBCD) = 0);
    Assert.AreEqual(255, Ord(P[10].AsBlob[3]));
  finally
    P.Free;
  end;
end;

procedure TFireDACExecutionTests.VariantsAndNulls;
var
  C: ICompiler;
  P: TFDParams;
begin
  C := TQueryCompilerFactory.CreateCompiler;
  C.ParameterPrefix := ':p';
  P := TFireDACParameterBinder.Bind
    (C.Compile(TQuery.Create('Typed').AsInsert(['Empty', 'Typed', 'VariantNull',
    'VariantInt', 'VariantString'], [TValue.Empty,
    TFireDACNull.Create(ftCurrency), TValue.From<Variant>(Null),
    TValue.From<Variant>(Int64(12345678901)), TValue.From<Variant>('hello')])));
  try
    Assert.IsTrue(P[0].IsNull);
    Assert.IsTrue(P[0].Bound);
    Assert.IsTrue(P[1].IsNull);
    Assert.IsTrue(P[1].DataType = ftCurrency);
    Assert.IsTrue(P[2].IsNull);
    Assert.AreEqual<Int64>(12345678901, P[3].AsLargeInt);
    Assert.AreEqual('hello', P[4].AsWideString);
  finally
    P.Free;
  end;
end;

procedure TFireDACExecutionTests.RejectsUnsupportedVariant;
var
  V: Variant;
begin
  V := VarArrayCreate([0, 1], varInteger);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').Where('Id', TValue.From<Variant>(V))
        .Execute(FExecutor);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').AsInsert(['Id'], [TValue.From<TObject>(nil)])
        .Execute(FExecutor);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').AsInsert(['Id'],
        [TValue.From < TArray < Integer >> (nil)]).Execute(FExecutor);
    end, EQueryException);
  Assert.IsTrue(FConnection.Connected);
  Assert.WillRaise(
    procedure
    begin
      TFireDACNull.Create(ftUnknown);
    end, EQueryException);
end;

procedure TFireDACExecutionTests.PreservesRawCharacters;
var
  R: IQueryResult;
begin
  R := TQuery.Create.SelectRaw('? as Value', ['&macro !bang {escape} :literal'])
    .Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('&macro !bang {escape} :literal', R.GetValue(0).AsString);
end;

procedure TFireDACExecutionTests.EmptyBinaryAndTypedNullExecution;
var
  R: IQueryResult;
begin
  TQuery.Create('Books').Where('Id', 1).AsUpdate(['Payload', 'Price'],
    [TValue.From<TBytes>(nil), TFireDACNull.Create(ftCurrency)])
    .Execute(FExecutor);
  R := TQuery.Create('Books').Where('Id', 1).Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.IsTrue(R.GetValue('Price').IsEmpty);
  // Drivers may normalize a zero-length BLOB to SQL NULL.
  if not R.GetValue('Payload').IsEmpty then
    Assert.AreEqual<NativeInt>(0, Length(R.GetValue('Payload').AsType<TBytes>));
end;

procedure TFireDACExecutionTests.CursorAfterLast;
var
  R: IQueryResult;
begin
  R := Rows;
  while R.Next do;
  Assert.WillRaise(
    procedure
    begin
      R.GetValue(0);
    end, EQueryException);
  Assert.IsFalse(R.Next);
  Assert.AreEqual(2, R.ColumnCount);
end;

procedure TFireDACExecutionTests.ExactDecimal(const Text: string);
var
  M: TFDMemTable;
  F: TExactBCDField;
  B, Actual: TBcd;
begin
  B := StrToBcd(Text, TFormatSettings.Invariant);
  F := TExactBCDField.Create(nil);
  try
    F.Decimal := B;
    Actual := TFireDACFieldReader.ReadValue(F).AsType<TBcd>;
    Assert.IsTrue(BcdCompare(B, Actual) = 0);
    Assert.AreEqual(Integer(B.Precision), Integer(Actual.Precision));
    Assert.AreEqual(Integer(B.SignSpecialPlaces),
      Integer(Actual.SignSpecialPlaces));
  finally
    F.Free;
  end;
  M := TFDMemTable.Create(nil);
  try
    with M.FieldDefs.AddFieldDef do
    begin
      Name := 'Exact';
      DataType := ftFMTBcd;
      Precision := 38;
      Size := 8;
    end;
    M.CreateDataSet;
    Assert.IsTrue(TFireDACFieldReader.ValueType(M.Fields[0]) = qtDecimal);
    M.Append;
    Assert.IsTrue(M.Fields[0].IsNull);
    Assert.IsTrue(TFireDACFieldReader.ReadValue(M.Fields[0]).TypeInfo = nil);
    M.FieldByName('Exact').AsBCD := B;
    M.Post;
    Actual := TFireDACFieldReader.ReadValue(M.Fields[0]).AsType<TBcd>;
    Assert.IsTrue(BcdCompare(B, Actual) = 0);
    Assert.IsTrue(TFireDACFieldReader.ValueType(M.Fields[0]) = qtDecimal);
  finally
    M.Free;
  end;
end;

procedure TFireDACExecutionTests.ExactTimestampsAndFloats;
var
  M: TFDMemTable;
  Stamp, ReadStamp: TSQLTimeStamp;
  Offset, ReadOffset: TSQLTimeStampOffset;
  V: TValue;
begin
  Stamp := DateTimeToSQLTimeStamp(EncodeDate(2026, 10, 22));
  Stamp.Fractions := 123456789;
  Offset := DateTimeToSQLTimeStampOffset(EncodeDate(2026, 10, 22), -5, -30);
  Offset.Fractions := 987654321;
  M := TFDMemTable.Create(nil);
  try
    M.FieldDefs.Add('Stamp', ftTimeStamp);
    M.FieldDefs.Add('Offset', ftTimeStampOffset);
    M.FieldDefs.Add('SingleValue', ftSingle);
    M.FieldDefs.Add('ExtendedValue', ftExtended);
    M.CreateDataSet;
    M.Append;
    M.Fields[0].AsSQLTimeStamp := Stamp;
    M.Fields[1].AsSQLTimeStampOffset := Offset;
    M.Fields[2].AsSingle := 1.25;
    M.Fields[3].AsExtended := 1.234567890123456789;
    M.Post;
    ReadStamp := TFireDACFieldReader.ReadValue(M.Fields[0])
      .AsType<TSQLTimeStamp>;
    ReadOffset := TFireDACFieldReader.ReadValue(M.Fields[1])
      .AsType<TSQLTimeStampOffset>;
    Assert.AreEqual<Cardinal>(Stamp.Fractions, ReadStamp.Fractions);
    Assert.AreEqual<Cardinal>(Offset.Fractions, ReadOffset.Fractions);
    Assert.AreEqual<SmallInt>(Offset.TimeZoneHour, ReadOffset.TimeZoneHour);
    Assert.AreEqual<SmallInt>(Offset.TimeZoneMinute, ReadOffset.TimeZoneMinute);
    V := TFireDACFieldReader.ReadValue(M.Fields[2]);
    Assert.IsTrue(V.IsType<Single>);
    V := TFireDACFieldReader.ReadValue(M.Fields[3]);
    Assert.IsTrue(V.IsType<Extended>);
    Assert.AreEqual<Extended>(M.Fields[3].AsExtended, V.AsType<Extended>);
  finally
    M.Free;
  end;
end;

procedure TFireDACExecutionTests.OracleClobAndUnsupportedTypes;
var
  F: TOracleTextField;
  U: TUnsupportedField;
begin
  F := TOracleTextField.Create(nil);
  try
    Assert.AreEqual('Oracle CLOB ' + #$03A9, TFireDACFieldReader.ReadValue(F)
      .AsString);
  finally
    F.Free;
  end;
  U := TUnsupportedField.Create(nil);
  try
    Assert.WillRaise(
      procedure
      begin
        TFireDACFieldReader.ReadValue(U);
      end, EQueryException);
    Assert.IsTrue(TFireDACFieldReader.ValueType(U) = qtUnknown);
  finally
    U.Free;
  end;
end;

procedure TFireDACExecutionTests.PortableNullsAndEmptyValues;
var
  C: ICompiler;
  P: TFDParams;
  R: IQueryResult;
  K: TQueryValueType;
  Expected: array [TQueryValueType] of TFieldType;
begin
  Expected[qtString] := ftWideString;
  Expected[qtInteger] := ftInteger;
  Expected[qtInt64] := ftLargeint;
  Expected[qtBoolean] := ftBoolean;
  Expected[qtFloat] := ftFloat;
  Expected[qtCurrency] := ftCurrency;
  Expected[qtDecimal] := ftFMTBcd;
  Expected[qtDateTime] := ftDateTime;
  Expected[qtTimestamp] := ftTimeStamp;
  Expected[qtTimestampOffset] := ftTimeStampOffset;
  Expected[qtGuid] := ftGuid;
  Expected[qtBinary] := ftBlob;
  C := TQueryCompilerFactory.CreateCompiler;
  C.ParameterPrefix := ':p';
  for K := qtString to qtBinary do
  begin
    P := TFireDACParameterBinder.Bind
      (C.Compile(TQuery.Create('Books').Where('Price', TQueryNull.Create(K))));
    try
      Assert.IsTrue(P[0].DataType = Expected[K]);
      Assert.IsTrue(P[0].IsNull);
      Assert.IsTrue(P[0].Bound);
    finally
      P.Free;
    end;
  end;
  P := TFireDACParameterBinder.Bind
    (C.Compile(TQuery.Create('Books').AsInsert(['Title', 'Payload', 'Price'],
    ['', TValue.From<TBytes>(nil), TQueryNull.Create(qtDecimal)])));
  try
    Assert.IsFalse(P[0].IsNull, 'Empty string parameter became NULL');
    Assert.IsFalse(P[1].IsNull, 'Empty byte parameter became NULL');
    Assert.IsTrue(P[2].IsNull);
  finally
    P.Free;
  end;
  TQuery.Create('Books').Where('Id', 1).AsUpdate(['Title', 'Payload', 'Price'],
    ['', TValue.From<TBytes>(nil), TQueryNull.Create(qtDecimal)])
    .Execute(FExecutor);
  R := TQuery.Create('Books').Where('Id', 1).Execute(FExecutor);
  Assert.AreEqual(4, R.ColumnCount);
  Assert.IsTrue(R.Next);
  Assert.IsFalse(R.IsNull(R.GetColumnIndex('Title')),
    'Empty string result became NULL');
  Assert.AreEqual('', R.GetValue('Title').AsString);
  Assert.IsFalse(R.IsNull(R.GetColumnIndex('Payload')),
    'Empty BLOB result became NULL');
  Assert.AreEqual<NativeInt>(0, Length(R.GetValue('Payload').AsType<TBytes>));
  Assert.IsTrue(R.GetValue('Price').IsEmpty);
end;

procedure TFireDACExecutionTests.RejectsParameterConventionMismatch;
var
  C: ICompiler;
  S: ISqlResult;
begin
  C := TQueryCompilerFactory.CreateCompiler;
  C.ParameterPrefix := ':Parameter';
  S := C.Compile(TQuery.Create('Books').Where('Id', 1));
  Assert.WillRaise(
    procedure
    begin
      TFireDACParameterBinder.Bind(S);
    end, EQueryException);
  Assert.WillRaise(
    procedure
    begin
      TFireDACParameterBinder.Bind(nil);
    end, EArgumentNilException);
end;

procedure TFireDACExecutionTests.DmlReturning;
var
  E: IQueryExecutor;
  R: IQueryResult;
begin
  E := TReturningExecutor.Create(FConnection, TSqlDialect.SQLite);
  R := TQuery.Create('Books').Where('Id', 1).AsUpdate(['Title'], ['Returned'])
    .Execute(E, emRows);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(1, R.GetValue(0).AsInt64);
  Assert.IsFalse(R.Next);
end;

procedure TFireDACExecutionTests.InvalidAndMismatchedModes;
var
  Before: Integer;
begin
  Before := FConnection.DataSetCount;
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create.Execute(FExecutor);
    end);
  Assert.WillRaise(
    procedure
    begin
      TQuery.Create('Books').Execute(FExecutor, emCommand);
    end);
  Assert.AreEqual(Before, FConnection.DataSetCount);
end;

procedure TFireDACExecutionTests.RejectsLossyBcdDefinition;
var
  F: TExactBCDField;
begin
  F := TExactBCDField.Create(nil);
  try
    F.Size := 8;
    F.Decimal := StrToBcd('123456789.12345678', TFormatSettings.Invariant);
    Assert.WillRaise(
      procedure
      begin
        TFireDACFieldReader.ReadValue(F);
      end, EQueryException);
  finally
    F.Free;
  end;
end;

procedure TFireDACExecutionTests.LiteralAndNestedBindings;
var
  R: IQueryResult;
begin
  R := TQuery.Create.SelectRaw
    ('''literal ? :p0'' as Literal, ? as Bound /* ? */', ['value'])
    .Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('literal ? :p0', R.GetValue('Literal').AsString);
  Assert.AreEqual('value', R.GetValue('Bound').AsString);
  R := nil;
  R := TQuery.Create('b').&With('b', TQuery.Create('Books').Where('Title',
    'Alpha')).WhereIn('Id', TQuery.Create('Books').Select('Id').Where('Id', 1))
    .Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual('Alpha', R.GetValue('Title').AsString);
  Assert.IsFalse(R.Next);
end;

procedure TFireDACExecutionTests.DocumentationExecutionExamples;
var
  R: IQueryResult;
begin
  FConnection.ExecSQL
    ('ALTER TABLE Books ADD COLUMN IsPublished integer DEFAULT 1');
  PrintBooks(FConnection, TSqlDialect.SQLite);
  Assert.WillRaise(
    procedure
    begin
      ChangeBookInTransaction(FConnection, TSqlDialect.SQLite);
    end, EInvalidOp);
  FConnection.StartTransaction;
  try
    Assert.AreEqual<Int64>(1, ChangeBookInTransaction(FConnection,
      TSqlDialect.SQLite));
    Assert.IsTrue(FConnection.InTransaction);
  finally
    FConnection.Rollback;
  end;
  ChangeBook(FConnection, TSqlDialect.SQLite);
  Assert.IsFalse(FConnection.InTransaction);
  Assert.IsTrue(FConnection.Connected);
  R := TQuery.Create('Books').AsCount.Execute(FExecutor);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(2, R.GetValue(0).AsInt64);
end;

procedure TFireDACExecutionTests.ObjectMappingExamples;
var
  Books: TObjectList<TBook>;
  Book: TBook;
begin
  Books := LoadBooks(FExecutor);
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.AreEqual(1, Books[0].Id);
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual(2, Books[1].Id);
    Assert.AreEqual('Beta', Books[1].Title);
  finally
    Books.Free;
  end;
  Book := FindBook(FExecutor, 2);
  try
    Assert.AreEqual(2, Book.Id);
    Assert.AreEqual('Beta', Book.Title);
  finally
    Book.Free;
  end;
  Book := FindBook(FExecutor, -1);
  try
    Assert.IsNull(Book);
  finally
    Book.Free;
  end;
  FConnection.ExecSQL
    ('ALTER TABLE Books ADD COLUMN IsPublished integer DEFAULT 1');
  FConnection.ExecSQL('UPDATE Books SET IsPublished = 0 WHERE Id = 2');
  Books := LoadPublishedBooks(FExecutor);
  try
    Assert.AreEqual<NativeInt>(1, Books.Count);
    Assert.AreEqual(1, Books[0].Id);
    Assert.AreEqual('Alpha', Books[0].Title);
  finally
    Books.Free;
  end;
  FConnection.ExecSQL('UPDATE Books SET Title = NULL WHERE Id = 1');
  Assert.WillRaise(
    procedure
    begin
      LoadBooks(FExecutor).Free;
    end, EQueryMappingException);
end;

procedure TFireDACExecutionTests.FluentMappingLifetimeAndErrors;
var
  A, B: TQueryResult;
  Raw: IQueryResult;
  Books: TObjectList<TBook>;
begin
  A := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle']).OrderBy('Id')
    .Execute(FExecutor);
  B := A;
  A := Default (TQueryResult);
  Raw := B.AsRaw;
  B := Default (TQueryResult);
  Books := TQueryMapper.ToList<TBook>(Raw);
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual(2, Books[1].Id);
  finally
    Books.Free;
  end;
  Raw := nil;
  Assert.AreEqual(0, FConnection.DataSetCount);
  Books := TQuery.Create('Books').Where('Id', -1).Execute(FExecutor)
    .ToList<TBook>();
  try
    Assert.AreEqual(0, FConnection.DataSetCount);
    Assert.AreEqual<NativeInt>(0, Books.Count);
  finally
    Books.Free;
  end;
  Assert.AreEqual(0, FConnection.DataSetCount);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      TQuery.Create('Books').Where('Id', -1).AsDelete.Execute(FExecutor)
        .ToList<TBook>().Free;
    end), EQueryMappingException);
  FConnection.ExecSQL('UPDATE Books SET Title = NULL WHERE Id = 1');
  try
    TQuery.Create('Books').Select('Title AS BookTitle').OrderBy('Id')
      .Execute(FExecutor).FirstOrDefault<TBook>().Free;
    Assert.Fail('Expected NULL mapping failure');
  except
    on E: EQueryMappingException do
      Assert.AreEqual(0, FConnection.DataSetCount);
  end;
  try
    TQuery.Create('Books').SelectRaw('Title AS Id').Where('Id', 2)
      .Execute(FExecutor).ToList<TBook>().Free;
    Assert.Fail('Expected type mapping failure');
  except
    on E: EQueryMappingException do
      Assert.AreEqual(0, FConnection.DataSetCount);
  end;
  // Failed temporary mapping must release the provider-owned query.
  Assert.AreEqual(0, FConnection.DataSetCount);
  Assert.IsTrue(FConnection.Connected);
end;

procedure TFireDACExecutionTests.ConsecutiveFluentQueries;
var
  Books, MoreBooks: TObjectList<TBook>;
  Book: TBook;
begin
  Books := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
    .OrderBy('Id').Execute(FExecutor).ToList<TBook>();
  try
    Assert.AreEqual(0, FConnection.DataSetCount);
    MoreBooks := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
      .OrderBy('Id').Execute(FExecutor).ToList<TBook>();
    try
      Assert.AreEqual(0, FConnection.DataSetCount);
      Assert.AreEqual('Beta', Books[1].Title);
      Assert.AreEqual(1, MoreBooks[0].Id);
    finally
      MoreBooks.Free;
    end;
    // FirstOrDefault deliberately leaves unread rows, but releases its owner.
    Book := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
      .OrderBy('Id').Execute(FExecutor).FirstOrDefault<TBook>();
    try
      Assert.AreEqual(0, FConnection.DataSetCount);
      Assert.AreEqual('Alpha', Book.Title);
    finally
      Book.Free;
    end;
    Book := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
      .Where('Id', 2).Execute(FExecutor).FirstOrDefault<TBook>();
    try
      Assert.AreEqual(0, FConnection.DataSetCount);
      Assert.AreEqual('Beta', Book.Title);
    finally
      Book.Free;
    end;
    Book := TQuery.Create('Books').Where('Id', -1).Execute(FExecutor)
      .FirstOrDefault<TBook>();
    try
      Assert.IsNull(Book);
      Assert.AreEqual(0, FConnection.DataSetCount);
    finally
      Book.Free;
    end;
  finally
    Books.Free;
  end;
  Assert.IsTrue(FConnection.Connected);
end;

procedure TFireDACExecutionTests.SharedPartialFluentResult;
var
  A, B, C: TQueryResult;
  Raw, Other: IQueryResult;
  Book: TBook;
  I: Integer;
begin
  // Cross FireDAC's fetch boundary so early termination also covers unfetched rows.
  FConnection.ExecSQL
    ('WITH RECURSIVE n(x) AS (SELECT 3 UNION ALL SELECT x+1 FROM n WHERE x<120) '
    + 'INSERT INTO Books(Id, Title) SELECT x, ''Book '' || x FROM n');
  Book := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle'])
    .OrderBy('Id').Execute(FExecutor).FirstOrDefault<TBook>();
  try
    Assert.AreEqual(0, FConnection.DataSetCount);
    Assert.AreEqual('Alpha', Book.Title);
  finally
    Book.Free;
  end;
  A := TQuery.Create('Books').Select(['Id', 'Title AS BookTitle']).OrderBy('Id')
    .Execute(FExecutor);
  B := A;
  Raw := A.AsRaw;
  Book := A.FirstOrDefault<TBook>();
  try
    Assert.AreEqual(1, FConnection.DataSetCount);
    Assert.AreEqual('Alpha', B.GetValue('BookTitle').AsString);
    Assert.IsFalse(TFDQuery(FConnection.DataSets[0]).SourceEOF);
    C := TQuery.Create('Books').Where('Id', 2).Execute(FExecutor);
    Other := C.AsRaw;
    C := Default (TQueryResult);
    Assert.AreEqual(2, FConnection.DataSetCount);
    Assert.IsTrue(Other.Next);
    Assert.AreEqual('Beta', Other.GetValue('Title').AsString);
    Other := nil;
    Assert.AreEqual(1, FConnection.DataSetCount);
    for I := 2 to 120 do
    begin
      Assert.IsTrue(B.Next);
      Assert.AreEqual<Int64>(I, Raw.GetValue('Id').AsInt64);
    end;
    Assert.IsFalse(B.Next);
    B := Default (TQueryResult);
    Assert.IsFalse(Raw.Next);
    Raw := nil;
    Assert.AreEqual(0, FConnection.DataSetCount);
    Assert.AreEqual('Alpha', Book.Title);
  finally
    Book.Free;
  end;
end;

procedure TFireDACExecutionTests.AutoClosePreservesCachedRows;
var
  ResultSet: TQueryResult;
  Raw: IQueryResult;
  Query: TFDQuery;
begin
  ResultSet := TQuery.Create('Books').OrderBy('Id').Execute(FExecutor);
  Raw := ResultSet.AsRaw;
  Query := TFDQuery(FConnection.DataSets[0]);
  Assert.IsTrue(Query.FetchOptions.AutoClose);
  Query.FetchAll;
  Assert.IsTrue(Query.SourceEOF);
  Assert.IsTrue(Query.Active);
  Assert.IsTrue(Raw.Next);
  Assert.AreEqual('Alpha', Raw.GetValue('Title').AsString);
  Assert.IsFalse(Raw.IsNull('Title'));
  Assert.IsTrue(ResultSet.Next);
  Assert.AreEqual('Beta', ResultSet.GetValue('Title').AsString);
  Assert.IsFalse(Raw.Next);
  Assert.AreEqual('Id', Raw.GetColumnName(0));
  ResultSet := Default (TQueryResult);
  Assert.AreEqual(1, FConnection.DataSetCount);
  Raw := nil;
  Assert.AreEqual(0, FConnection.DataSetCount);
end;

procedure TFireDACExecutionTests.MappingConvenienceAndStreaming;
var
  R: IQueryResult;
  Book: TBook;
  Seen: Integer;
begin
  R := TQuery.Create('Books').Select(['Id', 'Title as BookTitle']).OrderBy('Id')
    .Execute(FExecutor);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.MapCurrent<TBook>(R).Free;
    end, EQueryException);
  Book := TQueryMapper.First<TBook>(R);
  try
    Assert.AreEqual(1, Book.Id);
  finally
    Book.Free;
  end;
  Book := TQueryMapper.MapCurrent<TBook>(R);
  try
    Assert.AreEqual('Alpha', Book.Title);
  finally
    Book.Free;
  end;
  Book := TQueryMapper.Single<TBook>(R);
  try
    Assert.AreEqual(2, Book.Id);
  finally
    Book.Free;
  end;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.MapCurrent<TBook>(R).Free;
    end, EQueryException);
  R := Rows;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.SingleOrDefault<TBook>(R).Free;
    end, EQueryMappingException);
  Assert.AreEqual<Int64>(2, R.GetValue('Id').AsInt64);
  R := Rows;
  Seen := 0;
  TQueryMapper.ForEach<TBook>(R,
    procedure(Item: TBook)
    begin
      Inc(Seen, Item.Id);
    end);
  Assert.AreEqual(3, Seen);
  R := Rows;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ForEach<TBook>(R,
        procedure(Item: TBook)
        begin
          raise EInvalidOp.Create('callback failure');
        end);
    end, EInvalidOp);
  Assert.IsTrue(R.Next);
  Assert.AreEqual<Int64>(2, R.GetValue('Id').AsInt64);
end;

procedure TFireDACExecutionTests.MappingDocumentedExamples;
var
  Books: TObjectList<TBookView>;
  Joined: TObjectList<TBookAuthorView>;
  Book: TBookView;
  Seen: Integer;
begin
  // Declare decimal precision/scale: bare SQLite NUMERIC is inferred as Int64
  // by this driver and cannot represent fractional prices faithfully.
  FConnection.ExecSQL('DROP TABLE Books');
  FConnection.ExecSQL
    ('CREATE TABLE Books (Id integer PRIMARY KEY, Title text, Price decimal(18,4))');
  FConnection.ExecSQL('INSERT INTO Books VALUES (1, ''Alpha'', 12.5)');
  FConnection.ExecSQL('INSERT INTO Books VALUES (2, ''Beta'', NULL)');
  FConnection.ExecSQL
    ('ALTER TABLE Books ADD COLUMN AuthorId integer DEFAULT 1');
  FConnection.ExecSQL
    ('CREATE TABLE Authors (Id integer PRIMARY KEY, Name text)');
  FConnection.ExecSQL('INSERT INTO Authors VALUES (1, ''Ada'')');
  FConnection.ExecSQL('UPDATE Books SET AuthorId = NULL WHERE Id = 2');
  Books := LoadBookViews(FExecutor);
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual<Currency>(12.5, Books[0].Price.Value);
    Assert.IsFalse(Books[1].Price.HasValue);
    Assert.AreEqual('', Books[0].LocalNote);
  finally
    Books.Free;
  end;
  Books := LoadTitleViews(FExecutor);
  try
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual(0, Books[0].Id);
    Assert.IsFalse(Books[0].Price.HasValue);
  finally
    Books.Free;
  end;
  Joined := LoadBookAuthors(FExecutor);
  try
    Assert.AreEqual('Ada', Joined[0].AuthorName.Value);
    Assert.IsFalse(Joined[1].AuthorName.HasValue);
  finally
    Joined.Free;
  end;
  Book := FirstBook(FExecutor);
  try
    Assert.AreEqual(1, Book.Id);
  finally
    Book.Free;
  end;
  Book := SingleBook(FExecutor, 2);
  try
    Assert.AreEqual('Beta', Book.Title);
  finally
    Book.Free;
  end;
  Assert.WillRaise(
    procedure
    begin
      SingleBook(FExecutor, -1).Free;
    end, EQueryMappingException);
  Seen := 0;
  StreamBooks(FExecutor,
    procedure(Item: TBookView)
    begin
      Inc(Seen, Item.Id);
    end);
  Assert.AreEqual(3, Seen);
  PrintMappingExamples(FExecutor);
end;

initialization

TDUnitX.RegisterTestFixture(TFireDACExecutionTests);

end.
