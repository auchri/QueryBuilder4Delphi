unit Mapping.Values.Tests;

interface

uses
  System.SysUtils, System.Rtti, System.TypInfo, System.Generics.Collections,
  Data.FmtBcd, Data.SqlTimSt, DUnitX.TestFramework,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Nullable,
  QueryBuilder4Delphi.Mapping;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TTypedDTO<T> = class
  private
    FValue: T;
  public
    property Value: T read FValue write FValue;
  end;

  TNullableBook = class
  private
    FRating: TNullable<Integer>;
    FTitle: TNullable<string>;
    FPublished: TNullable<Boolean>;
    FStamp: TNullable<TDateTime>;
  public
    class var Created, Destroyed: Integer;
    constructor Create;
    destructor Destroy; override;
    property Rating: TNullable<Integer> read FRating write FRating;
    property Title: TNullable<string> read FTitle write FTitle;
    property Published: TNullable<Boolean> read FPublished write FPublished;
    property Stamp: TNullable<TDateTime> read FStamp write FStamp;
  end;
{$RTTI INHERIT}

  TApplicationCode = record
    Text: string;
  end;

  [TestFixture]
  TMappingValueTests = class
  private
    function Rows(const Names: TArray<string>; const Data: TRows): IQueryResult;
    function Map<T>(const Value: TValue;
      Options: TQueryMappingOptions = nil): T;
    procedure Reject<T>(const Value: TValue);
    function NullableOptions: TQueryMappingOptions;
    procedure CheckAutomatic<T>(const Value: T);
  public
    [Test]
    procedure NullableRecordSemantics;
    [Test]
    procedure ClosedGenericPropertyRTTI;
    [Test]
    procedure NullableNullVersusDefaults;
    [Test]
    procedure NullableDateTimeAndManagedLifetime;
    [Test]
    procedure NullableConversionAndFailureOwnership;
    [Test]
    procedure MissingRegistration;
    [Test]
    procedure SkipNullIsScopedAndPreservesConstructor;
    [Test]
    procedure IntegerBoundaries;
    [Test]
    procedure IntegerOverflow;
    [Test]
    procedure ExactIntegerFloatConversions;
    [Test]
    procedure NativeDecimalPrecision;
    [Test]
    procedure ExactCurrencyBcdConversions;
    [Test]
    procedure MinimumCurrencyBcdRoundTrip;
    [Test]
    procedure RejectsDecimalLossAndOverflow;
    [Test]
    procedure NativeGuidAndBytes;
    [Test]
    procedure NativeTimestampFractionsAndOffsets;
    [Test]
    procedure RejectsAmbiguousConversions;
    [Test]
    procedure ExactCustomConverterAndNullableComposition;
    [Test]
    procedure CustomConverterPrecedesBuiltIns;
    [Test]
    procedure ConverterFailureContextAndOwnership;
    [Test]
    procedure DuplicateAndNilRegistrations;
    [Test]
    procedure ActualValueOverridesMetadata;
    [Test]
    procedure AutomaticFluentFirstAndResultLifetime;
    [Test]
    procedure AutomaticIntegerBoundaries;
    [Test]
    procedure AutomaticScalarsAndAliases;
    [Test]
    procedure AutomaticNativeRecords;
    [Test]
    procedure AutomaticBytes;
    [Test]
    procedure AutomaticStrictConversions;
    [Test]
    procedure AutomaticConcurrentMapping;
    [Test]
    procedure AutomaticFluentListAndRetainedResults;
    [Test]
    procedure AutomaticScopedConverterAndExplicitRegistration;
    [Test]
    procedure ExactConverterToNullableRemainsSupported;
  end;

implementation

uses DUnitX.Assert, Execution.Mock, Mapping.Tests, QueryBuilder4Delphi.Query,
  System.Math, System.Threading;

constructor TNullableBook.Create;
begin
  inherited;
  Inc(Created);
  FRating := TNullable<Integer>.Create(99);
  FTitle := TNullable<string>.Create('constructor');
end;

destructor TNullableBook.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

function TMappingValueTests.Rows(const Names: TArray<string>; const Data: TRows)
  : IQueryResult;
begin
  Result := TMockQueryResult.Create(Names, nil, Data, True, -1);
end;

function TMappingValueTests.Map<T>(const Value: TValue;
  Options: TQueryMappingOptions): T;
var
  Item: TTypedDTO<T>;
begin
  Item := TQueryMapper.FirstOrDefault < TTypedDTO < T >>
    (Rows(['Value'], TRows.Create(TValues.Create(Value))), Options);
  try
    Result := Item.Value;
  finally
    Item.Free;
  end;
end;

procedure TMappingValueTests.Reject<T>(const Value: TValue);
begin
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Map<T>(Value);
    end), EQueryMappingException);
end;

function TMappingValueTests.NullableOptions: TQueryMappingOptions;
begin
  Result := TQueryMappingOptions.Create;
  Result.RegisterNullable<Integer>;
  Result.RegisterNullable<string>;
  Result.RegisterNullable<Boolean>;
  Result.RegisterNullable<TDateTime>;
end;

procedure TMappingValueTests.NullableRecordSemantics;
var
  A, B: TNullable<string>;
  N: TNullable<Integer>;
begin
  N := Default (TNullable<Integer>);
  Assert.IsFalse(N.HasValue);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      N.Value;
    end), EQueryNullValue);
  A := TNullable<string>.Create('managed');
  B := A;
  A := TNullable<string>.Null;
  Assert.IsFalse(A.HasValue);
  Assert.AreEqual('managed', B.Value);
  B := TNullable<string>.Create('');
  Assert.IsTrue(B.HasValue);
  Assert.AreEqual('', B.Value);
  N := TNullable<Integer>.Create(0);
  Assert.IsTrue(N.HasValue);
  Assert.AreEqual(0, N.Value);
end;

procedure TMappingValueTests.ClosedGenericPropertyRTTI;
var
  Context: TRttiContext;
  Prop: TRttiProperty;
  Item: TNullableBook;
begin
  Context := TRttiContext.Create;
  Item := TNullableBook.Create;
  try
    Prop := Context.GetType(TNullableBook).GetProperty('Title');
    Assert.IsNotNull(Prop);
    Assert.IsTrue(Prop.PropertyType.Handle = TypeInfo(TNullable<string>));
    Prop.SetValue(Item, TValue.From < TNullable < string >>
      (TNullable<string>.Create('typed RTTI')));
    Assert.AreEqual('typed RTTI', Prop.GetValue(Item).AsType < TNullable <
      string >>.Value);
    Prop.SetValue(Item, TValue.From < TNullable < string >>
      (TNullable<string>.Null));
    Assert.IsFalse(Item.Title.HasValue);
  finally
    Item.Free;
    Context.Free;
  end;
end;

procedure TMappingValueTests.NullableNullVersusDefaults;
var
  Books: TObjectList<TNullableBook>;
begin
  Books := TQueryMapper.ToList<TNullableBook>
    (Rows(['Rating', 'Title', 'Published', 'Stamp'],
    TRows.Create(TValues.Create(TValue.Empty, TValue.Empty, TValue.Empty,
    TValue.Empty), TValues.Create(0, '', False, TValue.From<TDateTime>(0)))));
  try
    Assert.IsFalse(Books[0].Rating.HasValue);
    Assert.IsFalse(Books[0].Title.HasValue);
    Assert.IsFalse(Books[0].Published.HasValue);
    Assert.IsFalse(Books[0].Stamp.HasValue);
    Assert.IsTrue(Books[1].Rating.HasValue);
    Assert.AreEqual(0, Books[1].Rating.Value);
    Assert.IsTrue(Books[1].Title.HasValue);
    Assert.AreEqual('', Books[1].Title.Value);
    Assert.IsTrue(Books[1].Published.HasValue);
    Assert.IsFalse(Books[1].Published.Value);
    Assert.IsTrue(Books[1].Stamp.HasValue);
    Assert.AreEqual<TDateTime>(0, Books[1].Stamp.Value);
  finally
    Books.Free;
  end;
end;

procedure TMappingValueTests.NullableDateTimeAndManagedLifetime;
var
  Item: TNullableBook;
  Stamp: TDateTime;
  R: IQueryResult;
begin
  Stamp := EncodeDate(2026, 10, 24) + EncodeTime(8, 30, 14, 123);
  R := Rows(['Title', 'Stamp'],
    TRows.Create(TValues.Create('Gr' + #$00FC + #$00DF + 'e',
    TValue.From<TDateTime>(Stamp))));
  Item := TQueryMapper.FirstOrDefault<TNullableBook>(R);
  try
    R := nil;
    Assert.AreEqual('Gr' + #$00FC + #$00DF + 'e', Item.Title.Value);
    Assert.AreEqual<TDateTime>(Stamp, Item.Stamp.Value);
  finally
    Item.Free;
  end;
end;

procedure TMappingValueTests.NullableConversionAndFailureOwnership;
var
  C, D: Integer;
begin
  Assert.AreEqual(42, Map < TNullable < Integer >>
    (TValue.From<Int64>(42)).Value);
  C := TNullableBook.Created;
  D := TNullableBook.Destroyed;
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      TQueryMapper.ToList<TNullableBook>(Rows(['Rating', 'Title'],
        TRows.Create(TValues.Create(1, 'managed first'), TValues.Create(2,
        'managed second'), TValues.Create(TValue.From<Int64>(Int64(High(Integer)
        ) + 1), 'bad')))).Free;
    end), EQueryMappingException);
  Assert.AreEqual(3, TNullableBook.Created - C);
  Assert.AreEqual(3, TNullableBook.Destroyed - D);
end;

procedure TMappingValueTests.MissingRegistration;
begin
  Reject < TNullable < TApplicationCode >> (1);
  Reject < TNullable < TApplicationCode >> (TValue.Empty);
end;

procedure TMappingValueTests.SkipNullIsScopedAndPreservesConstructor;
var
  Options: TQueryMappingOptions;
  Item: TNullableBook;
  Book: TMappingBook;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.SkipNullAssignment := True;
    Item := TQueryMapper.FirstOrDefault<TNullableBook>
      (Rows(['Rating', 'Title'], TRows.Create(TValues.Create(TValue.Empty,
      TValue.Empty))), Options);
    try
      Assert.AreEqual(99, Item.Rating.Value);
      Assert.AreEqual('constructor', Item.Title.Value);
    finally
      Item.Free;
    end;
    Book := TQueryMapper.FirstOrDefault<TMappingBook>
      (Rows(['BookTitle'], TRows.Create(TValues.Create(TValue.Empty))),
      Options);
    try
      Assert.AreEqual('constructor title', Book.Title);
    finally
      Book.Free;
    end;
    Reject<string>(TValue.Empty);
    Assert.AreEqual(0, Map<Integer>(TValue.Empty, Options));
  finally
    Options.Free;
  end;
end;

procedure TMappingValueTests.IntegerBoundaries;
begin
  Assert.AreEqual<Int64>(Low(Int64),
    Map<Int64>(TValue.From<Int64>(Low(Int64))));
  Assert.AreEqual<Int64>(High(Int64),
    Map<Int64>(TValue.From<UInt64>(UInt64(High(Int64)))));
  Assert.AreEqual<UInt64>(High(UInt64),
    Map<UInt64>(TValue.From<UInt64>(High(UInt64))));
  Assert.AreEqual<UInt64>(0, Map<UInt64>(0));
  Assert.AreEqual<UInt64>(UInt64(High(Int64)),
    Map<UInt64>(TValue.From<Int64>(High(Int64))));
  Assert.AreEqual<Cardinal>(High(Cardinal),
    Map<Cardinal>(TValue.From<UInt64>(High(Cardinal))));
  Assert.AreEqual<Int64>(4294967295,
    Map<Int64>(TValue.From<Cardinal>(High(Cardinal))));
  Assert.AreEqual(Low(Integer), Map<Integer>(TValue.From<Int64>(Low(Integer))));
end;

procedure TMappingValueTests.IntegerOverflow;
begin
  Reject<Int64>(TValue.From<UInt64>(High(UInt64)));
  Reject<Integer>(TValue.From<UInt64>(UInt64(High(Integer)) + 1));
  Reject<Cardinal>(TValue.From<UInt64>(UInt64(High(Cardinal)) + 1));
  Reject<Cardinal>(-1);
  Reject<UInt64>(TValue.From<Int64>(-1));
  Reject<Integer>(TValue.From<Int64>(Low(Int64)));
end;

procedure TMappingValueTests.ExactIntegerFloatConversions;
begin
  Assert.AreEqual<Single>(16777216, Map<Single>(TValue.From<Int64>(16777216)));
  Reject<Single>(TValue.From<Int64>(16777217));
  Assert.AreEqual<Double>(9007199254740992.0,
    Map<Double>(TValue.From<UInt64>(9007199254740992)));
  Reject<Double>(TValue.From<UInt64>(9007199254740993));
  Reject<Double>(TValue.From<UInt64>(High(UInt64)));
  Assert.AreEqual<Int64>(Low(Int64),
    Map<Int64>(TValue.From<Double>(-9223372036854775808.0)));
  Assert.AreEqual<UInt64>(UInt64(1) shl 63,
    Map<UInt64>(TValue.From<Double>(9223372036854775808.0)));
  Reject<Int64>(TValue.From<Double>(9223372036854775808.0));
  Reject<UInt64>(TValue.From<Double>(18446744073709551616.0));
  Reject<UInt64>(TValue.From<Double>(-1));
  Assert.AreEqual(42, Map<Integer>(TValue.From<Double>(42)));
  Reject<Integer>(TValue.From<Double>(42.5));
  Reject<Int64>(TValue.From<Double>(Infinity));
  Reject<UInt64>(TValue.From<Double>(NaN));
  if SizeOf(Extended) > 8 then
    Assert.AreEqual<UInt64>(High(UInt64),
      Map<UInt64>(TValue.From<Extended>(Map<Extended>(TValue.From<UInt64>
      (High(UInt64))))))
  else
    Reject<Extended>(TValue.From<UInt64>(High(UInt64)));
end;

procedure TMappingValueTests.NativeDecimalPrecision;
var
  Decimal, Mapped: TBcd;
begin
  Decimal := StrToBcd('1234567890123456789012345678.12345678',
    TFormatSettings.Invariant);
  Mapped := Map<TBcd>(TValue.From<TBcd>(Decimal));
  Assert.AreEqual(0, BcdCompare(Decimal, Mapped));
  Assert.AreEqual(Integer(Decimal.Precision), Integer(Mapped.Precision));
  Assert.AreEqual(Integer(Decimal.SignSpecialPlaces),
    Integer(Mapped.SignSpecialPlaces));
end;

procedure TMappingValueTests.ExactCurrencyBcdConversions;
var
  Money: Currency;
  Decimal: TBcd;
begin
  Money := 123456789.1234;
  Assert.AreEqual<Currency>(Money, Map<Currency>(TValue.From<Currency>(Money)));
  Decimal := Map<TBcd>(TValue.From<Currency>(Money));
  Assert.AreEqual<Currency>(Money, Map<Currency>(TValue.From<TBcd>(Decimal)));
  Money := 922337203685477.5807;
  Decimal := Map<TBcd>(TValue.From<Currency>(Money));
  Assert.AreEqual<Currency>(Money, Map<Currency>(TValue.From<TBcd>(Decimal)));
  Money := -922337203685477.5807;
  Decimal := Map<TBcd>(TValue.From<Currency>(Money));
  Assert.AreEqual<Currency>(Money, Map<Currency>(TValue.From<TBcd>(Decimal)));
end;

procedure TMappingValueTests.MinimumCurrencyBcdRoundTrip;
const
  Maximum: Currency = 922337203685477.5807;
  Quantum: Currency = 0.0001;
var
  Minimum, Mapped: Currency;
  Decimal, Expected: TBcd;
begin
  // Currency subtraction uses fixed-point operands. Avoid negating a positive
  // 922337203685477.5808 literal (which is already outside Currency's range).
  Minimum := -Maximum;
  Minimum := Minimum - Quantum;
  Assert.AreEqual('-922337203685477.5808',
    CurrToStr(Minimum, TFormatSettings.Invariant));
  Expected := StrToBcd('-922337203685477.5808', TFormatSettings.Invariant);
  Decimal := Map<TBcd>(TValue.From<Currency>(Minimum));
  Assert.AreEqual(0, BcdCompare(Expected, Decimal));
  Mapped := Map<Currency>(TValue.From<TBcd>(Decimal));
  Assert.AreEqual<Currency>(Minimum, Mapped);
end;

procedure TMappingValueTests.RejectsDecimalLossAndOverflow;
begin
  Reject<Currency>(TValue.From<TBcd>(StrToBcd('0.00001',
    TFormatSettings.Invariant)));
  Reject<Currency>(TValue.From<TBcd>(StrToBcd('999999999999999999999.25',
    TFormatSettings.Invariant)));
  Reject<Double>(TValue.From<TBcd>(StrToBcd('0.12345678',
    TFormatSettings.Invariant)));
end;

procedure TMappingValueTests.NativeGuidAndBytes;
var
  Id: TGUID;
  Bytes, Mapped: TBytes;
begin
  Id := StringToGUID('{20BF89A2-91B6-45CB-B610-98320D788099}');
  Assert.IsTrue(IsEqualGUID(Id, Map<TGUID>(TValue.From<TGUID>(Id))));
  Bytes := TBytes.Create(0, 255, 1, 42);
  Mapped := Map<TBytes>(TValue.From<TBytes>(Bytes));
  Assert.AreEqual<NativeInt>(4, Length(Mapped));
  Assert.AreEqual<Byte>(255, Mapped[1]);
  Assert.AreEqual<NativeInt>(0, Length(Map<TBytes>(TValue.From<TBytes>(nil))));
  Reject<TBytes>(TValue.Empty);
end;

procedure TMappingValueTests.NativeTimestampFractionsAndOffsets;
var
  Stamp, Mapped: TSQLTimeStamp;
  Offset, MappedOffset: TSQLTimeStampOffset;
begin
  Stamp := DateTimeToSQLTimeStamp(EncodeDate(2026, 10, 24));
  Stamp.Fractions := 123456789;
  Mapped := Map<TSQLTimeStamp>(TValue.From<TSQLTimeStamp>(Stamp));
  Assert.AreEqual<Cardinal>(123456789, Mapped.Fractions);
  Assert.AreEqual(Integer(Stamp.Year), Integer(Mapped.Year));
  Offset := DateTimeToSQLTimeStampOffset(EncodeDate(2026, 10, 24), -3, -30);
  Offset.Fractions := 987654321;
  MappedOffset := Map<TSQLTimeStampOffset>
    (TValue.From<TSQLTimeStampOffset>(Offset));
  Assert.AreEqual<Cardinal>(987654321, MappedOffset.Fractions);
  Assert.AreEqual(-3, Integer(MappedOffset.TimeZoneHour));
  Assert.AreEqual(-30, Integer(MappedOffset.TimeZoneMinute));
  Reject<TDateTime>(TValue.From<TSQLTimeStamp>(Stamp));
  Reject<TSQLTimeStamp>(TValue.From<TSQLTimeStampOffset>(Offset));
  Reject<TDateTime>(TValue.From<TSQLTimeStampOffset>(Offset));
end;

procedure TMappingValueTests.RejectsAmbiguousConversions;
begin
  Reject<Integer>('1,000');
  Reject<Currency>('1.2345');
  Reject<TDateTime>('2026-10-24');
  Reject<TGUID>('{20BF89A2-91B6-45CB-B610-98320D788099}');
  Reject<Boolean>(1);
  Reject<Integer>(TValue.From<Double>(1.5));
  Reject<Single>(TValue.From<Double>(0.1));
  Reject<TBcd>(TValue.From<Double>(0.1));
end;

procedure TMappingValueTests.ExactCustomConverterAndNullableComposition;
var
  Options: TQueryMappingOptions;
  Code: TNullable<TApplicationCode>;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter<string, TApplicationCode>(
      function(Text: string): TApplicationCode
      begin
        Result.Text := 'code:' + Text;
      end);
    Options.RegisterNullable<TApplicationCode>;
    Assert.AreEqual('code:abc', Map<TApplicationCode>('abc', Options).Text);
    Code := Map < TNullable < TApplicationCode >> ('xyz', Options);
    Assert.IsTrue(Code.HasValue);
    Assert.AreEqual('code:xyz', Code.Value.Text);
    Assert.IsFalse(Map < TNullable < TApplicationCode >> (TValue.Empty, Options)
      .HasValue);
    Reject<TApplicationCode>('abc');
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        Map<TApplicationCode>(1, Options);
      end), EQueryMappingException);
  finally
    Options.Free;
  end;
end;

procedure TMappingValueTests.CustomConverterPrecedesBuiltIns;
var
  Options, OtherOptions: TQueryMappingOptions;
  Nullable: TNullable<Integer>;
  Source: TValue;
begin
  Options := TQueryMappingOptions.Create;
  try
    OtherOptions := TQueryMappingOptions.Create;
    try
      Options.RegisterConverter<Int64, Integer>(
        function(Value: Int64): Integer
        begin
          Result := Integer(Value) + 100;
        end);
      Options.RegisterNullable<Integer>;
      OtherOptions.RegisterNullable<Integer>;
      Source := TValue.From<Int64>(42);
      Assert.AreEqual(142, Map<Integer>(Source, Options));
      Assert.AreEqual(42, Map<Integer>(Source));
      // Both halves of the source/target contract must match exactly.
      Assert.AreEqual(42, Map<Integer>(TValue.From<Integer>(42), Options));
      Assert.AreEqual<Int64>(42, Map<Int64>(Source, Options));
      Nullable := Map < TNullable < Integer >> (Source, Options);
      Assert.IsTrue(Nullable.HasValue);
      Assert.AreEqual(142, Nullable.Value);
      Assert.AreEqual(42, Map<Integer>(Source, OtherOptions));
      Nullable := Map < TNullable < Integer >> (Source, OtherOptions);
      Assert.IsTrue(Nullable.HasValue);
      Assert.AreEqual(42, Nullable.Value);
    finally
      OtherOptions.Free;
    end;
  finally
    Options.Free;
  end;
end;

procedure TMappingValueTests.ConverterFailureContextAndOwnership;
var
  Options: TQueryMappingOptions;
  C, D: Integer;
begin
  Options := NullableOptions;
  C := TNullableBook.Created;
  D := TNullableBook.Destroyed;
  try
    Options.RegisterConverter<string, Integer>(
      function(Text: string): Integer
      begin
        raise EConvertError.Create('application conversion failed');
      end);
    try
      TQueryMapper.FirstOrDefault<TNullableBook>
        (Rows(['Rating'], TRows.Create(TValues.Create('invalid'))),
        Options).Free;
      Assert.Fail('Expected converter failure');
    except
      on E: EConvertError do
      begin
        Assert.IsTrue(Pos('TNullableBook.Rating', E.Message) > 0);
        Assert.IsTrue(Pos('row 1', E.Message) > 0);
        Assert.IsTrue(Pos('column "Rating" [0]', E.Message) > 0);
        Assert.IsTrue(Pos('application conversion failed', E.Message) > 0);
      end;
    end;
    Assert.AreEqual(1, TNullableBook.Created - C);
    Assert.AreEqual(1, TNullableBook.Destroyed - D);
  finally
    Options.Free;
  end;
end;

procedure TMappingValueTests.DuplicateAndNilRegistrations;
var
  Options: TQueryMappingOptions;
  Converter: TFunc<string, Integer>;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterNullable<Integer>;
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        Options.RegisterNullable<Integer>;
      end), EQueryMappingException);
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        Options.RegisterConverter<string, Integer>(nil);
      end), EArgumentNilException);
    Converter := function(Text: string): Integer
      begin
        Result := Length(Text);
      end;
    Options.RegisterConverter<string, Integer>(Converter);
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        Options.RegisterConverter<string, Integer>(Converter);
      end), EQueryMappingException);
  finally
    Converter := nil;
    Options.Free;
  end;
end;

procedure TMappingValueTests.ActualValueOverridesMetadata;
var
  R: IQueryResult;
  Item: TTypedDTO<TBcd>;
  Decimal: TBcd;
begin
  Decimal := StrToBcd('123.12345678', TFormatSettings.Invariant);
  R := TMockQueryResult.Create(['Value'], [qtFloat],
    TRows.Create(TValues.Create(TValue.From<TBcd>(Decimal))), True, -1);
  Item := TQueryMapper.FirstOrDefault < TTypedDTO < TBcd >> (R);
  try
    Assert.AreEqual(0, BcdCompare(Decimal, Item.Value));
  finally
    Item.Free;
  end;
end;

procedure TMappingValueTests.AutomaticFluentFirstAndResultLifetime;
var
  R: TQueryResult;
  Executor: IQueryExecutor;
  Item: TNullableBook;
  Baseline: Integer;
begin
  Baseline := TMockQueryResult.LiveCount;
  Executor := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  TMockQueryExecutor.Names := TArray<string>.Create('Rating');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(TValue.Empty));
  R := TQuery.Create('Books').Execute(Executor);
  Item := R.FirstOrDefault<TNullableBook>();
  try
    Assert.IsFalse(Item.Rating.HasValue);
    Assert.IsNull(R.AsRaw);
    Assert.AreEqual(Baseline, TMockQueryResult.LiveCount);
  finally
    Item.Free;
  end;
end;

procedure TMappingValueTests.CheckAutomatic<T>(const Value: T);
var
  Mapped: TNullable<T>;
begin
  Mapped := Map < TNullable < T >> (TValue.From<T>(Value));
  Assert.IsTrue(Mapped.HasValue);
  Assert.AreEqual<T>(Value, Mapped.Value);
  Assert.IsFalse(Map < TNullable < T >> (TValue.Empty).HasValue);
end;

procedure TMappingValueTests.AutomaticIntegerBoundaries;
begin
  CheckAutomatic<ShortInt>(Low(ShortInt));
  CheckAutomatic<ShortInt>(High(ShortInt));
  CheckAutomatic<SmallInt>(Low(SmallInt));
  CheckAutomatic<SmallInt>(High(SmallInt));
  CheckAutomatic<Integer>(Low(Integer));
  CheckAutomatic<Integer>(High(Integer));
  CheckAutomatic<Int64>(Low(Int64));
  CheckAutomatic<Int64>(High(Int64));
  CheckAutomatic<Byte>(0);
  CheckAutomatic<Byte>(High(Byte));
  CheckAutomatic<Word>(0);
  CheckAutomatic<Word>(High(Word));
  CheckAutomatic<Cardinal>(0);
  CheckAutomatic<Cardinal>(High(Cardinal));
  CheckAutomatic<UInt64>(0);
  CheckAutomatic<UInt64>(High(UInt64));
end;

procedure TMappingValueTests.AutomaticScalarsAndAliases;
begin
  CheckAutomatic<Boolean>(False);
  CheckAutomatic<string>('');
  CheckAutomatic<Single>(1.25);
  CheckAutomatic<Double>(1.25);
  CheckAutomatic<Extended>(1.25);
  CheckAutomatic<Currency>(123456789.1234);
  CheckAutomatic<TDateTime>(EncodeDate(2026, 10, 24));
  // Verify both compiler identities rather than assuming Extended = Double.
  Assert.AreEqual(TypeInfo(Double) = TypeInfo(Extended),
    TypeInfo(TNullable<Double>) = TypeInfo(TNullable<Extended>));
  Assert.AreEqual(TypeInfo(Double) = TypeInfo(TDateTime),
    TypeInfo(TNullable<Double>) = TypeInfo(TNullable<TDateTime>));
end;

procedure TMappingValueTests.AutomaticNativeRecords;
var
  Decimal, ActualDecimal: TBcd;
  Id: TGUID;
  Stamp, ActualStamp: TSQLTimeStamp;
  Offset, ActualOffset: TSQLTimeStampOffset;
begin
  Decimal := StrToBcd('123456789.123456789', TFormatSettings.Invariant);
  ActualDecimal := Map < TNullable < TBcd >> (TValue.From<TBcd>(Decimal)).Value;
  Assert.AreEqual(0, BcdCompare(Decimal, ActualDecimal));
  Assert.IsFalse(Map < TNullable < TBcd >> (TValue.Empty).HasValue);
  Id := StringToGUID('{20BF89A2-91B6-45CB-B610-98320D788099}');
  Assert.IsTrue(IsEqualGUID(Id, Map < TNullable < TGUID >>
    (TValue.From<TGUID>(Id)).Value));
  Assert.IsFalse(Map < TNullable < TGUID >> (TValue.Empty).HasValue);
  Stamp := DateTimeToSQLTimeStamp(EncodeDate(2026, 10, 24));
  Stamp.Fractions := 123456789;
  ActualStamp := Map < TNullable < TSQLTimeStamp >>
    (TValue.From<TSQLTimeStamp>(Stamp)).Value;
  Assert.AreEqual<Cardinal>(Stamp.Fractions, ActualStamp.Fractions);
  Assert.AreEqual(Integer(Stamp.Year), Integer(ActualStamp.Year));
  Assert.IsFalse(Map < TNullable < TSQLTimeStamp >> (TValue.Empty).HasValue);
  Offset := DateTimeToSQLTimeStampOffset(EncodeDate(2026, 10, 24), -3, -30);
  Offset.Fractions := 987654321;
  ActualOffset := Map < TNullable < TSQLTimeStampOffset >>
    (TValue.From<TSQLTimeStampOffset>(Offset)).Value;
  Assert.AreEqual<Cardinal>(Offset.Fractions, ActualOffset.Fractions);
  Assert.AreEqual(-3, Integer(ActualOffset.TimeZoneHour));
  Assert.AreEqual(-30, Integer(ActualOffset.TimeZoneMinute));
  Assert.IsFalse(Map < TNullable < TSQLTimeStampOffset >> (TValue.Empty)
    .HasValue);
end;

procedure TMappingValueTests.AutomaticBytes;
var
  Value: TNullable<TBytes>;
begin
  Value := Map < TNullable < TBytes >> (TValue.From<TBytes>(nil));
  Assert.IsTrue(Value.HasValue);
  Assert.AreEqual<NativeInt>(0, Length(Value.Value));
  Value := Map < TNullable < TBytes >>
    (TValue.From<TBytes>(TBytes.Create(0, 255, 42)));
  Assert.IsTrue(Value.HasValue);
  Assert.AreEqual<NativeInt>(3, Length(Value.Value));
  Assert.AreEqual<Byte>(255, Value.Value[1]);
  Assert.IsFalse(Map < TNullable < TBytes >> (TValue.Empty).HasValue);
end;

procedure TMappingValueTests.AutomaticStrictConversions;
var
  Decimal: TBcd;
begin
  Assert.AreEqual(42, Map < TNullable < Integer >>
    (TValue.From<Int64>(42)).Value);
  Reject < TNullable < Integer >>
    (TValue.From<Int64>(Int64(High(Integer)) + 1));
  Reject < TNullable < UInt64 >> (TValue.From<Int64>(-1));
  Reject < TNullable < Int64 >> (TValue.From<UInt64>(High(UInt64)));
  Reject < TNullable < Integer >> (TValue.From<Double>(1.5));
  Reject < TNullable < Single >> (TValue.From<Double>(0.1));
  Reject < TNullable < Double >> (TValue.From<Int64>(9007199254740993));
  Reject < TNullable < Currency >>
    (TValue.From<TBcd>(StrToBcd('0.00001', TFormatSettings.Invariant)));
  Reject < TNullable < Currency >>
    (TValue.From<TBcd>(StrToBcd('999999999999999999999',
    TFormatSettings.Invariant)));
  Reject < TNullable < Boolean >> (0);
  Reject<Integer>(TValue.Empty);
  Decimal := Map < TNullable < TBcd >> (TValue.From<Currency>(123.4567)).Value;
  Assert.AreEqual<Currency>(123.4567, Map < TNullable < Currency >>
    (TValue.From<TBcd>(Decimal)).Value);
end;

procedure TMappingValueTests.AutomaticConcurrentMapping;
begin
  TParallel.For(0, 127,
    procedure(Index: Integer)
    begin
      Assert.AreEqual(Index, Map < TNullable < Integer >>
        (TValue.From<Int64>(Index)).Value);
      Assert.IsFalse(Map < TNullable < string >> (TValue.Empty).HasValue);
      Assert.AreEqual('parallel', Map < TNullable < string >>
        ('parallel').Value);
      Assert.IsTrue(Map < TNullable < TBytes >> (TValue.From<TBytes>(nil))
        .HasValue);
    end);
end;

procedure TMappingValueTests.AutomaticFluentListAndRetainedResults;
var
  A, B: TQueryResult;
  Raw, Empty: IQueryResult;
  Item: TNullableBook;
  Books: TObjectList<TNullableBook>;
  Executor: IQueryExecutor;
  Baseline: Integer;
begin
  Baseline := TMockQueryResult.LiveCount;
  Executor := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  TMockQueryExecutor.Names := TArray<string>.Create('Rating');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(TValue.Empty),
    TValues.Create(0));
  Books := TQuery.Create('Books').Execute(Executor).ToList<TNullableBook>();
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.IsFalse(Books[0].Rating.HasValue);
    Assert.IsTrue(Books[1].Rating.HasValue);
    Assert.AreEqual(0, Books[1].Rating.Value);
    Assert.AreEqual(Baseline, TMockQueryResult.LiveCount);
  finally
    Books.Free;
  end;
  A := TQuery.Create('Books').Where('Id', 42).Execute(Executor);
  B := A;
  Raw := A.AsRaw;
  Item := A.FirstOrDefault<TNullableBook>();
  try
    Assert.IsFalse(Item.Rating.HasValue);
    Empty := A.AsRaw;
    Assert.IsNull(Empty);
    Assert.AreEqual(Baseline + 1, TMockQueryResult.LiveCount);
    Assert.IsTrue(B.Next);
    Assert.AreEqual(0, Raw.GetValue('Rating').AsInteger);
    B := Default (TQueryResult);
    Raw := nil;
    Assert.AreEqual(Baseline, TMockQueryResult.LiveCount);
  finally
    Item.Free;
  end;
end;

procedure TMappingValueTests.AutomaticScopedConverterAndExplicitRegistration;
var
  Options: TQueryMappingOptions;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter<Int64, Integer>(
      function(Value: Int64): Integer
      begin
        Result := Integer(Value) + 100;
      end);
    // The default callback uses this operation's converter without capturing it.
    Assert.AreEqual(142, Map < TNullable < Integer >> (TValue.From<Int64>(42),
      Options).Value);
    Assert.AreEqual(42, Map < TNullable < Integer >>
      (TValue.From<Int64>(42)).Value);
    Options.RegisterNullable<Integer>;
    Assert.AreEqual(142, Map < TNullable < Integer >> (TValue.From<Int64>(42),
      Options).Value);
    Assert.IsFalse(Map < TNullable < Integer >> (TValue.Empty, Options)
      .HasValue);
  finally
    Options.Free;
  end;
  // No callback retained the freed options instance.
  Assert.AreEqual(42, Map < TNullable < Integer >>
    (TValue.From<Int64>(42)).Value);
end;

procedure TMappingValueTests.ExactConverterToNullableRemainsSupported;
var
  Options: TQueryMappingOptions;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter < Int64, TNullable < Integer >> (
      function(Value: Int64): TNullable<Integer>
      begin
        Result := TNullable<Integer>.Create(Integer(Value) + 200);
      end);
    Assert.AreEqual(242, Map < TNullable < Integer >> (TValue.From<Int64>(42),
      Options).Value);
    Assert.AreEqual(42, Map < TNullable < Integer >>
      (TValue.From<Int64>(42)).Value);
    Assert.IsFalse(Map < TNullable < Integer >> (TValue.Empty, Options)
      .HasValue);
    // Explicit nullable construction still takes precedence over a converter
    // returning the whole record, as it did before built-in registrations.
    Options.RegisterNullable<Integer>;
    Assert.AreEqual(42, Map < TNullable < Integer >> (TValue.From<Int64>(42),
      Options).Value);
  finally
    Options.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TMappingValueTests);

end.
