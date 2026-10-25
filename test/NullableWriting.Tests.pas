unit NullableWriting.Tests;

interface

uses DUnitX.TestFramework;

type

  [TestFixture]
  TNullableWritingTests = class
  public
    [Test]
    procedure NativeTypes;
    [Test]
    procedure PredicatesAndKeys;
    [Test]
    procedure ManagedLifetimeAndFailures;
    [Test]
    procedure CustomRegistration;
    [Test]
    procedure GetterAndCallbackFailures;
    [Test]
    procedure DialectPredicates;
  end;

implementation

uses System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  Data.FmtBcd, Data.SqlTimSt,
  QueryBuilder4Delphi.Nullable, QueryBuilder4Delphi.Mapping,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Query.DataMapper,
  QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.Factory;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TNullableDTO<T> = class
  private
    FValue: TNullable<T>;
  public
    [Column('db_value')]
    property Value: TNullable<T> read FValue write FValue;
  end;

  TKeyDTO = class
  private
    FId, FSecond: TNullable<Integer>;
  public
    [Key('book_id')]
    property Id: TNullable<Integer> read FId write FId;
    [Key('second_id')]
    property Second: TNullable<Integer> read FSecond write FSecond;
  end;

  TInheritedDTO = class(TNullableDTO<string>)
  private
    function GetIgnored: TNullable<Integer>;
  public
    [Ignore]
    property Ignored: TNullable<Integer> read GetIgnored;
  end;

  TFailingDTO = class(TKeyDTO)
  private
    function GetFailing: TNullable<string>;
  public
    property Failing: TNullable<string> read GetFailing;
  end;

  TCode = record
    Text: string;
  end;
{$RTTI INHERIT}

  TNativeCheck = class
    class procedure Check<T>(const Native: T; Hint: TQueryValueType); static;
  end;

function TFailingDTO.GetFailing: TNullable<string>;
begin
  raise EInvalidOp.Create('Getter failed');
end;

function TInheritedDTO.GetIgnored: TNullable<Integer>;
begin
  raise EInvalidOp.Create('Ignored getter invoked');
end;

class procedure TNativeCheck.Check<T>(const Native: T; Hint: TQueryValueType);
var
  DTO: TNullableDTO<T>;
  Pairs: TArray<TPair<string, TValue>>;
  R: ISqlResult;
  Q: IQuery;
  I: Integer;
begin
  DTO := TNullableDTO<T>.Create;
  try
    DTO.Value := TNullable<T>.Create(Native);
    Pairs := TQueryDataMapper.GetPairs(DTO);
    Assert.AreEqual<NativeInt>(1, Length(Pairs));
    Assert.IsTrue(Pairs[0].Value.TypeInfo = TypeInfo(T));
    if TypeInfo(T) = TypeInfo(TBytes) then
    begin
      Assert.AreEqual<NativeInt>(Length(TValue.From<T>(Native).AsType<TBytes>),
        Length(Pairs[0].Value.AsType<TBytes>));
      for I := 0 to High(Pairs[0].Value.AsType<TBytes>) do
        Assert.AreEqual<Byte>(TValue.From<T>(Native).AsType<TBytes>[I],
          Pairs[0].Value.AsType<TBytes>[I]);
    end
    else if TypeInfo(T) = TypeInfo(TBcd) then
      Assert.AreEqual(0, BcdCompare(TValue.From<T>(Native).AsType<TBcd>,
        Pairs[0].Value.AsType<TBcd>))
    else if TypeInfo(T) = TypeInfo(TSQLTimeStamp) then
    begin
      Assert.AreEqual<Integer>(123456789,
        Pairs[0].Value.AsType<TSQLTimeStamp>.Fractions);
      Assert.AreEqual<Integer>(2026, Pairs[0].Value.AsType<TSQLTimeStamp>.Year);
      Assert.AreEqual<Integer>(10, Pairs[0].Value.AsType<TSQLTimeStamp>.Month);
      Assert.AreEqual<Integer>(25, Pairs[0].Value.AsType<TSQLTimeStamp>.Day);
    end
    else if TypeInfo(T) = TypeInfo(TSQLTimeStampOffset) then
    begin
      Assert.AreEqual<Integer>(987654321,
        Pairs[0].Value.AsType<TSQLTimeStampOffset>.Fractions);
      Assert.AreEqual<Integer>(5,
        Pairs[0].Value.AsType<TSQLTimeStampOffset>.TimeZoneHour);
      Assert.AreEqual<Integer>(45,
        Pairs[0].Value.AsType<TSQLTimeStampOffset>.TimeZoneMinute);
    end
    else if Pairs[0].Value.Kind = tkFloat then
      Assert.IsTrue(TValue.From<T>(Native).AsExtended = Pairs[0]
        .Value.AsExtended)
    else
      Assert.AreEqual(TValue.From<T>(Native).ToString, Pairs[0].Value.ToString);
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').AsInsert(DTO));
    Assert.AreEqual<NativeInt>(1, R.Bindings.Count);
    Assert.IsTrue(R.Bindings[0].TypeInfo = TypeInfo(T));
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').Where('id', 7)
      .AsUpdate(DTO));
    Assert.IsTrue(R.Bindings[0].TypeInfo = TypeInfo(T));
    Assert.AreEqual(7, R.Bindings[1].AsInteger);
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').Where(DTO)
      .Having(DTO));
    if TypeInfo(T) = TypeInfo(Boolean) then
      Assert.AreEqual<NativeInt>(0, R.Bindings.Count)
      // Existing Boolean SQL literals.
    else
    begin
      Assert.AreEqual<NativeInt>(2, R.Bindings.Count);
      Assert.IsTrue(R.Bindings[0].TypeInfo = TypeInfo(T));
      Assert.IsTrue(R.Bindings[1].TypeInfo = TypeInfo(T));
    end;
    Assert.IsTrue(Pos('IS NULL', R.Sql) = 0);
    DTO.Value := TNullable<T>.Null;
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').AsInsert(DTO));
    Assert.AreEqual<TQueryValueType>(Hint,
      R.Bindings[0].AsType<TQueryNull>.ValueType);
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').Where('id', 7)
      .AsUpdate(DTO));
    Assert.AreEqual<TQueryValueType>(Hint,
      R.Bindings[0].AsType<TQueryNull>.ValueType);
    Q := TQuery.Create('Items').Where(DTO).Having(DTO);
    R := TSqliteCompiler.Create.Compile(Q);
    Assert.IsTrue(Pos('"db_value" IS NULL', R.Sql) > 0);
    Assert.IsTrue(Pos('HAVING "db_value" IS NULL', R.Sql) > 0);
    Assert.AreEqual<NativeInt>(0, R.Bindings.Count);
  finally
    DTO.Free;
  end;
end;

procedure TNullableWritingTests.NativeTypes;
var
  Stamp: TSQLTimeStamp;
  Offset: TSQLTimeStampOffset;
begin
  TNativeCheck.Check<ShortInt>(-12, qtInteger);
  TNativeCheck.Check<SmallInt>(-1234, qtInteger);
  TNativeCheck.Check<Integer>(42, qtInteger);
  TNativeCheck.Check<Integer>(0, qtInteger);
  TNativeCheck.Check<Int64>(Low(Int64), qtInt64);
  TNativeCheck.Check<Byte>(255, qtInteger);
  TNativeCheck.Check<Word>(65535, qtInteger);
  TNativeCheck.Check<Cardinal>(High(Cardinal), qtInt64);
  TNativeCheck.Check<UInt64>(High(UInt64), qtInt64);
  TNativeCheck.Check<Boolean>(False, qtBoolean);
  TNativeCheck.Check<Boolean>(True, qtBoolean);
  TNativeCheck.Check<string>('', qtString);
  TNativeCheck.Check<string>('hello nullable', qtString);
  TNativeCheck.Check<Single>(1.25, qtFloat);
  TNativeCheck.Check<Double>(1.23456789, qtFloat);
  TNativeCheck.Check<Extended>(1.234567890123, qtFloat);
  TNativeCheck.Check<Currency>(1234567.1234, qtCurrency);
  TNativeCheck.Check<TDateTime>(EncodeDate(2026, 10, 25), qtDateTime);
  TNativeCheck.Check<TBcd>(StrToBcd('12345678901234567890.12345678',
    TFormatSettings.Invariant), qtDecimal);
  Stamp := DateTimeToSQLTimeStamp(EncodeDate(2026, 10, 25));
  Stamp.Fractions := 123456789;
  TNativeCheck.Check<TSQLTimeStamp>(Stamp, qtTimestamp);
  Offset := DateTimeToSQLTimeStampOffset(EncodeDate(2026, 10, 25), 5, 45);
  Offset.Fractions := 987654321;
  TNativeCheck.Check<TSQLTimeStampOffset>(Offset, qtTimestampOffset);
  TNativeCheck.Check<TGUID>
    (StringToGUID('{937BFC29-C522-491C-8359-2D5DA373AB91}'), qtGuid);
  TNativeCheck.Check<TBytes>(nil, qtBinary);
  TNativeCheck.Check<TBytes>(TBytes.Create(0, 255, 42), qtBinary);
end;

procedure TNullableWritingTests.PredicatesAndKeys;
var
  DTO: TKeyDTO;
  Q: IQuery;
  R: ISqlResult;
begin
  DTO := TKeyDTO.Create;
  try
    DTO.Id := TNullable<Integer>.Create(0);
    Q := TQuery.Create('Books').Where('Original', 9)
      .AsUpdate(['Title'], ['original']);
    Assert.WillRaise(
      procedure
      begin
        Q.AsUpdate(DTO);
      end, EQueryMappingException);
    Assert.AreEqual<NativeInt>(1, Length(Q.GetComponents('where')));
    R := TSqliteCompiler.Create.Compile(Q);
    Assert.AreEqual('original', R.Bindings[0].AsString);
    DTO.Second := TNullable<Integer>.Create(42);
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Books').AsUpdate(DTO));
    Assert.AreEqual<NativeInt>(4, R.Bindings.Count);
    Assert.AreEqual(0, R.Bindings[0].AsInteger);
    Assert.AreEqual(42, R.Bindings[1].AsInteger);
    Assert.AreEqual(0, R.Bindings[2].AsInteger);
    Assert.AreEqual(42, R.Bindings[3].AsInteger);
    DTO.Id := TNullable<Integer>.Null;
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Books').Select('*')
      .&Not.Where(DTO));
    Assert.IsTrue(Pos('"book_id" IS NOT NULL', R.Sql) > 0);
    Assert.AreEqual<NativeInt>(1, R.Bindings.Count);
  finally
    DTO.Free;
  end;
end;

procedure TNullableWritingTests.ManagedLifetimeAndFailures;
var
  DTO: TInheritedDTO;
  Bytes: TNullableDTO<TBytes>;
  Pairs: TArray<TPair<string, TValue>>;
  R: ISqlResult;
begin
  DTO := TInheritedDTO.Create;
  try
    DTO.Value := TNullable<string>.Create(StringOfChar('x', 2048));
    Pairs := TQueryDataMapper.GetPairs(DTO);
    Assert.AreEqual<NativeInt>(1, Length(Pairs));
  finally
    DTO.Free;
  end;
  Assert.AreEqual(2048, Length(Pairs[0].Value.AsString));
  Bytes := TNullableDTO<TBytes>.Create;
  try
    Bytes.Value := TNullable<TBytes>.Create(TBytes.Create(0, 255));
    R := TSqliteCompiler.Create.Compile(TQuery.Create('Items').AsInsert(Bytes));
  finally
    Bytes.Free;
  end;
  Assert.AreEqual<Byte>(255, R.Bindings[0].AsType<TBytes>[1]);
end;

procedure TNullableWritingTests.CustomRegistration;
var
  Options: TQueryMappingOptions;
  DTO: TNullableDTO<TCode>;
  Code: TCode;
  Pairs: TArray<TPair<string, TValue>>;
  Calls: Integer;
begin
  Options := TQueryMappingOptions.Create;
  DTO := TNullableDTO<TCode>.Create;
  try
    Code.Text := 'custom';
    DTO.Value := TNullable<TCode>.Create(Code);
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(DTO);
      end, EQueryMappingException);
    Options.RegisterNullable<TCode>;
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(DTO, nil, Options);
      end, EQueryMappingException);
    Calls := 0;
    Options.RegisterConverter<TCode, string>(
      function(Value: TCode): string
      begin
        Inc(Calls);
        Result := Value.Text;
      end);
    Pairs := TQueryDataMapper.GetPairs(DTO, nil, Options);
    Assert.AreEqual('custom', Pairs[0].Value.AsString);
    Options.RegisterConverter<TCode, Integer>(
      function(Value: TCode): Integer
      begin
        raise EInvalidOp.Create('Unused converter');
      end);
    // A second representation does not change the first registered outbound type.
    Pairs := TQueryDataMapper.GetPairs(DTO, nil, Options);
    Assert.AreEqual('custom', Pairs[0].Value.AsString);
    DTO.Value := TNullable<TCode>.Null;
    Pairs := TQueryDataMapper.GetPairs(DTO, nil, Options);
    Assert.AreEqual<TQueryValueType>(qtString,
      Pairs[0].Value.AsType<TQueryNull>.ValueType);
    Assert.AreEqual(2, Calls);
    Options.Free;
    Options := nil;
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(DTO);
      end, EQueryMappingException);
    Options := TQueryMappingOptions.Create;
    Options.RegisterNullable<TCode>;
    Options.RegisterConverter<TCode, string>(
      function(Value: TCode): string
      begin
        raise EInvalidOp.Create('Converter failed');
      end);
    DTO.Value := TNullable<TCode>.Create(Code);
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(DTO, nil, Options);
      end, EInvalidOp);
  finally
    DTO.Free;
    Options.Free;
  end;
end;

procedure TNullableWritingTests.GetterAndCallbackFailures;
var
  DTO: TFailingDTO;
  Good: TKeyDTO;
  Calls: Integer;
  Q: IQuery;
begin
  DTO := TFailingDTO.Create;
  Good := TKeyDTO.Create;
  try
    DTO.Id := TNullable<Integer>.Create(1);
    DTO.Second := TNullable<Integer>.Create(2);
    Calls := 0;
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(DTO,
          procedure(Name: string; Value: TValue)
          begin
            Inc(Calls);
          end);
      end, EInvalidOp);
    Assert.AreEqual(0, Calls);
    Q := TQuery.Create('Books').AsUpdate(['Title'], ['original']);
    Assert.WillRaise(
      procedure
      begin
        Q.AsUpdate(DTO);
      end, EInvalidOp);
    Assert.IsFalse(Q.HasConditions);
    Good.Id := DTO.Id;
    Good.Second := DTO.Second;
    Assert.WillRaise(
      procedure
      begin
        TQueryDataMapper.GetPairs(Good,
          procedure(Name: string; Value: TValue)
          begin
            raise EInvalidOp.Create('Callback failed');
          end);
      end, EInvalidOp);
    Q.AsUpdate(Good);
    Assert.AreEqual<NativeInt>(2, Length(Q.GetComponents('where')));
  finally
    Good.Free;
    DTO.Free;
  end;
end;

procedure TNullableWritingTests.DialectPredicates;
var
  Dialect: TSqlDialect;
  C: ICompiler;
  DTO: TNullableDTO<Integer>;
  R: ISqlResult;
begin
  DTO := TNullableDTO<Integer>.Create;
  try
    for Dialect := Low(TSqlDialect) to High(TSqlDialect) do
    begin
      C := TQueryCompilerFactory.CreateCompiler(Dialect);
      R := C.Compile(TQuery.Create('Books').Where('seed', 1).Where(DTO)
        .Having(DTO).Having('tail', 2));
      Assert.IsTrue(Pos(' IS NULL', R.Sql) > 0);
      Assert.IsTrue(Pos('= NULL', R.Sql) = 0);
      Assert.AreEqual<NativeInt>(2, R.Bindings.Count);
      Assert.AreEqual(1, R.Bindings[0].AsInteger);
      Assert.AreEqual(2, R.Bindings[1].AsInteger);
      DTO.Value := TNullable<Integer>.Create(0);
      R := C.Compile(TQuery.Create('Books').Where(DTO).Having(DTO));
      Assert.AreEqual<NativeInt>(2, R.Bindings.Count);
      Assert.AreEqual(0, R.Bindings[0].AsInteger);
      Assert.AreEqual(0, R.Bindings[1].AsInteger);
      DTO.Value := TNullable<Integer>.Null;
    end;
  finally
    DTO.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TNullableWritingTests);

end.
