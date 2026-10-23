unit Mapping.Tests;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  DUnitX.TestFramework, QueryBuilder4Delphi.Query.Core;

type
  // Explicitly request public property RTTI; no RTTI for fields is needed.
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic, vcPublished]) FIELDS([])}
  TMappingBook = class
  private
    FId: Integer;
    FTitle, FIgnored, FDefault: string;
  public
    class var Created, Destroyed: Integer;
    constructor Create;
    destructor Destroy; override;
    [Key('BookId')]
    property Id: Integer read FId write FId;
    [Column('BookTitle')]
    property Title: string read FTitle write FTitle;
    [Ignore]
    property Ignored: string read FIgnored write FIgnored;
    property DefaultValue: string read FDefault write FDefault;
    property ReadOnly: string read FDefault;
  end;

  TScalarDTO = class
  private
    FId: Integer;
    FBig: Int64;
    FFlag: Boolean;
    FText: string;
    FSingle: Single;
    FDouble: Double;
    FExtended: Extended;
    FMoney: Currency;
    FStamp: TDateTime;
    FBytes: TBytes;
  public
    property Id: Integer read FId write FId;
    property Big: Int64 read FBig write FBig;
    property Flag: Boolean read FFlag write FFlag;
    property Text: string read FText write FText;
    property SmallFloat: Single read FSingle write FSingle;
    property Float: Double read FDouble write FDouble;
    property LargeFloat: Extended read FExtended write FExtended;
    property Money: Currency read FMoney write FMoney;
    property Stamp: TDateTime read FStamp write FStamp;
    property Bytes: TBytes read FBytes write FBytes;
  end;

  TSetterDTO = class
  private
    FId: Integer;
    procedure SetId(Value: Integer);
  public
    property Id: Integer read FId write SetId;
  end;

  TReadOnlyDTO = class
  private
    FId: Integer;
  public
    property Id: Integer read FId;
  end;

  TConcurrentDTO = class
  private
    FId: Integer;
  public
    property Id: Integer read FId write FId;
  end;

{$M+}

  TPublishedDTO = class
  private
    FId: Integer;
  published
    property Id: Integer read FId write FId;
  end;
{$M-}
{$RTTI EXPLICIT METHODS([]) PROPERTIES([]) FIELDS([])}

  TNoRTTIDTO = class
  private
    FId: Integer;
  public
    property Id: Integer read FId write FId;
  end;
{$RTTI INHERIT}

  [TestFixture]
  TMappingTests = class
  private
    function Rows(const Names: TArray<string>; const Data: TRows): IQueryResult;
    procedure ExpectFailure(const Column: string; const Value: TValue;
      const SourceName, TargetName: string);
  public
    [Test]
    procedure MultipleRowsAndOwnership;
    [Test]
    procedure EmptyResults;
    [Test]
    procedure FirstConsumesOneRemainingRow;
    [Test]
    procedure AttributesAliasesPartialAndExtraColumns;
    [Test]
    procedure RepeatedSchemasAndChangedOrder;
    [Test]
    procedure AmbiguousMappedColumns;
    [Test]
    procedure UnmappedDuplicatesAreIgnored;
    [Test]
    procedure ScalarValues;
    [Test]
    procedure LosslessNumericConversions;
    [Test]
    procedure RejectsLossyAndUnsupportedConversions;
    [Test]
    procedure NullFailsAndReleasesObject;
    [Test]
    procedure EmptyBytesAreUnsupportedNotNull;
    [Test]
    procedure ThirdRowFailureReleasesAllObjects;
    [Test]
    procedure SetterExceptionIsPreserved;
    [Test]
    procedure MissingWritableRTTI;
    [Test]
    procedure NilAndCommandResults;
    [Test]
    procedure FirstFailureReleasesObject;
    [Test]
    procedure ConcurrentMetadataAndSchemas;
    [Test]
    procedure PublishedProperties;
    [Test]
    procedure ColumnPlanIsResolvedOnce;
  end;

implementation

uses
  System.TypInfo, System.Threading, DUnitX.Assert, Execution.Mock,
  QueryBuilder4Delphi.Mapping;

constructor TMappingBook.Create;
begin
  inherited;
  Inc(Created);
  FTitle := 'constructor title';
  FIgnored := 'ignored default';
  FDefault := 'constructor default';
end;

destructor TMappingBook.Destroy;
begin
  Inc(Destroyed);
  inherited;
end;

procedure TSetterDTO.SetId(Value: Integer);
begin
  raise EInvalidOp.Create('setter failed');
end;

function TMappingTests.Rows(const Names: TArray<string>; const Data: TRows)
  : IQueryResult;
begin
  Result := TMockQueryResult.Create(Names, nil, Data, True, -1);
end;

procedure TMappingTests.MultipleRowsAndOwnership;
var
  R: IQueryResult;
  Books: TObjectList<TMappingBook>;
  BeforeCreated, BeforeDestroyed, BeforeResults: Integer;
begin
  BeforeCreated := TMappingBook.Created;
  BeforeDestroyed := TMappingBook.Destroyed;
  BeforeResults := TMockQueryResult.LiveCount;
  R := Rows(['BookId', 'BookTitle'], TRows.Create(TValues.Create(1, 'Alpha'),
    TValues.Create(2, 'Beta')));
  Books := TQueryMapper.ToList<TMappingBook>(R);
  try
    Assert.IsTrue(Books.OwnsObjects);
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.AreEqual(1, Books[0].Id);
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual(2, Books[1].Id);
    Assert.AreEqual('Beta', Books[1].Title);
    Assert.IsFalse(R.Next);
  finally
    Books.Free;
  end;
  Assert.AreEqual(BeforeCreated + 2, TMappingBook.Created);
  Assert.AreEqual(BeforeDestroyed + 2, TMappingBook.Destroyed);
  Assert.AreEqual(BeforeResults + 1, TMockQueryResult.LiveCount);
  R := nil;
  Assert.AreEqual(BeforeResults, TMockQueryResult.LiveCount);
end;

procedure TMappingTests.EmptyResults;
var
  Books: TObjectList<TMappingBook>;
  Book: TMappingBook;
begin
  Books := TQueryMapper.ToList<TMappingBook>(Rows(['BookId'], nil));
  try
    Assert.AreEqual<NativeInt>(0, Books.Count);
  finally
    Books.Free;
  end;
  Book := TQueryMapper.FirstOrDefault<TMappingBook>(Rows(['BookId'], nil));
  try
    Assert.IsNull(Book);
  finally
    Book.Free;
  end;
end;

procedure TMappingTests.FirstConsumesOneRemainingRow;
var
  R: IQueryResult;
  Book: TMappingBook;
begin
  R := Rows(['BookId'], TRows.Create(TValues.Create(1), TValues.Create(2),
    TValues.Create(3)));
  Assert.IsTrue(R.Next);
  Book := TQueryMapper.FirstOrDefault<TMappingBook>(R);
  try
    Assert.AreEqual(2, Book.Id);
  finally
    Book.Free;
  end;
  Assert.IsTrue(R.Next);
  Assert.AreEqual(3, R.GetValue(0).AsInteger);
end;

procedure TMappingTests.AttributesAliasesPartialAndExtraColumns;
var
  Book: TMappingBook;
begin
  Book := TQueryMapper.FirstOrDefault<TMappingBook>
    (Rows(['bOoKiD', 'BOOKTITLE', 'ignored', 'ReadOnly', 'extra'],
    TRows.Create(TValues.Create(7, 'alias value', 'overwrite', 'overwrite',
    TValue.Empty))));
  try
    Assert.AreEqual(7, Book.Id);
    Assert.AreEqual('alias value', Book.Title);
    Assert.AreEqual('ignored default', Book.Ignored);
    Assert.AreEqual('constructor default', Book.DefaultValue);
    Assert.AreEqual('constructor default', Book.ReadOnly);
  finally
    Book.Free;
  end;
end;

procedure TMappingTests.RepeatedSchemasAndChangedOrder;
var
  I: Integer;
  Book: TMappingBook;
begin
  for I := 1 to 5 do
  begin
    Book := TQueryMapper.FirstOrDefault<TMappingBook>
      (Rows(['BookId', 'BookTitle'], TRows.Create(TValues.Create(I,
      'normal'))));
    try
      Assert.AreEqual(I, Book.Id);
      Assert.AreEqual('normal', Book.Title);
    finally
      Book.Free;
    end;
    Book := TQueryMapper.FirstOrDefault<TMappingBook>
      (Rows(['BookTitle', 'BookId'], TRows.Create(TValues.Create('reordered',
      I + 10))));
    try
      Assert.AreEqual(I + 10, Book.Id);
      Assert.AreEqual('reordered', Book.Title);
    finally
      Book.Free;
    end;
    Book := TQueryMapper.FirstOrDefault<TMappingBook>
      (Rows(['BookTitle'], TRows.Create(TValues.Create('partial'))));
    try
      Assert.AreEqual(0, Book.Id);
      Assert.AreEqual('partial', Book.Title);
    finally
      Book.Free;
    end;
  end;
end;

procedure TMappingTests.AmbiguousMappedColumns;
begin
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ToList<TMappingBook>(Rows(['BookId', 'BOOKID'],
        TRows.Create(TValues.Create(1, 2)))).Free;
    end, EQueryMappingException);
end;

procedure TMappingTests.UnmappedDuplicatesAreIgnored;
var
  Book: TMappingBook;
begin
  Book := TQueryMapper.FirstOrDefault<TMappingBook>
    (Rows(['other', 'OTHER'], TRows.Create(TValues.Create(TValue.Empty, 2))));
  try
    Assert.AreEqual(0, Book.Id);
    Assert.AreEqual('constructor title', Book.Title);
  finally
    Book.Free;
  end;
end;

procedure TMappingTests.ScalarValues;
var
  Item: TScalarDTO;
  Stamp: TDateTime;
begin
  Stamp := EncodeDate(2026, 10, 23) + EncodeTime(12, 30, 0, 0);
  Item := TQueryMapper.FirstOrDefault<TScalarDTO>
    (Rows(['id', 'big', 'flag', 'text', 'SmallFloat', 'Float', 'LargeFloat',
    'Money', 'Stamp'], TRows.Create(TValues.Create(42,
    TValue.From<Int64>(5000000000), True, 'Gr' + #$00FC + #$00DF + 'e',
    TValue.From<Single>(1.25), TValue.From<Double>(2.5),
    TValue.From<Extended>(3.75), TValue.From<Currency>(12.34),
    TValue.From<TDateTime>(Stamp)))));
  try
    Assert.AreEqual(42, Item.Id);
    Assert.AreEqual<Int64>(5000000000, Item.Big);
    Assert.IsTrue(Item.Flag);
    Assert.AreEqual('Gr' + #$00FC + #$00DF + 'e', Item.Text);
    Assert.AreEqual<Single>(1.25, Item.SmallFloat);
    Assert.AreEqual<Double>(2.5, Item.Float);
    Assert.AreEqual<Extended>(3.75, Item.LargeFloat);
    Assert.AreEqual<Currency>(12.34, Item.Money);
    Assert.AreEqual<TDateTime>(Stamp, Item.Stamp);
  finally
    Item.Free;
  end;
  Item := TQueryMapper.FirstOrDefault<TScalarDTO>
    (Rows(['Text', 'Flag'], TRows.Create(TValues.Create('', False))));
  try
    Assert.AreEqual('', Item.Text);
    Assert.IsFalse(Item.Flag);
  finally
    Item.Free;
  end;
end;

procedure TMappingTests.LosslessNumericConversions;
var
  Item: TScalarDTO;
begin
  Item := TQueryMapper.FirstOrDefault<TScalarDTO>
    (Rows(['Id', 'Big', 'SmallFloat', 'Float', 'LargeFloat'],
    TRows.Create(TValues.Create(TValue.From<Int64>(High(Integer)),
    TValue.From<Cardinal>(High(Cardinal)), TValue.From<Double>(1.5),
    TValue.From<Single>(2.5), TValue.From<Double>(3.5)))));
  try
    Assert.AreEqual(High(Integer), Item.Id);
    Assert.AreEqual<Int64>(4294967295, Item.Big);
    Assert.AreEqual<Single>(1.5, Item.SmallFloat);
    Assert.AreEqual<Double>(2.5, Item.Float);
    Assert.AreEqual<Extended>(3.5, Item.LargeFloat);
  finally
    Item.Free;
  end;
end;

procedure TMappingTests.ExpectFailure(const Column: string; const Value: TValue;
const SourceName, TargetName: string);
begin
  try
    TQueryMapper.FirstOrDefault<TScalarDTO>
      (Rows([Column], TRows.Create(TValues.Create(Value)))).Free;
    Assert.Fail('Expected mapping failure');
  except
    on E: EQueryMappingException do
    begin
      Assert.IsTrue(Pos('TScalarDTO.' + Column, E.Message) > 0, E.Message);
      Assert.IsTrue(Pos('source ' + SourceName, E.Message) > 0, E.Message);
      Assert.IsTrue(Pos('target ' + TargetName, E.Message) > 0, E.Message);
      Assert.IsTrue(Pos('row 1', E.Message) > 0, E.Message);
    end;
  end;
end;

procedure TMappingTests.RejectsLossyAndUnsupportedConversions;
begin
  ExpectFailure('Id', TValue.From<Int64>(Int64(High(Integer)) + 1), 'Int64',
    'Integer');
  ExpectFailure('Id', TValue.From<Int64>(Int64(Low(Integer)) - 1), 'Int64',
    'Integer');
  ExpectFailure('Id', '123', string(PTypeInfo(TypeInfo(string))^.Name),
    'Integer');
  ExpectFailure('Id', TValue.From<Double>(1.5), 'Double', 'Integer');
  ExpectFailure('Flag', 1, 'Integer', 'Boolean');
  ExpectFailure('SmallFloat', TValue.From<Double>(0.1), 'Double', 'Single');
  ExpectFailure('Money', '12,34', string(PTypeInfo(TypeInfo(string))^.Name),
    'Currency');
  ExpectFailure('Stamp', '2026-10-23',
    string(PTypeInfo(TypeInfo(string))^.Name), 'TDateTime');
  ExpectFailure('Text', 12, 'Integer',
    string(PTypeInfo(TypeInfo(string))^.Name));
end;

procedure TMappingTests.NullFailsAndReleasesObject;
begin
  ExpectFailure('Id', TValue.Empty, 'SQL NULL', 'Integer');
  ExpectFailure('Text', TValue.Empty, 'SQL NULL',
    string(PTypeInfo(TypeInfo(string))^.Name));
  ExpectFailure('Flag', TValue.Empty, 'SQL NULL', 'Boolean');
end;

procedure TMappingTests.EmptyBytesAreUnsupportedNotNull;
begin
  ExpectFailure('Bytes', TValue.From<TBytes>(nil),
    string(PTypeInfo(TypeInfo(TBytes))^.Name),
    string(PTypeInfo(TypeInfo(TBytes))^.Name));
end;

procedure TMappingTests.ThirdRowFailureReleasesAllObjects;
var
  BeforeCreated, BeforeDestroyed: Integer;
  R: IQueryResult;
begin
  BeforeCreated := TMappingBook.Created;
  BeforeDestroyed := TMappingBook.Destroyed;
  R := Rows(['BookId'], TRows.Create(TValues.Create(1), TValues.Create(2),
    TValues.Create('invalid'), TValues.Create(4)));
  try
    TQueryMapper.ToList<TMappingBook>(R).Free;
    Assert.Fail('Expected third row failure');
  except
    on E: EQueryMappingException do
      Assert.IsTrue(Pos('row 3', E.Message) > 0, E.Message);
  end;
  Assert.AreEqual(BeforeCreated + 3, TMappingBook.Created);
  Assert.AreEqual(BeforeDestroyed + 3, TMappingBook.Destroyed);
  Assert.IsTrue(R.Next, 'Caller still owns the result');
  Assert.AreEqual(4, R.GetValue(0).AsInteger);
end;

procedure TMappingTests.SetterExceptionIsPreserved;
begin
  try
    TQueryMapper.FirstOrDefault<TSetterDTO>
      (Rows(['Id'], TRows.Create(TValues.Create(1)))).Free;
    Assert.Fail('Expected setter failure');
  except
    on E: EInvalidOp do
    begin
      Assert.IsTrue(Pos('setter failed', E.Message) > 0);
      Assert.IsTrue(Pos('TSetterDTO.Id', E.Message) > 0);
    end;
  end;
end;

procedure TMappingTests.MissingWritableRTTI;
begin
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.FirstOrDefault<TNoRTTIDTO>(Rows(['Id'],
        TRows.Create(TValues.Create(1)))).Free;
    end, EQueryMappingException);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.FirstOrDefault<TReadOnlyDTO>(Rows(['Id'],
        TRows.Create(TValues.Create(1)))).Free;
    end, EQueryMappingException);
end;

procedure TMappingTests.NilAndCommandResults;
var
  R: IQueryResult;
begin
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ToList<TMappingBook>(nil).Free;
    end, EArgumentNilException);
  R := TMockQueryResult.Create(nil, nil, nil, False, 1);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ToList<TMappingBook>(R).Free;
    end, EQueryMappingException);
end;

procedure TMappingTests.FirstFailureReleasesObject;
var
  BeforeCreated, BeforeDestroyed: Integer;
begin
  BeforeCreated := TMappingBook.Created;
  BeforeDestroyed := TMappingBook.Destroyed;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.FirstOrDefault<TMappingBook>(Rows(['BookTitle'],
        TRows.Create(TValues.Create(TValue.Empty)))).Free;
    end, EQueryMappingException);
  Assert.AreEqual(BeforeCreated + 1, TMappingBook.Created);
  Assert.AreEqual(BeforeDestroyed + 1, TMappingBook.Destroyed);
end;

procedure TMappingTests.ConcurrentMetadataAndSchemas;
var
  Values: TArray<Integer>;
  I, BeforeResults: Integer;
begin
  BeforeResults := TMockQueryResult.LiveCount;
  SetLength(Values, 64);
  TParallel.For(0, Integer(High(Values)),
    procedure(Index: Integer)
    var
      R: IQueryResult;
      Item: TConcurrentDTO;
      Context: TRttiContext;
    begin
      // Cold-cache contention followed by varied projections. Local contexts
      // come and go while the mapper's retained context keeps metadata alive.
      Context := TRttiContext.Create;
      try
        if Odd(Index) then
          R := Rows(['extra', 'ID'],
            TRows.Create(TValues.Create('ignored', Index)))
        else
          R := Rows(['id'], TRows.Create(TValues.Create(Index)));
        Item := TQueryMapper.FirstOrDefault<TConcurrentDTO>(R);
        try
          Values[Index] := Item.Id;
        finally
          Item.Free;
        end;
      finally
        Context.Free;
      end;
    end);
  for I := 0 to High(Values) do
    Assert.AreEqual(I, Values[I]);
  Assert.AreEqual(BeforeResults, TMockQueryResult.LiveCount);
end;

procedure TMappingTests.PublishedProperties;
var
  Item: TPublishedDTO;
begin
  Item := TQueryMapper.FirstOrDefault<TPublishedDTO>
    (Rows(['iD'], TRows.Create(TValues.Create(123))));
  try
    Assert.AreEqual(123, Item.Id);
  finally
    Item.Free;
  end;
end;

procedure TMappingTests.ColumnPlanIsResolvedOnce;
var
  Mock: TMockQueryResult;
  R: IQueryResult;
  Books: TObjectList<TMappingBook>;
begin
  Mock := TMockQueryResult.Create(['BookId', 'BookTitle'], nil,
    TRows.Create(TValues.Create(1, 'one'), TValues.Create(2, 'two'),
    TValues.Create(3, 'three')), True, -1);
  R := Mock;
  Books := TQueryMapper.ToList<TMappingBook>(R);
  try
    Assert.AreEqual<NativeInt>(3, Books.Count);
    Assert.AreEqual(1, Books[0].Id);
    Assert.AreEqual('two', Books[1].Title);
    Assert.AreEqual(3, Books[2].Id);
    Assert.AreEqual('three', Books[2].Title);
    Assert.AreEqual(2, Mock.ColumnNameReads);
    Assert.AreEqual(0, Mock.ColumnIndexLookups);
  finally
    Books.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TMappingTests);

end.
