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
  QueryBuilder4Delphi.Compilers.SqliteCompiler;

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
  C := CreateCompiler(TSqlDialect(DialectIndex));
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
  C := CreateCompiler;
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
  C := CreateCompiler;
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
  C := CreateCompiler;
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
  C := CreateCompiler;
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

initialization

TDUnitX.RegisterTestFixture(TFireDACExecutionTests);

end.
