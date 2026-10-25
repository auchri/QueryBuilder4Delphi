unit FluentMapping.Operations.Tests;

interface

uses DUnitX.TestFramework, QueryBuilder4Delphi.Query.Core;

type

  [TestFixture]
  TFluentMappingOperationsTests = class
  private
    FExecutor: IQueryExecutor;
    FResultBaseline, FCreated, FDestroyed: Integer;
    procedure ConfigureRows(Count: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [TestCase('Method0Rows0', '0,0')]
    [TestCase('Method0Rows1', '0,1')]
    [TestCase('Method0Rows3', '0,3')]
    [TestCase('Method1Rows0', '1,0')]
    [TestCase('Method1Rows1', '1,1')]
    [TestCase('Method1Rows3', '1,3')]
    [TestCase('Method2Rows0', '2,0')]
    [TestCase('Method2Rows1', '2,1')]
    [TestCase('Method2Rows3', '2,3')]
    [TestCase('Method3Rows0', '3,0')]
    [TestCase('Method3Rows1', '3,1')]
    [TestCase('Method3Rows3', '3,3')]
    [TestCase('Method4Rows0', '4,0')]
    [TestCase('Method4Rows1', '4,1')]
    [TestCase('Method4Rows3', '4,3')]
    procedure TemporaryRows(Method, Count: Integer);
    [TestCase('First', '0')]
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    [TestCase('FirstDefault', '4')]
    procedure RemainingRowsAndCopies(Method: Integer);
    [TestCase('Method0Failure0', '0,0')]
    [TestCase('Method0Failure1', '0,1')]
    [TestCase('Method0Failure2', '0,2')]
    [TestCase('Method0Failure3', '0,3')]
    [TestCase('Method1Failure0', '1,0')]
    [TestCase('Method1Failure1', '1,1')]
    [TestCase('Method1Failure2', '1,2')]
    [TestCase('Method1Failure3', '1,3')]
    [TestCase('Method2Failure0', '2,0')]
    [TestCase('Method2Failure1', '2,1')]
    [TestCase('Method2Failure2', '2,2')]
    [TestCase('Method2Failure3', '2,3')]
    [TestCase('Method3Failure0', '3,0')]
    [TestCase('Method3Failure1', '3,1')]
    [TestCase('Method3Failure2', '3,2')]
    [TestCase('Method3Failure3', '3,3')]
    procedure TemporaryFailures(Method, Kind: Integer);
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure LaterProviderFailure(Method: Integer);
    [TestCase('First', '0')]
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure SetterFailure(Method: Integer);
    [TestCase('Method0Null0', '0,0')]
    [TestCase('Method0Null1', '0,1')]
    [TestCase('Method1Null0', '1,0')]
    [TestCase('Method1Null1', '1,1')]
    [TestCase('Method2Null0', '2,0')]
    [TestCase('Method2Null1', '2,1')]
    [TestCase('Method3Null0', '3,0')]
    [TestCase('Method3Null1', '3,1')]
    procedure NullableAndOptions(Method, NullValue: Integer);
    [TestCase('First', '0')]
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure ConverterFailure(Method: Integer);
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure SharedFailures(Method: Integer);
    [Test]
    procedure NilCallbackConsumesFacade;
    [Test]
    procedure TemporaryCallbackFailure;
    [TestCase('First', '0')]
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure EmptyFacade(Method: Integer);
    [TestCase('First', '0')]
    [TestCase('Single', '1')]
    [TestCase('SingleDefault', '2')]
    [TestCase('Streaming', '3')]
    procedure SkipNullDefaults(Method: Integer);
  end;

implementation

uses System.SysUtils, System.Rtti, DUnitX.Assert, Execution.Mock,
  QueryBuilder4Delphi.Compilers.Compiler, QueryBuilder4Delphi.Query,
  QueryBuilder4Delphi.Mapping, Mapping.Tests, Mapping.Values.Tests;

type
  // Test-only executor; LastResult is borrowed, and inspected only while a
  // separately retained interface/facade still owns it.
  TFluentFaultExecutor = class(TMockQueryExecutor)
  public
    FailOnNext: Integer;
    LastResult: TMockQueryResult;
    LastSql: string;
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  end;

function TFluentFaultExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  LastSql := Statement.Sql;
  LastResult := TMockQueryResult.Create(Names, Types, Data, Mode = emRows,
    Affected);
  LastResult.NextFailureAt := FailOnNext;
  Result := LastResult;
end;

procedure TFluentMappingOperationsTests.ConfigureRows(Count: Integer);
var
  I: Integer;
begin
  TMockQueryExecutor.Names := TArray<string>.Create('BookId', 'BookTitle');
  SetLength(TMockQueryExecutor.Data, Count);
  for I := 0 to Count - 1 do
    TMockQueryExecutor.Data[I] := TValues.Create(I + 1,
      'Book ' + IntToStr(I + 1));
end;

procedure TFluentMappingOperationsTests.Setup;
begin
  FResultBaseline := TMockQueryResult.LiveCount;
  FCreated := TMappingBook.Created;
  FDestroyed := TMappingBook.Destroyed;
  FExecutor := TFluentFaultExecutor.Create(TSqlDialect.Sqlite);
  ConfigureRows(3);
end;

procedure TFluentMappingOperationsTests.TearDown;
begin
  FExecutor := nil;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed, 'Mapped object leaked');
end;

procedure TFluentMappingOperationsTests.TemporaryRows(Method, Count: Integer);
var
  Book: TMappingBook;
  Seen: Integer;
  Raised, MustRaise: Boolean;
begin
  ConfigureRows(Count);
  Book := nil;
  Seen := 0;
  Raised := False;
  MustRaise := ((Count = 0) and (Method in [0, 1])) or
    ((Count > 1) and (Method in [1, 2]));
  try
    try
      case Method of
        0:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .First<TMappingBook>();
        1:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .Single<TMappingBook>();
        2:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .SingleOrDefault<TMappingBook>();
        3:
          TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
            procedure(Item: TMappingBook)
            begin
              Inc(Seen);
              Assert.AreEqual(Seen, Item.Id);
              Assert.AreEqual(FCreated + Seen, TMappingBook.Created);
              Assert.AreEqual(FDestroyed + Seen - 1, TMappingBook.Destroyed,
                'Only the current borrowed object may be alive');
            end);
        4:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .FirstOrDefault<TMappingBook>();
      end;
    except
      on E: EQueryMappingException do
        Raised := True;
    end;
    Assert.IsTrue(MustRaise = Raised);
    // Check now, before this caller scope and its compiler temporaries end.
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    if Method = 3 then
    begin
      Assert.AreEqual(Count, Seen);
      Assert.AreEqual(FCreated + Count, TMappingBook.Created);
      Assert.AreEqual(FDestroyed + Count, TMappingBook.Destroyed);
    end
    else if not MustRaise and (Count > 0) then
    begin
      Assert.IsNotNull(Book);
      Assert.AreEqual(1, Book.Id, 'Returned object outlives its resultset');
      Assert.AreEqual('Book 1', Book.Title);
      Assert.AreEqual(FDestroyed, TMappingBook.Destroyed);
    end
    else
      Assert.IsNull(Book);
  finally
    Book.Free;
  end;
end;

procedure TFluentMappingOperationsTests.RemainingRowsAndCopies(Method: Integer);
var
  A, B: TQueryResult;
  Raw: IQueryResult;
  Book: TMappingBook;
  Sum, Calls: Integer;
begin
  A := TQuery.Create('Books').Execute(FExecutor);
  B := A;
  Raw := A.AsRaw;
  Assert.IsTrue(A.Next); // Start the operation after row one.
  Book := nil;
  Sum := 0;
  try
    try
      case Method of
        0:
          Book := A.First<TMappingBook>();
        1:
          Book := A.Single<TMappingBook>();
        2:
          Book := A.SingleOrDefault<TMappingBook>();
        3:
          A.ForEach<TMappingBook>(
            procedure(Item: TMappingBook)
            begin
              Inc(Sum, Item.Id);
            end);
        4:
          Book := A.FirstOrDefault<TMappingBook>();
      end;
      Assert.IsFalse(Method in [1, 2], 'Single must detect two remaining rows');
    except
      on E: EQueryMappingException do
        Assert.IsTrue(Method in [1, 2]);
    end;
    Assert.IsNull(A.AsRaw, 'The receiving facade is consumed');
    Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
    if Method in [0, 4] then
    begin
      Assert.AreEqual(2, Book.Id);
      Assert.AreEqual(2, B.GetValue(0).AsInteger);
      Calls := 2;
    end
    else if Method in [1, 2] then
    begin
      Assert.AreEqual(3, Raw.GetValue(0).AsInteger);
      Calls := 3;
    end
    else
    begin
      Assert.AreEqual(5, Sum);
      Calls := 4;
    end;
    Assert.AreEqual(Calls, (FExecutor as TFluentFaultExecutor)
      .LastResult.NextCalls);
    Assert.IsFalse((FExecutor as TFluentFaultExecutor).LastSql.ToUpper.Contains
      ('LIMIT'));
    B := Default (TQueryResult);
    if Method in [0, 4] then
    begin
      Assert.IsTrue(Raw.Next);
      Assert.AreEqual(3, Raw.GetValue(0).AsInteger);
    end
    else
      Assert.IsFalse(Raw.Next);
    Raw := nil;
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    if Book <> nil then
      Assert.AreEqual('Book 2', Book.Title);
  finally
    Book.Free;
  end;
end;

procedure TFluentMappingOperationsTests.TemporaryFailures(Method,
  Kind: Integer);
var
  Options: TQueryMappingOptions;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.NullBehavior := nmbThrow;
    ConfigureRows(1);
    case Kind of
      0:
        TMockQueryExecutor.Names := TArray<string>.Create('unmatched', 'extra');
      1:
        TMockQueryExecutor.Data :=
          TRows.Create(TValues.Create('bad integer', 'title'));
      2:
        TMockQueryExecutor.Data :=
          TRows.Create(TValues.Create(TValue.Empty, 'title'));
      3:
        (FExecutor as TFluentFaultExecutor).FailOnNext := 1;
  end;
  try
    case Method of
      0:
        TQuery.Create('Books').Execute(FExecutor).First<TMappingBook>
          (Options).Free;
      1:
        TQuery.Create('Books').Execute(FExecutor).Single<TMappingBook>
          (Options).Free;
      2:
        TQuery.Create('Books').Execute(FExecutor).SingleOrDefault<TMappingBook>
          (Options).Free;
      3:
        TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
          procedure(Item: TMappingBook)
          begin
            Assert.Fail('No callback expected');
          end, Options);
    end;
    Assert.Fail('Expected failure');
  except
    on E: EQueryMappingException do
      Assert.IsTrue(Kind <> 3);
    on E: EInvalidOp do
      Assert.AreEqual(3, Kind);
  end;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed);
finally
  Options.Free;
end;
end;

procedure TFluentMappingOperationsTests.LaterProviderFailure(Method: Integer);
begin
  (FExecutor as TFluentFaultExecutor).FailOnNext := 2;
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      case Method of
        1:
          TQuery.Create('Books').Execute(FExecutor).Single<TMappingBook>().Free;
        2:
          TQuery.Create('Books').Execute(FExecutor)
            .SingleOrDefault<TMappingBook>().Free;
        3:
          TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
            procedure(Item: TMappingBook)
            begin
              Assert.AreEqual(1, Item.Id);
            end);
      end;
    end), EInvalidOp);
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(FCreated + 1, TMappingBook.Created);
  Assert.AreEqual(FDestroyed + 1, TMappingBook.Destroyed);
end;

procedure TFluentMappingOperationsTests.SetterFailure(Method: Integer);
begin
  TMockQueryExecutor.Names := TArray<string>.Create('Id');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(1));
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      case Method of
        0:
          TQuery.Create('Books').Execute(FExecutor).First<TSetterDTO>().Free;
        1:
          TQuery.Create('Books').Execute(FExecutor).Single<TSetterDTO>().Free;
        2:
          TQuery.Create('Books').Execute(FExecutor)
            .SingleOrDefault<TSetterDTO>().Free;
        3:
          TQuery.Create('Books').Execute(FExecutor).ForEach<TSetterDTO>(
            procedure(Item: TSetterDTO)
            begin
              Assert.Fail('Setter must fail');
            end);
      end;
    end), EInvalidOp);
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

procedure TFluentMappingOperationsTests.NullableAndOptions(Method,
  NullValue: Integer);
var
  Options: TQueryMappingOptions;
  Book: TNullableBook;
  Seen, Created, Destroyed: Integer;
  Check: TProc<TNullableBook>;
begin
  Check := procedure(Item: TNullableBook)
    begin
      Assert.IsTrue(Item.Rating.HasValue = (NullValue = 0));
      Assert.IsTrue(Item.Title.HasValue = (NullValue = 0));
      if NullValue = 0 then
      begin
        Assert.AreEqual(3, Item.Rating.Value);
        Assert.AreEqual('ALPHA', Item.Title.Value);
      end;
    end;

  TMockQueryExecutor.Names := TArray<string>.Create('Rating', 'Title');
  if NullValue = 1 then
    TMockQueryExecutor.Data :=
      TRows.Create(TValues.Create(TValue.Empty, TValue.Empty))
  else
    TMockQueryExecutor.Data := TRows.Create(TValues.Create('abc', 'alpha'));
  Options := TQueryMappingOptions.Create;
  Created := TNullableBook.Created;
  Destroyed := TNullableBook.Destroyed;
  Book := nil;
  Seen := 0;
  try
    Options.RegisterConverter<string, Integer>(
      function(S: string): Integer
      begin
        Result := Length(S);
      end);
    Options.RegisterConverter<string, string>(
      function(S: string): string
      begin
        Result := S.ToUpper;
      end);
    case Method of
      0:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .First<TNullableBook>(Options);
      1:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .Single<TNullableBook>(Options);
      2:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .SingleOrDefault<TNullableBook>(Options);
      3:
        TQuery.Create('Books').Execute(FExecutor).ForEach<TNullableBook>(
          procedure(Item: TNullableBook)
          begin
            Inc(Seen);
            Check(Item);
            Assert.AreEqual(Destroyed, TNullableBook.Destroyed);
          end, Options);
    end;
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    if Method = 3 then
      Assert.AreEqual(1, Seen)
    else
      Check(Book);
  finally
    Book.Free;
    Options.Free;
    Check := nil; // Break the test's captured anonymous-method reference cycle.
  end;
  Assert.AreEqual(Created + 1, TNullableBook.Created);
  Assert.AreEqual(Destroyed + 1, TNullableBook.Destroyed);
end;

procedure TFluentMappingOperationsTests.ConverterFailure(Method: Integer);
var
  Options: TQueryMappingOptions;
begin
  ConfigureRows(1);
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter<Integer, Integer>(
      function(Value: Integer): Integer
      begin
        raise EInvalidOp.Create('converter failed');
      end);
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        case Method of
          0:
            TQuery.Create('Books').Execute(FExecutor)
              .First<TMappingBook>(Options).Free;
          1:
            TQuery.Create('Books').Execute(FExecutor)
              .Single<TMappingBook>(Options).Free;
          2:
            TQuery.Create('Books').Execute(FExecutor)
              .SingleOrDefault<TMappingBook>(Options).Free;
          3:
            TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
              procedure(Item: TMappingBook)
              begin
                Assert.Fail('Converter must fail');
              end, Options);
        end;
      end), EInvalidOp);
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    Assert.AreEqual(FCreated + 1, TMappingBook.Created);
    Assert.AreEqual(FDestroyed + 1, TMappingBook.Destroyed);
  finally
    Options.Free;
  end;
end;

procedure TFluentMappingOperationsTests.SharedFailures(Method: Integer);
var
  A, B: TQueryResult;
  Raw: IQueryResult;
  Seen: Integer;
  Failure: EInvalidOp;
begin
  A := TQuery.Create('Books').Execute(FExecutor);
  B := A;
  Raw := A.AsRaw;
  Seen := 0;
  if Method = 3 then
  begin
    Failure := EInvalidOp.Create('callback failed');
    try
      A.ForEach<TMappingBook>(
        procedure(Item: TMappingBook)
        begin
          Inc(Seen);
          Assert.AreEqual(FDestroyed + Seen - 1, TMappingBook.Destroyed);
          if Seen = 2 then
            raise Failure;
        end);
      Assert.Fail('Expected callback failure');
    except
      on E: EInvalidOp do
        Assert.IsTrue(E = Failure);
    end;
    Assert.AreEqual(2, Seen);
  end
  else
  begin
    // Do not capture A in an assertion callback: Delphi can hoist the Execute
    // assignment's managed temporary into that callback's activation record.
    try
      if Method = 1 then
        A.Single<TMappingBook>().Free
      else
        A.SingleOrDefault<TMappingBook>().Free;
      Assert.Fail('Expected multiple rows');
    except
      on E: EQueryMappingException do
        Assert.IsTrue(Pos('multiple rows', E.Message) > 0);
    end;
  end;
  Assert.IsNull(A.AsRaw);
  Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
  Assert.AreEqual(2, B.GetValue(0).AsInteger);
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed);
  Assert.IsTrue(Raw.Next);
  Assert.AreEqual(3, B.GetValue(0).AsInteger);
  B := Default (TQueryResult);
  Raw := nil;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

procedure TFluentMappingOperationsTests.NilCallbackConsumesFacade;
var
  Rows: TQueryResult;
begin
  Rows := TQuery.Create('Books').Execute(FExecutor);
  try
    Rows.ForEach<TMappingBook>(nil);
    Assert.Fail('Expected nil callback rejection');
  except
    on E: EArgumentNilException do
      Assert.IsTrue(Pos('Callback', E.Message) > 0);
  end;
  Assert.IsNull(Rows.AsRaw);
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

procedure TFluentMappingOperationsTests.EmptyFacade(Method: Integer);
var
  Rows: TQueryResult;
begin
  Rows := Default (TQueryResult);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      case Method of
        0:
          Rows.First<TMappingBook>().Free;
        1:
          Rows.Single<TMappingBook>().Free;
        2:
          Rows.SingleOrDefault<TMappingBook>().Free;
        3:
          Rows.ForEach<TMappingBook>(
            procedure(Item: TMappingBook)
            begin
            end);
      end;
    end), EArgumentNilException);
end;

procedure TFluentMappingOperationsTests.SkipNullDefaults(Method: Integer);
var
  Book: TMappingBook;
  Options: TQueryMappingOptions;
  Seen: Integer;
begin
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(TValue.Empty,
    TValue.Empty));
  Book := nil;
  Options := TQueryMappingOptions.Create;
  Seen := 0;
  try
    Options.SkipNullAssignment := True;
    case Method of
      0:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .First<TMappingBook>(Options);
      1:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .Single<TMappingBook>(Options);
      2:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .SingleOrDefault<TMappingBook>(Options);
      3:
        TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
          procedure(Item: TMappingBook)
          begin
            Inc(Seen);
            Assert.AreEqual('constructor title', Item.Title);
          end, Options);
    end;
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    if Method = 3 then
      Assert.AreEqual(1, Seen)
    else
      Assert.AreEqual('constructor title', Book.Title);
  finally
    Book.Free;
    Options.Free;
  end;
end;

procedure TFluentMappingOperationsTests.TemporaryCallbackFailure;
var
  Seen: Integer;
begin
  Seen := 0;
  try
    TQuery.Create('Books').Execute(FExecutor).ForEach<TMappingBook>(
      procedure(Item: TMappingBook)
      begin
        Inc(Seen);
        if Seen = 2 then
          raise EInvalidOp.Create('temporary callback failed');
      end);
    Assert.Fail('Expected callback exception');
  except
    on E: EInvalidOp do
      Assert.AreEqual('temporary callback failed', E.Message);
  end;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(2, Seen);
  Assert.AreEqual(FCreated + 2, TMappingBook.Created);
  Assert.AreEqual(FDestroyed + 2, TMappingBook.Destroyed);
end;

initialization

TDUnitX.RegisterTestFixture(TFluentMappingOperationsTests);

end.
