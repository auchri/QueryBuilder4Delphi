unit Mapping.Fallback.Tests;

interface

uses System.Generics.Collections, DUnitX.TestFramework,
  QueryBuilder4Delphi.Query.Core, Mapping.Tests;

type

  [TestFixture]
  TMappingFallbackTests = class
  private
    FExecutor: IQueryExecutor;
    FOwner: TObjectList<TMappingBook>;
    FExisting: TMappingBook;
    FResultBaseline, FCreated, FDestroyed: Integer;
    procedure ConfigureRows(Count: Integer);
    function OpenRows: IQueryResult;
    procedure CheckExisting;
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
    procedure Cardinality(Method, Count: Integer);
    [TestCase('Method0Kind0', '0,0')]
    [TestCase('Method0Kind1', '0,1')]
    [TestCase('Method0Kind2', '0,2')]
    [TestCase('Method1Kind0', '1,0')]
    [TestCase('Method1Kind1', '1,1')]
    [TestCase('Method1Kind2', '1,2')]
    [TestCase('Method2Kind0', '2,0')]
    [TestCase('Method2Kind1', '2,1')]
    [TestCase('Method2Kind2', '2,2')]
    [TestCase('Method3Kind0', '3,0')]
    [TestCase('Method3Kind1', '3,1')]
    [TestCase('Method3Kind2', '3,2')]
    procedure FallbackKinds(Method, Kind: Integer);
    [TestCase('Method0Rows0', '0,0')]
    [TestCase('Method0Rows1', '0,1')]
    [TestCase('Method1Rows0', '1,0')]
    [TestCase('Method1Rows1', '1,1')]
    [TestCase('Method2Rows0', '2,0')]
    [TestCase('Method2Rows1', '2,1')]
    [TestCase('Method3Rows0', '3,0')]
    [TestCase('Method3Rows1', '3,1')]
    procedure NilCallback(Method, Count: Integer);
    [TestCase('Method0Failure0', '0,0')]
    [TestCase('Method0Failure1', '0,1')]
    [TestCase('Method0Failure2', '0,2')]
    [TestCase('Method0Failure3', '0,3')]
    [TestCase('Method0Failure4', '0,4')]
    [TestCase('Method1Failure0', '1,0')]
    [TestCase('Method1Failure1', '1,1')]
    [TestCase('Method1Failure2', '1,2')]
    [TestCase('Method1Failure3', '1,3')]
    [TestCase('Method1Failure4', '1,4')]
    [TestCase('Method2Failure0', '2,0')]
    [TestCase('Method2Failure1', '2,1')]
    [TestCase('Method2Failure2', '2,2')]
    [TestCase('Method2Failure3', '2,3')]
    [TestCase('Method2Failure4', '2,4')]
    [TestCase('Method3Failure0', '3,0')]
    [TestCase('Method3Failure1', '3,1')]
    [TestCase('Method3Failure2', '3,2')]
    [TestCase('Method3Failure3', '3,3')]
    [TestCase('Method3Failure4', '3,4')]
    procedure ErrorsNeverFallBack(Method, Kind: Integer);
    [TestCase('StaticFirst', '0')]
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentFirst', '2')]
    [TestCase('FluentSingle', '3')]
    procedure CallbackFailure(Method: Integer);
    [TestCase('StaticFirst', '0')]
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentFirst', '2')]
    [TestCase('FluentSingle', '3')]
    procedure MissingResult(Method: Integer);
    [TestCase('StaticFirst', '0')]
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentFirst', '2')]
    [TestCase('FluentSingle', '3')]
    procedure RetainedResults(Method: Integer);
    [TestCase('StaticFirst', '0')]
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentFirst', '2')]
    [TestCase('FluentSingle', '3')]
    procedure RemainingRows(Method: Integer);
    [TestCase('StaticFirst', '0')]
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentFirst', '2')]
    [TestCase('FluentSingle', '3')]
    procedure NullableOptions(Method: Integer);
    [TestCase('StaticSingle', '1')]
    [TestCase('FluentSingle', '3')]
    procedure LaterProviderFailure(Method: Integer);
  end;

implementation

uses System.SysUtils, System.Rtti, DUnitX.Assert, Execution.Mock,
  Mapping.Values.Tests, QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping;

type
  TFallbackFaultExecutor = class(TMockQueryExecutor)
  public
    FailOnNext: Integer;
    LastResult: TMockQueryResult;
    // Borrowed; inspect only while Rows is retained.
    function ExecuteCompiled(const Statement: ISqlResult;
      Mode: TQueryExecutionMode): IQueryResult; override;
  end;

function TFallbackFaultExecutor.ExecuteCompiled(const Statement: ISqlResult;
  Mode: TQueryExecutionMode): IQueryResult;
begin
  LastResult := TMockQueryResult.Create(Names, Types, Data, Mode = emRows,
    Affected);
  LastResult.NextFailureAt := FailOnNext;
  Result := LastResult;
end;

procedure TMappingFallbackTests.ConfigureRows(Count: Integer);
var
  I: Integer;
begin
  TMockQueryExecutor.Names := TArray<string>.Create('BookId', 'BookTitle');
  SetLength(TMockQueryExecutor.Data, Count);
  for I := 0 to Count - 1 do
    TMockQueryExecutor.Data[I] := TValues.Create(I + 1, 'Database book');
end;

function TMappingFallbackTests.OpenRows: IQueryResult;
begin
  Result := FExecutor.Execute(TQuery.Create('Books'), emRows);
end;

procedure TMappingFallbackTests.Setup;
begin
  FResultBaseline := TMockQueryResult.LiveCount;
  FCreated := TMappingBook.Created;
  FDestroyed := TMappingBook.Destroyed;
  FOwner := TObjectList<TMappingBook>.Create(True);
  FExisting := TMappingBook.Create;
  FExisting.Id := -99;
  FExisting.Title := 'Externally owned book';
  FOwner.Add(FExisting);
  FExecutor := TFallbackFaultExecutor.Create(TSqlDialect.Sqlite);
  ConfigureRows(1);
end;

procedure TMappingFallbackTests.CheckExisting;
begin
  Assert.AreEqual<NativeInt>(1, FOwner.Count);
  Assert.IsTrue(FOwner[0] = FExisting);
  Assert.IsTrue(FOwner.OwnsObjects);
  Assert.AreEqual(-99, FExisting.Id);
  Assert.AreEqual('Externally owned book', FExisting.Title);
end;

procedure TMappingFallbackTests.TearDown;
begin
  FExecutor := nil;
  FOwner.Free;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed, 'Object leaked or external object freed');
end;

procedure TMappingFallbackTests.Cardinality(Method, Count: Integer);
var
  Rows: IQueryResult;
  Fallback: TFunc<TMappingBook>;
  Book: TMappingBook;
  Calls: Integer;
  Raised, MustRaise: Boolean;
begin
  ConfigureRows(Count);
  Calls := 0;
  Raised := False;
  MustRaise := Odd(Method) and (Count > 1);
  Fallback := function: TMappingBook
    begin
      Inc(Calls);
      if Method < 2 then
        Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount)
      else
        Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount,
          'Release the fluent result before calling the fallback');
      Result := FExisting;
    end;
  Book := nil;
  if Method < 2 then
    Rows := OpenRows;
  try
    try
      case Method of
        0:
          Book := TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback);
        1:
          Book := TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback);
        2:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .FirstOrElse<TMappingBook>(Fallback);
        3:
          Book := TQuery.Create('Books').Execute(FExecutor)
            .SingleOrElse<TMappingBook>(Fallback);
      end;
    except
      on E: EQueryMappingException do
      begin
        Raised := True;
        Assert.IsTrue(Pos('multiple rows', E.Message) > 0);
      end;
    end;
    Assert.IsTrue(MustRaise = Raised);
    if Count = 0 then
    begin
      Assert.AreEqual(1, Calls);
      Assert.IsTrue(Book = FExisting);
    end
    else
    begin
      Assert.AreEqual(0, Calls);
      if not MustRaise then
      begin
        Assert.IsTrue(Book <> FExisting);
        Assert.AreEqual(1, Book.Id);
        Assert.AreEqual('Database book', Book.Title);
        Assert.AreEqual(FDestroyed, TMappingBook.Destroyed);
      end;
    end;
    if Method < 2 then
    begin
      Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
      if Count = 0 then
        Assert.IsFalse(Rows.Next);
    end
    else
      Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
    CheckExisting;
  finally
    if Book <> FExisting then
      Book.Free;
    Rows := nil;
  end;
end;

procedure TMappingFallbackTests.FallbackKinds(Method, Kind: Integer);
var
  Rows: IQueryResult;
  Book, CreatedFallback: TMappingBook;
  Fallback: TFunc<TMappingBook>;
  Options: TQueryMappingOptions;
  Calls: Integer;
begin
  ConfigureRows(0);
  Calls := 0;
  CreatedFallback := nil;
  Book := nil;
  Options := TQueryMappingOptions.Create;
  try
    Options.SkipNullAssignment := True;
    Options.RegisterConverter<string, string>(
      function(S: string): string
      begin
        Result := 'Should never transform a fallback';
      end);
    Fallback := function: TMappingBook
      begin
        Inc(Calls);
        case Kind of
          0:
            Result := FExisting;
          1:
            begin
              CreatedFallback := TMappingBook.Create;
              CreatedFallback.Title := 'New fallback';
              Result := CreatedFallback;
            end;
        else
          Result := nil;
        end;
      end;
    if Method < 2 then
      Rows := OpenRows;
    case Method of
      0:
        Book := TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback, Options);
      1:
        Book := TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback,
          Options);
      2:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .FirstOrElse<TMappingBook>(Fallback, Options);
      3:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .SingleOrElse<TMappingBook>(Fallback, Options);
    end;
    Assert.AreEqual(1, Calls);
    case Kind of
      0:
        Assert.IsTrue(Book = FExisting);
      1:
        begin
          Assert.IsTrue(Book = CreatedFallback,
            'Return the exact newly created reference');
          Assert.AreEqual('New fallback', Book.Title);
        end;
      2:
        Assert.IsNull(Book);
    end;
    CheckExisting;
    if Method >= 2 then
      Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  finally
    if Book <> FExisting then
      Book.Free;
    Options.Free;
    Rows := nil;
  end;
end;

procedure TMappingFallbackTests.NilCallback(Method, Count: Integer);
var
  Rows: IQueryResult;
begin
  ConfigureRows(Count);
  if Method < 2 then
    Rows := OpenRows;
  try
    case Method of
      0:
        TQueryMapper.FirstOrElse<TMappingBook>(Rows, nil).Free;
      1:
        TQueryMapper.SingleOrElse<TMappingBook>(Rows, nil).Free;
      2:
        TQuery.Create('Books').Execute(FExecutor).FirstOrElse<TMappingBook>
          (nil).Free;
      3:
        TQuery.Create('Books').Execute(FExecutor).SingleOrElse<TMappingBook>
          (nil).Free;
    end;
    Assert.Fail('A nil callback must fail even if a database row exists');
  except
    on E: EArgumentNilException do
      Assert.IsTrue(Pos('Fallback', E.Message) > 0);
  end;
  if Method < 2 then
  begin
    Assert.AreEqual(0, (FExecutor as TFallbackFaultExecutor)
      .LastResult.NextCalls);
    Assert.AreEqual(0, (FExecutor as TFallbackFaultExecutor)
      .LastResult.ColumnNameReads);
    Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
  end
  else
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

procedure TMappingFallbackTests.ErrorsNeverFallBack(Method, Kind: Integer);
var
  Rows: IQueryResult;
  Options: TQueryMappingOptions;
  Fallback: TFunc<TMappingBook>;
  Calls: Integer;
begin
  Calls := 0;
  case Kind of
    0:
      begin
        ConfigureRows(0);
        TMockQueryExecutor.Names := TArray<string>.Create('wrong schema');
      end;
    1:
      TMockQueryExecutor.Data := TRows.Create(TValues.Create('not an integer',
        'title'));
    2:
      TMockQueryExecutor.Data :=
        TRows.Create(TValues.Create(TValue.Empty, 'title'));
    3:
      (FExecutor as TFallbackFaultExecutor).FailOnNext := 1;
end;
Fallback := function: TMappingBook
  begin
    Inc(Calls);
    Result := FExisting;
  end;
Options := TQueryMappingOptions.Create;
try
  if Kind = 4 then
    Options.RegisterConverter<Integer, Integer>(
      function(Value: Integer): Integer
      begin
        raise EInvalidOp.Create('converter failure');
      end);
  if Method < 2 then
    Rows := OpenRows;
  try
    case Method of
      0:
        TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback, Options).Free;
      1:
        TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback, Options).Free;
      2:
        TQuery.Create('Books').Execute(FExecutor).FirstOrElse<TMappingBook>
          (Fallback, Options).Free;
      3:
        TQuery.Create('Books').Execute(FExecutor).SingleOrElse<TMappingBook>
          (Fallback, Options).Free;
    end;
    Assert.Fail('Expected failure, not a fallback');
  except
    on E: EQueryMappingException do
      Assert.IsTrue(Kind < 3);
    on E: EInvalidOp do
      Assert.IsTrue(Kind in [3, 4]);
  end;
  Assert.AreEqual(0, Calls);
  if Method >= 2 then
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(TMappingBook.Created - FCreated - 1, TMappingBook.Destroyed -
    FDestroyed, 'Every partial mapped object must be freed');
  CheckExisting;
finally
  Options.Free;
  Rows := nil;
end;
end;

procedure TMappingFallbackTests.CallbackFailure(Method: Integer);
var
  Rows: IQueryResult;
  Fallback: TFunc<TMappingBook>;
  Failure: EInvalidOp;
  Calls: Integer;
begin
  ConfigureRows(0);
  Calls := 0;
  Failure := EInvalidOp.Create('fallback failed');
  Fallback := function: TMappingBook
    begin
      Inc(Calls);
      if Method >= 2 then
        Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
      raise Failure;
    end;
  if Method < 2 then
    Rows := OpenRows;
  try
    case Method of
      0:
        TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback).Free;
      1:
        TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback).Free;
      2:
        TQuery.Create('Books').Execute(FExecutor).FirstOrElse<TMappingBook>
          (Fallback).Free;
      3:
        TQuery.Create('Books').Execute(FExecutor).SingleOrElse<TMappingBook>
          (Fallback).Free;
    end;
    Assert.Fail('Expected callback exception');
  except
    on E: EInvalidOp do
      Assert.IsTrue(E = Failure, 'Preserve exception identity');
  end;
  Assert.AreEqual(1, Calls);
  if Method >= 2 then
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  CheckExisting;
end;

procedure TMappingFallbackTests.MissingResult(Method: Integer);
var
  Rows: IQueryResult;
  Facade: TQueryResult;
  Calls: Integer;
  Fallback: TFunc<TMappingBook>;
begin
  Calls := 0;
  Facade := Default (TQueryResult);
  Fallback := function: TMappingBook
    begin
      Inc(Calls);
      Result := nil;
    end;
  try
    case Method of
      0:
        TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback).Free;
      1:
        TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback).Free;
      2:
        Facade.FirstOrElse<TMappingBook>(Fallback).Free;
      3:
        Facade.SingleOrElse<TMappingBook>(Fallback).Free;
    end;
    Assert.Fail('Expected missing result error');
  except
    on E: EArgumentNilException do
      Assert.IsTrue(Pos('Rows', E.Message) > 0);
  end;
  Assert.AreEqual(0, Calls);
end;

procedure TMappingFallbackTests.RetainedResults(Method: Integer);
var
  A, B: TQueryResult;
  Rows: IQueryResult;
  Fallback: TFunc<TMappingBook>;
  Book: TMappingBook;
begin
  ConfigureRows(0);
  Fallback := function: TMappingBook
    begin
      Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount,
        'Independent owners keep the empty result alive during fallback');
      Result := FExisting;
    end;
  if Method < 2 then
    Rows := OpenRows
  else
  begin
    A := TQuery.Create('Books').Execute(FExecutor);
    B := A;
    Rows := A.AsRaw;
  end;
  case Method of
    0:
      Book := TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback);
    1:
      Book := TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback);
    2:
      Book := A.FirstOrElse<TMappingBook>(Fallback);
    3:
      Book := A.SingleOrElse<TMappingBook>(Fallback);
  else
    Book := nil;
  end;
  Assert.IsTrue(Book = FExisting);
  if Method >= 2 then
  begin
    Assert.IsNull(A.AsRaw);
    Assert.AreEqual(2, B.ColumnCount);
    Assert.IsFalse(B.Next);
    B := Default (TQueryResult);
  end;
  Assert.AreEqual(2, Rows.ColumnCount);
  Assert.IsFalse(Rows.Next);
  Rows := nil;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  CheckExisting;
end;

procedure TMappingFallbackTests.RemainingRows(Method: Integer);
var
  A: TQueryResult;
  Rows: IQueryResult;
  Book: TMappingBook;
  Calls: Integer;
  Fallback: TFunc<TMappingBook>;
begin
  ConfigureRows(3);
  if Method < 2 then
    Rows := OpenRows
  else
  begin
    A := TQuery.Create('Books').Execute(FExecutor);
    Rows := A.AsRaw;
  end;
  Assert.IsTrue(Rows.Next);
  Calls := 0;
  Book := nil;
  Fallback := function: TMappingBook
    begin
      Inc(Calls);
      Result := FExisting;
    end;
  try
    try
      case Method of
        0:
          Book := TQueryMapper.FirstOrElse<TMappingBook>(Rows, Fallback);
        1:
          Book := TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback);
        2:
          Book := A.FirstOrElse<TMappingBook>(Fallback);
        3:
          Book := A.SingleOrElse<TMappingBook>(Fallback);
      end;
      Assert.IsFalse(Odd(Method), 'Single must reject two remaining rows');
      Assert.AreEqual(2, Book.Id);
    except
      on E: EQueryMappingException do
        Assert.IsTrue(Odd(Method));
    end;
    Assert.AreEqual(0, Calls);
    if Odd(Method) then
    begin
      Assert.AreEqual(3, (FExecutor as TFallbackFaultExecutor)
        .LastResult.NextCalls);
      Assert.AreEqual(3, Rows.GetValue(0).AsInteger);
      Assert.IsFalse(Rows.Next);
    end
    else
    begin
      Assert.AreEqual(2, (FExecutor as TFallbackFaultExecutor)
        .LastResult.NextCalls);
      Assert.IsTrue(Rows.Next);
      Assert.AreEqual(3, Rows.GetValue(0).AsInteger);
    end;
  finally
    if Book <> FExisting then
      Book.Free;
  end;
end;

procedure TMappingFallbackTests.NullableOptions(Method: Integer);
var
  Rows: IQueryResult;
  Book: TNullableBook;
  Fallback: TFunc<TNullableBook>;
  Options: TQueryMappingOptions;
  Calls, Created, Destroyed: Integer;
begin
  TMockQueryExecutor.Names := TArray<string>.Create('Rating', 'Title');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create('abc', TValue.Empty));
  Created := TNullableBook.Created;
  Destroyed := TNullableBook.Destroyed;
  Calls := 0;
  Book := nil;
  Fallback := function: TNullableBook
    begin
      Inc(Calls);
      Result := nil;
    end;
  Options := TQueryMappingOptions.Create;
  try
    Options.RegisterConverter<string, Integer>(
      function(S: string): Integer
      begin
        Result := Length(S);
      end);
    if Method < 2 then
      Rows := OpenRows;
    case Method of
      0:
        Book := TQueryMapper.FirstOrElse<TNullableBook>(Rows, Fallback,
          Options);
      1:
        Book := TQueryMapper.SingleOrElse<TNullableBook>(Rows,
          Fallback, Options);
      2:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .FirstOrElse<TNullableBook>(Fallback, Options);
      3:
        Book := TQuery.Create('Books').Execute(FExecutor)
          .SingleOrElse<TNullableBook>(Fallback, Options);
    end;
    Assert.AreEqual(0, Calls);
    Assert.AreEqual(3, Book.Rating.Value);
    Assert.IsFalse(Book.Title.HasValue);
    if Method >= 2 then
      Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  finally
    Book.Free;
    Options.Free;
    Rows := nil;
  end;
  Assert.AreEqual(Created + 1, TNullableBook.Created);
  Assert.AreEqual(Destroyed + 1, TNullableBook.Destroyed);
end;

procedure TMappingFallbackTests.LaterProviderFailure(Method: Integer);
var
  Rows: IQueryResult;
  Calls: Integer;
  Fallback: TFunc<TMappingBook>;
begin
  ConfigureRows(3);
  (FExecutor as TFallbackFaultExecutor).FailOnNext := 2;
  Calls := 0;
  Fallback := function: TMappingBook
    begin
      Inc(Calls);
      Result := FExisting;
    end;
  if Method < 2 then
    Rows := OpenRows;
  try
    if Method = 1 then
      TQueryMapper.SingleOrElse<TMappingBook>(Rows, Fallback).Free
    else
      TQuery.Create('Books').Execute(FExecutor).SingleOrElse<TMappingBook>
        (Fallback).Free;
    Assert.Fail('Expected second Next failure');
  except
    on E: EInvalidOp do
      Assert.IsTrue(Pos('Provider Next failed', E.Message) > 0);
  end;
  Assert.AreEqual(0, Calls);
  Assert.AreEqual(FCreated + 2, TMappingBook.Created);
  Assert.AreEqual(FDestroyed + 1, TMappingBook.Destroyed);
  if Method >= 2 then
    Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

initialization

TDUnitX.RegisterTestFixture(TMappingFallbackTests);

end.
