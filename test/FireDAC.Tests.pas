unit FireDAC.Tests;

interface

uses
  DUnitX.TestFramework, FireDAC.Comp.Client;

type
  [TestFixture]
  TFireDACAdapterTests = class
  private
    FTarget: TFDQuery;
  public
    [Setup] procedure Setup;
    [TearDown] procedure TearDown;
    [TestCase('MSSql', '0')]
    [TestCase('MySql', '1')]
    [TestCase('PostgreSql', '2')]
    [TestCase('Sqlite', '3')]
    [TestCase('Oracle', '4')]
    [TestCase('Firebird', '5')]
    procedure AppliesDialectWithNamedParameters(DialectIndex: Integer);
    [Test] procedure PreservesBindingTypes;
    [Test] procedure BindsNullsWithExplicitOrDefaultTypes;
    [Test] procedure BindsScalarVariants;
    [Test] procedure RejectsUnsupportedValuesBeforeMutation;
    [Test] procedure ReuseReplacesParameters;
    [Test] procedure RejectsNilArguments;
    [Test] procedure SQLiteCrud;
    [Test] procedure LeavesTransactionsWithCaller;
    [Test] procedure LeavesRawLiteralsIntact;
  end;

implementation

uses
  DUnitX.Assert, System.SysUtils, System.Classes, System.Rtti, System.Variants, Data.DB, Data.FmtBcd,
  FireDAC.Stan.Param, FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.DApt,
  FireDAC.Phys.SQLite, FireDAC.Phys.SQLiteWrapper.Stat, FireDAC.ConsoleUI.Wait,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Compilers.Compiler, QueryBuilder4Delphi.Compilers.Factory,
  QueryBuilder4Delphi.FireDAC;

procedure TFireDACAdapterTests.Setup;
begin FTarget := TFDQuery.Create(nil); end;

procedure TFireDACAdapterTests.TearDown;
begin FreeAndNil(FTarget); end;

procedure TFireDACAdapterTests.AppliesDialectWithNamedParameters(DialectIndex: Integer);
var
  Query: IQuery;
  Compiler: ICompiler;
  Compiled: ISqlResult;
  I: Integer;
begin
  Query := TQuery.Create('Books').Where('Title', 'O''Brien').OrderBy('Id').Limit(3);
  Compiler := CreateCompiler(TSqlDialect(DialectIndex));
  Compiler.ParameterPrefix := ':p';
  Compiled := Compiler.Compile(Query);
  TFireDACAdapter.Apply(FTarget, Query, TSqlDialect(DialectIndex));
  Assert.AreEqual(Compiled.Sql, Trim(FTarget.SQL.Text));
  Assert.AreEqual<NativeInt>(Compiled.Bindings.Count, FTarget.Params.Count);
  for I := 0 to Compiled.Bindings.Count-1 do
    Assert.AreEqual(Compiled.Bindings[I].ToString, VarToStr(FTarget.ParamByName('p'+IntToStr(I)).Value));
  Assert.IsTrue(FTarget.Params.BindMode = pbByName);
  Assert.IsFalse(FTarget.Active);
  Assert.IsFalse(FTarget.Prepared);
  Assert.IsTrue(FTarget.Connection = nil);
  Assert.AreEqual('@p', CreateCompiler.ParameterPrefix);
end;

procedure TFireDACAdapterTests.PreservesBindingTypes;
var
  D: TDateTime;
  G: TGUID;
  B: TBytes;
  Decimal: TBcd;
begin
  D := EncodeDate(2026, 10, 21)+EncodeTime(12, 34, 56, 0);
  G := StringToGUID('{03629984-43D7-41EE-8028-EE7774970E92}');
  B := TBytes.Create(0, 127, 255);
  Decimal := StrToBcd('12345.6789', TFormatSettings.Invariant);
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Values').AsInsert(
    ['Text', 'Number', 'Large', 'Unsigned', 'MaxUnsigned', 'Flag', 'Date',
     'Money', 'Float', 'Guid', 'Decimal', 'Bytes'],
    ['Gr'+#$00FC+#$00DF+'e', 42, TValue.From<Int64>(High(Int64)),
     TValue.From<Cardinal>(High(Cardinal)), TValue.From<UInt64>(High(UInt64)),
     True, TValue.From<TDateTime>(D), TValue.From<Currency>(12.34),
     TValue.From<Double>(1.25), TValue.From<TGUID>(G), TValue.From<TBcd>(Decimal),
     TValue.From<TBytes>(B)]));
  Assert.AreEqual('Gr'+#$00FC+#$00DF+'e', FTarget.Params[0].AsWideString);
  Assert.AreEqual(42, FTarget.Params[1].AsInteger);
  Assert.AreEqual<Int64>(High(Int64), FTarget.Params[2].AsLargeInt);
  Assert.AreEqual<Cardinal>(High(Cardinal), FTarget.Params[3].AsLongword);
  Assert.IsTrue(BcdCompare(StrToBcd('18446744073709551615'), FTarget.Params[4].AsFMTBCD) = 0);
  Assert.IsTrue(FTarget.Params[5].AsBoolean);
  Assert.AreEqual(D, FTarget.Params[6].AsDateTime);
  Assert.IsTrue(FTarget.Params[6].DataType = ftDateTime);
  Assert.AreEqual<Currency>(12.34, FTarget.Params[7].AsCurrency);
  Assert.AreEqual<Double>(1.25, Double(FTarget.Params[8].AsExtended));
  Assert.IsTrue(IsEqualGUID(G, FTarget.Params[9].AsGUID));
  Assert.IsTrue(BcdCompare(Decimal, FTarget.Params[10].AsFMTBCD) = 0);
  Assert.AreEqual(3, Length(FTarget.Params[11].AsBlob));
  Assert.AreEqual(255, Ord(FTarget.Params[11].AsBlob[3]));
end;

procedure TFireDACAdapterTests.BindsNullsWithExplicitOrDefaultTypes;
begin
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').AsInsert(
    ['A', 'B', 'C'], [TValue.Empty, TValue.From<Variant>(Null), TFireDACNull.Create(ftInteger)]));
  Assert.IsTrue(FTarget.Params[0].IsNull);
  Assert.IsTrue(FTarget.Params[0].Bound);
  Assert.IsTrue(FTarget.Params[0].DataType <> ftUnknown);
  Assert.IsTrue(FTarget.Params[1].IsNull);
  Assert.IsTrue(FTarget.Params[2].IsNull);
  Assert.IsTrue(FTarget.Params[2].DataType = ftInteger);
  FTarget.FormatOptions.DefaultParamDataType := ftDateTime;
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').AsInsert(['Date'], [TValue.Empty]));
  Assert.IsTrue(FTarget.Params[0].DataType = ftDateTime);
end;

procedure TFireDACAdapterTests.BindsScalarVariants;
var
  Text, Number, Flag, DateValue: Variant;
  D: TDateTime;
begin
  Text := 'text'; Number := Int64(12345678901); Flag := True;
  D := EncodeDate(2026, 10, 21); DateValue := VarFromDateTime(D);
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').AsInsert(
    ['A', 'B', 'C', 'D'], [TValue.From<Variant>(Text), TValue.From<Variant>(Number),
      TValue.From<Variant>(Flag), TValue.From<Variant>(DateValue)]));
  Assert.AreEqual('text', FTarget.Params[0].AsWideString);
  Assert.AreEqual<Int64>(12345678901, FTarget.Params[1].AsLargeInt);
  Assert.IsTrue(FTarget.Params[2].AsBoolean);
  Assert.AreEqual(D, FTarget.Params[3].AsDateTime);
end;

procedure TFireDACAdapterTests.RejectsUnsupportedValuesBeforeMutation;
var
  Original: string;
begin
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').Where('Id', 1));
  Original := FTarget.SQL.Text;
  Assert.WillRaise(DUnitX.Assert.TTestLocalMethod(procedure begin
    TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').Where('Id', TValue.From<TObject>(FTarget)));
  end), EQueryException);
  Assert.AreEqual(Original, FTarget.SQL.Text);
  Assert.AreEqual(1, FTarget.Params.Count);
  Assert.AreEqual(1, FTarget.Params[0].AsInteger);
  Assert.WillRaise(DUnitX.Assert.TTestLocalMethod(procedure begin
    TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').WhereRaw('Id = ?', []));
  end), EQueryException);
  Assert.AreEqual(Original, FTarget.SQL.Text);
end;

procedure TFireDACAdapterTests.ReuseReplacesParameters;
begin
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').Where('Id', 1).Where('Lang', 'de'));
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books').Where('Id', 'other'));
  Assert.AreEqual(1, FTarget.Params.Count);
  Assert.AreEqual('other', FTarget.Params[0].AsWideString);
  TFireDACAdapter.Apply(FTarget, TQuery.Create('Books'));
  Assert.AreEqual(0, FTarget.Params.Count);
end;

procedure TFireDACAdapterTests.RejectsNilArguments;
begin
  Assert.WillRaise(DUnitX.Assert.TTestLocalMethod(procedure begin TFireDACAdapter.Apply(nil, TQuery.Create); end), EArgumentNilException);
  Assert.WillRaise(DUnitX.Assert.TTestLocalMethod(procedure begin TFireDACAdapter.Apply(FTarget, nil); end), EArgumentNilException);
  Assert.WillRaise(DUnitX.Assert.TTestLocalMethod(procedure begin TFireDACNull.Create(ftUnknown); end), EQueryException);
end;

function ConnectMemory(Target: TFDQuery): TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  try
    Result.LoginPrompt := False;
    Result.Params.Values['DriverID'] := 'SQLite';
    Result.Params.Values['Database'] := ':memory:';
    Result.Connected := True;
    Target.Connection := Result;
  except
    Result.Free;
    raise;
  end;
end;

procedure TFireDACAdapterTests.SQLiteCrud;
var
  Connection: TFDConnection;
begin
  Connection := ConnectMemory(FTarget);
  try
    Connection.ExecSQL('CREATE TABLE Books (Id INTEGER PRIMARY KEY, Title TEXT, Price NUMERIC)');
    Assert.AreEqual<Int64>(1, TFireDACAdapter.ExecSQL(FTarget,
      TQuery.Create('Books').AsInsert(['Id', 'Title', 'Price'], [1, 'O''Brien', TFireDACNull.Create(ftCurrency)]),
      TSqlDialect.Sqlite));
    TFireDACAdapter.Open(FTarget, TQuery.Create('Books').Where('Id', 1), TSqlDialect.Sqlite);
    Assert.AreEqual('O''Brien', FTarget.FieldByName('Title').AsString);
    Assert.IsTrue(FTarget.FieldByName('Price').IsNull);
    Assert.AreEqual<Int64>(1, TFireDACAdapter.ExecSQL(FTarget,
      TQuery.Create('Books').Where('Id', 1).AsUpdate(['Title'], ['Revised']), TSqlDialect.Sqlite));
    TFireDACAdapter.Open(FTarget, TQuery.Create('Books').Where('Title', 'Revised'), TSqlDialect.Sqlite);
    Assert.AreEqual(1, FTarget.FieldByName('Id').AsInteger);
    Assert.AreEqual<Int64>(1, TFireDACAdapter.ExecSQL(FTarget,
      TQuery.Create('Books').Where('Id', 1).AsDelete, TSqlDialect.Sqlite));
    TFireDACAdapter.Open(FTarget, TQuery.Create('Books'), TSqlDialect.Sqlite);
    Assert.IsTrue(FTarget.IsEmpty);
  finally
    FTarget.Close;
    FTarget.Connection := nil;
    Connection.Free;
  end;
end;

procedure TFireDACAdapterTests.LeavesTransactionsWithCaller;
var
  Connection: TFDConnection;
begin
  Connection := ConnectMemory(FTarget);
  try
    Connection.ExecSQL('CREATE TABLE Books (Id INTEGER)');
    Connection.StartTransaction;
    TFireDACAdapter.ExecSQL(FTarget, TQuery.Create('Books').AsInsert(['Id'], [1]), TSqlDialect.Sqlite);
    Assert.IsTrue(Connection.InTransaction);
    Connection.Rollback;
    TFireDACAdapter.Open(FTarget, TQuery.Create('Books'), TSqlDialect.Sqlite);
    Assert.IsTrue(FTarget.IsEmpty);
  finally
    FTarget.Close;
    FTarget.Connection := nil;
    Connection.Free;
  end;
end;

procedure TFireDACAdapterTests.LeavesRawLiteralsIntact;
var
  Connection: TFDConnection;
begin
  Connection := ConnectMemory(FTarget);
  try
    TFireDACAdapter.Open(FTarget, TQuery.Create.SelectRaw('''&macro \{text\} :p0'' AS Value')
      .WhereRaw('? = ?', [7, 7]), TSqlDialect.Sqlite);
    Assert.AreEqual('&macro {text} :p0', FTarget.FieldByName('Value').AsString);
  finally
    FTarget.Close;
    FTarget.Connection := nil;
    Connection.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TFireDACAdapterTests);

end.
