unit Mapping.Streaming.Tests;

interface

uses System.SysUtils, System.Rtti, DUnitX.TestFramework,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Mapping;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TColdStreamingDTO = class
  private
    FId: Integer;
  public
    property Id: Integer read FId write FId;
  end;

  TOtherColdStreamingDTO = class(TColdStreamingDTO);
{$RTTI INHERIT}

  [TestFixture]
  TMappingStreamingTests = class
  public
    [TestCase('FirstEmpty', '0,0')]
    [TestCase('FirstOne', '0,1')]
    [TestCase('FirstMany', '0,3')]
    [TestCase('DefaultEmpty', '1,0')]
    [TestCase('DefaultOne', '1,1')]
    [TestCase('DefaultMany', '1,3')]
    [TestCase('SingleEmpty', '2,0')]
    [TestCase('SingleOne', '2,1')]
    [TestCase('SingleMany', '2,3')]
    [TestCase('SingleDefaultEmpty', '3,0')]
    [TestCase('SingleDefaultOne', '3,1')]
    [TestCase('SingleDefaultMany', '3,3')]
    procedure Cardinality(Method, Count: Integer);
    [Test]
    procedure CurrentPositionAndOwnership;
    [Test]
    procedure RemainingRows;
    [TestCase('Empty', '0')]
    [TestCase('One', '1')]
    [TestCase('Many', '3')]
    procedure Streaming(Count: Integer);
    [Test]
    procedure CallbackFailure;
    [Test]
    procedure MappingFailure;
    [Test]
    procedure NilCallbackAndValidation;
    [Test]
    procedure ConcurrentDifferentTypes;
    [Test]
    procedure AdvancedConversions;
    [TestCase('SingleFirstNext', '0,1')]
    [TestCase('SingleSecondNext', '0,2')]
    [TestCase('StreamingThirdNext', '1,3')]
    procedure ProviderNextFailure(Method, FailAt: Integer);
    [Test]
    procedure RepeatedStreamingSchemas;
    [Test]
    procedure UnneededRowsAreNotMapped;
  end;

implementation

uses System.Generics.Collections, System.Threading, Data.FmtBcd, Data.SqlTimSt,
  DUnitX.Assert, Execution.Mock, Mapping.Tests, Mapping.Values.Tests,
  QueryBuilder4Delphi.Nullable;

function MakeRows(Count: Integer; out Mock: TMockQueryResult): IQueryResult;
var
  Data: TRows;
  I: Integer;
begin
  SetLength(Data, Count);
  for I := 0 to Count - 1 do
    Data[I] := TValues.Create(I + 1);
  Mock := TMockQueryResult.Create(['BookId'], nil, Data, True, -1);
  Result := Mock;
end;

procedure TMappingStreamingTests.Cardinality(Method, Count: Integer);
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Book: TMappingBook;
  Created, Destroyed, Calls, ExpectedObjects: Integer;
  MustRaise, Raised: Boolean;
begin
  R := MakeRows(Count, Mock);
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  MustRaise := ((Count = 0) and (Method in [0, 2])) or
    ((Count > 1) and (Method in [2, 3]));
  Book := nil;
  Raised := False;
  try
    try
      case Method of
        0:
          Book := TQueryMapper.First<TMappingBook>(R);
        1:
          Book := TQueryMapper.FirstOrDefault<TMappingBook>(R);
        2:
          Book := TQueryMapper.Single<TMappingBook>(R);
        3:
          Book := TQueryMapper.SingleOrDefault<TMappingBook>(R);
      end;
    except
      on E: EQueryMappingException do
      begin
        Raised := True;
        Assert.IsTrue(Pos('row', E.Message) > 0, E.Message);
      end;
    end;
    Assert.IsTrue(MustRaise = Raised);
    if not MustRaise and (Count > 0) then
    begin
      Assert.IsNotNull(Book);
      Assert.AreEqual(1, Book.Id);
      Assert.AreEqual(Destroyed, TMappingBook.Destroyed,
        'Caller owns the object');
    end
    else
      Assert.IsNull(Book);
  finally
    Book.Free;
  end;
  Calls := 1;
  if (Method >= 2) and (Count > 0) then
    Calls := 2;
  Assert.AreEqual(Calls, Mock.NextCalls);
  Assert.AreEqual(1, Mock.ColumnNameReads);
  ExpectedObjects := 0;
  if Count > 0 then
    ExpectedObjects := 1;
  Assert.AreEqual(Created + ExpectedObjects, TMappingBook.Created);
  Assert.AreEqual(Destroyed + ExpectedObjects, TMappingBook.Destroyed);
  if Count > Calls then
  begin
    Assert.IsTrue(R.Next);
    Assert.AreEqual(Calls + 1, R.GetValue(0).AsInteger);
  end;
end;

procedure TMappingStreamingTests.CurrentPositionAndOwnership;
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Book: TMappingBook;
  Created, Destroyed: Integer;
begin
  R := MakeRows(1, Mock);
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.MapCurrent<TMappingBook>(R).Free;
    end, EQueryException);
  Assert.AreEqual(0, Mock.NextCalls);
  Assert.IsTrue(R.Next);
  Book := TQueryMapper.MapCurrent<TMappingBook>(R);
  try
    Assert.AreEqual(1, Book.Id);
    Assert.AreEqual(1, Mock.NextCalls);
    Assert.AreEqual(1, R.GetValue(0).AsInteger);
  finally
    Book.Free;
  end;
  Assert.IsFalse(R.Next);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.MapCurrent<TMappingBook>(R).Free;
    end, EQueryException);
  Assert.AreEqual(2, Mock.NextCalls);
  Assert.AreEqual(Created + 3, TMappingBook.Created);
  Assert.AreEqual(Destroyed + 3, TMappingBook.Destroyed);
end;

procedure TMappingStreamingTests.RemainingRows;
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Book: TMappingBook;
  Sum: Integer;
begin
  R := MakeRows(3, Mock);
  Assert.IsTrue(R.Next);
  Book := TQueryMapper.First<TMappingBook>(R);
  try
    Assert.AreEqual(2, Book.Id);
  finally
    Book.Free;
  end;
  Book := TQueryMapper.Single<TMappingBook>(R);
  try
    Assert.AreEqual(3, Book.Id);
  finally
    Book.Free;
  end;
  R := MakeRows(3, Mock);
  Assert.IsTrue(R.Next);
  Sum := 0;
  TQueryMapper.ForEach<TMappingBook>(R,
    procedure(Book: TMappingBook)
    begin
      Inc(Sum, Book.Id);
    end);
  Assert.AreEqual(5, Sum);
end;

procedure TMappingStreamingTests.Streaming(Count: Integer);
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Created, Destroyed, Seen, Results: Integer;
begin
  Results := TMockQueryResult.LiveCount;
  R := MakeRows(Count, Mock);
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  Seen := 0;
  TQueryMapper.ForEach<TMappingBook>(R,
    procedure(Book: TMappingBook)
    begin
      Inc(Seen);
      Assert.AreEqual(Seen, Book.Id);
      Assert.AreEqual(Created + Seen, TMappingBook.Created);
      Assert.AreEqual(Destroyed + Seen - 1, TMappingBook.Destroyed);
    end);
  Assert.AreEqual(Count, Seen);
  Assert.AreEqual(Destroyed + Count, TMappingBook.Destroyed);
  Assert.AreEqual(Count + 1, Mock.NextCalls);
  Assert.AreEqual(1, Mock.ColumnNameReads);
  Assert.AreEqual(0, Mock.ColumnIndexLookups);
  Assert.AreEqual(Results + 1, TMockQueryResult.LiveCount);
  R := nil;
  Assert.AreEqual(Results, TMockQueryResult.LiveCount);
end;

procedure TMappingStreamingTests.CallbackFailure;
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Destroyed, Seen: Integer;
  Failure: EInvalidOp;
begin
  R := MakeRows(3, Mock);
  Destroyed := TMappingBook.Destroyed;
  Seen := 0;
  Failure := EInvalidOp.Create('callback failed');
  try
    TQueryMapper.ForEach<TMappingBook>(R,
      procedure(Book: TMappingBook)
      begin
        Inc(Seen);
        if Seen = 2 then
          raise Failure;
      end);
    Assert.Fail('Expected callback failure');
  except
    on E: EInvalidOp do
      Assert.IsTrue(E = Failure, 'Preserve exception identity');
  end;
  Assert.AreEqual(2, Seen);
  Assert.AreEqual(Destroyed + 2, TMappingBook.Destroyed);
  Assert.AreEqual(2, Mock.NextCalls);
  Assert.IsTrue(R.Next);
  Assert.AreEqual(3, R.GetValue(0).AsInteger);
end;

procedure TMappingStreamingTests.MappingFailure;
var
  R: IQueryResult;
  Seen, Created, Destroyed: Integer;
begin
  R := TMockQueryResult.Create(['BookId'], nil, TRows.Create(TValues.Create(1),
    TValues.Create('bad'), TValues.Create(3)), True, -1);
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  Seen := 0;
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ForEach<TMappingBook>(R,
        procedure(Book: TMappingBook)
        begin
          Inc(Seen);
        end);
    end, EQueryMappingException);
  Assert.AreEqual(1, Seen);
  Assert.AreEqual(Created + 2, TMappingBook.Created);
  Assert.AreEqual(Destroyed + 2, TMappingBook.Destroyed);
  Assert.IsTrue(R.Next);
  Assert.AreEqual(3, R.GetValue(0).AsInteger);
end;

procedure TMappingStreamingTests.NilCallbackAndValidation;
var
  R: IQueryResult;
  Mock: TMockQueryResult;
begin
  R := MakeRows(1, Mock);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.ForEach<TMappingBook>(R, nil);
    end, EArgumentNilException);
  Assert.AreEqual(0, Mock.NextCalls);
  R := TMockQueryResult.Create(['wrong'], nil, nil, True, -1);
  Assert.WillRaise(
    procedure
    begin
      TQueryMapper.Single<TMappingBook>(R).Free;
    end, EQueryMappingException);
end;

procedure TMappingStreamingTests.ConcurrentDifferentTypes;
var
  Values: TArray<Integer>;
  I: Integer;
begin
  SetLength(Values, 128);
  TParallel.For(0, Integer(High(Values)),
    procedure(Index: Integer)
    var
      R: IQueryResult;
      A: TColdStreamingDTO;
      B: TOtherColdStreamingDTO;
    begin
      R := TMockQueryResult.Create(['Id'], nil,
        TRows.Create(TValues.Create(Index)), True, -1);
      if Odd(Index) then
      begin
        A := TQueryMapper.Single<TColdStreamingDTO>(R);
        try
          Values[Index] := A.Id;
        finally
          A.Free;
        end;
      end
      else
      begin
        B := TQueryMapper.Single<TOtherColdStreamingDTO>(R);
        try
          Values[Index] := B.Id;
        finally
          B.Free;
        end;
      end;
    end);
  for I := 0 to High(Values) do
    Assert.AreEqual(I, Values[I]);
end;

procedure TMappingStreamingTests.AdvancedConversions;
var
  R: IQueryResult;
  Item: TTypedDTO<TNullable<Currency>>;
  Options: TQueryMappingOptions;
  Seen: Integer;
begin
  R := TMockQueryResult.Create(['Value'], nil,
    TRows.Create(TValues.Create(TValue.Empty),
    TValues.Create(TValue.From<TBcd>(StrToBcd('12.5000',
    TFormatSettings.Invariant)))), True, -1);
  Seen := 0;
  TQueryMapper.ForEach < TTypedDTO < TNullable<Currency> >> (R,
    procedure(Book: TTypedDTO < TNullable < Currency >> )
    begin
      Inc(Seen);
      if Seen = 1 then
        Assert.IsFalse(Book.Value.HasValue)
      else
        Assert.AreEqual<Currency>(12.5, Book.Value.Value);
    end);
  Assert.AreEqual(2, Seen);
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter<string, Currency>(
      function(S: string): Currency
      begin
        Result := Length(S);
      end);
    R := TMockQueryResult.Create(['Value'], nil,
      TRows.Create(TValues.Create('abc')), True, -1);
    Assert.IsTrue(R.Next);
    Item := TQueryMapper.MapCurrent < TTypedDTO < TNullable<Currency> >>
      (R, Options);
    try
      Assert.AreEqual<Currency>(3, Item.Value.Value);
    finally
      Item.Free;
    end;
  finally
    Options.Free;
  end;
end;

procedure TMappingStreamingTests.ProviderNextFailure(Method, FailAt: Integer);
var
  R: IQueryResult;
  Mock: TMockQueryResult;
  Created, Destroyed, Seen: Integer;
begin
  R := MakeRows(3, Mock);
  Mock.NextFailureAt := FailAt;
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  Seen := 0;
  Assert.WillRaise(
    procedure
    begin
      if Method = 0 then
        TQueryMapper.Single<TMappingBook>(R).Free
      else
        TQueryMapper.ForEach<TMappingBook>(R,
          procedure(Book: TMappingBook)
          begin
            Inc(Seen);
          end);
    end, EInvalidOp);
  Assert.AreEqual(FailAt - 1, TMappingBook.Created - Created);
  Assert.AreEqual(FailAt - 1, TMappingBook.Destroyed - Destroyed);
  Assert.AreEqual(FailAt, Mock.NextCalls);
  Assert.IsTrue(R.Next, 'The result remains caller owned');
end;

procedure TMappingStreamingTests.RepeatedStreamingSchemas;
var
  R: IQueryResult;
  I, Seen: Integer;
  SavedTitles: TList<string>;
begin
  SavedTitles := TList<string>.Create;
  try
    for I := 1 to 10 do
    begin
      if Odd(I) then
        R := TMockQueryResult.Create(['BookTitle', 'BookId'], nil,
          TRows.Create(TValues.Create('reordered', I)), True, -1)
      else
        R := TMockQueryResult.Create(['BookId', 'extra', 'BookTitle'], nil,
          TRows.Create(TValues.Create(I, TValue.Empty, 'normal')), True, -1);
      Seen := 0;
      TQueryMapper.ForEach<TMappingBook>(R,
        procedure(Book: TMappingBook)
        begin
          Inc(Seen);
          Assert.AreEqual(I, Book.Id);
          SavedTitles.Add(Book.Title); // Independent managed value copy.
        end);
      Assert.AreEqual(1, Seen);
    end;
    R := nil;
    Assert.AreEqual('reordered', SavedTitles[0]);
    Assert.AreEqual('normal', SavedTitles[9]);
  finally
    SavedTitles.Free;
  end;
end;

procedure TMappingStreamingTests.UnneededRowsAreNotMapped;
var
  R: IQueryResult;
  Book: TMappingBook;
  Created, Destroyed: Integer;
begin
  R := TMockQueryResult.Create(['BookId'], nil, TRows.Create(TValues.Create(1),
    TValues.Create('invalid second row')), True, -1);
  Book := TQueryMapper.First<TMappingBook>(R);
  try
    Assert.AreEqual(1, Book.Id);
  finally
    Book.Free;
  end;
  R := TMockQueryResult.Create(['BookId'], nil, TRows.Create(TValues.Create(1),
    TValues.Create('invalid second row')), True, -1);
  Created := TMappingBook.Created;
  Destroyed := TMappingBook.Destroyed;
  try
    TQueryMapper.Single<TMappingBook>(R).Free;
    Assert.Fail('Expected multiple rows');
  except
    on E: EQueryMappingException do
      Assert.IsTrue(Pos('multiple rows', E.Message) > 0, E.Message);
  end;
  Assert.AreEqual(Created + 1, TMappingBook.Created);
  Assert.AreEqual(Destroyed + 1, TMappingBook.Destroyed);
end;

initialization

TDUnitX.RegisterTestFixture(TMappingStreamingTests);

end.
