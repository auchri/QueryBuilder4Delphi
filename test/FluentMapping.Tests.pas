unit FluentMapping.Tests;

interface

uses
  DUnitX.TestFramework, QueryBuilder4Delphi.Query.Core;

type

  [TestFixture]
  TFluentMappingTests = class
  private
    FExecutor: IQueryExecutor;
    FResultBaseline, FCreated, FDestroyed: Integer;
    procedure FailMapping(First: Integer);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    [Test]
    procedure TemporaryListAndOwnership;
    [Test]
    procedure TemporaryFirstAndOwnership;
    [Test]
    procedure EmptyResults;
    [Test]
    procedure AttributesAndPartialProjection;
    [Test]
    procedure CopyAssignmentAndRawLifetime;
    [Test]
    procedure ReaderDelegation;
    [Test]
    procedure ImplicitConversionAndStaticMapper;
    [Test]
    procedure CursorConsumption;
    [TestCase('ListNull', '0,0')]
    [TestCase('FirstNull', '1,0')]
    [TestCase('ListInvalid', '0,1')]
    [TestCase('FirstInvalid', '1,1')]
    procedure MappingErrorsReleaseResources(First, Invalid: Integer);
    [Test]
    procedure SetterExceptionIsPreserved;
    [TestCase('List', '0')]
    [TestCase('First', '1')]
    procedure CommandsCannotBeMapped(First: Integer);
    [Test]
    procedure EmptyFacade;
    [Test]
    procedure FluentMappingInAnonymousMethod;
  end;

implementation

uses
  System.SysUtils, System.Rtti, System.Generics.Collections, DUnitX.Assert,
  QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Mapping,
  Execution.Mock, Mapping.Tests;

procedure TFluentMappingTests.Setup;
begin
  FResultBaseline := TMockQueryResult.LiveCount;
  FCreated := TMappingBook.Created;
  FDestroyed := TMappingBook.Destroyed;
  FExecutor := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  TMockQueryExecutor.Names := TArray<string>.Create('BookId', 'BookTitle');
  TMockQueryExecutor.Types := TArray<TQueryValueType>.Create(qtInt64, qtString);
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(TValue.From<Int64>(1),
    'Alpha'), TValues.Create(TValue.From<Int64>(2), 'Beta'));
end;

procedure TFluentMappingTests.TearDown;
begin
  FExecutor := nil;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount, 'Result leaked');
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed, 'Mapped object leaked');
end;

procedure TFluentMappingTests.TemporaryListAndOwnership;
var
  Books: TObjectList<TMappingBook>;
begin
  Books := TQuery.Create('Books').Select(['Id AS BookId', 'Title AS BookTitle'])
    .OrderBy('Id').Execute(FExecutor).ToList<TMappingBook>();
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.IsTrue(Books.OwnsObjects);
    Assert.AreEqual(1, Books[0].Id);
    Assert.AreEqual('Alpha', Books[0].Title);
    Assert.AreEqual(2, Books[1].Id);
    Assert.AreEqual('Beta', Books[1].Title);
  finally
    Books.Free;
  end;
  Assert.AreEqual(2, TMappingBook.Destroyed - FDestroyed);
end;

procedure TFluentMappingTests.TemporaryFirstAndOwnership;
var
  Book: TMappingBook;
begin
  Book := TQuery.Create('Books').Where('Id', 42).Execute(FExecutor)
    .FirstOrDefault<TMappingBook>();
  try
    Assert.IsNotNull(Book);
    Assert.AreEqual(1, Book.Id);
    Assert.AreEqual('Alpha', Book.Title);
    Assert.AreEqual(0, TMappingBook.Destroyed - FDestroyed);
  finally
    Book.Free;
  end;
  Assert.AreEqual(1, TMappingBook.Destroyed - FDestroyed);
end;

procedure TFluentMappingTests.EmptyResults;
var
  Books: TObjectList<TMappingBook>;
  Book: TMappingBook;
begin
  TMockQueryExecutor.Data := nil;
  Books := TQuery.Create('Books').Execute(FExecutor).ToList<TMappingBook>();
  try
    Assert.AreEqual<NativeInt>(0, Books.Count);
    Assert.IsTrue(Books.OwnsObjects);
  finally
    Books.Free;
  end;
  Book := TQuery.Create('Books').Execute(FExecutor)
    .FirstOrDefault<TMappingBook>();
  try
    Assert.IsNull(Book);
  finally
    Book.Free;
  end;
  Assert.AreEqual(0, TMappingBook.Created - FCreated);
end;

procedure TFluentMappingTests.AttributesAndPartialProjection;
var
  Book: TMappingBook;
begin
  TMockQueryExecutor.Names := TArray<string>.Create('booktitle', 'Ignored');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create('Alias', 'discard'));
  Book := TQuery.Create('Books').Select('Title AS BookTitle').Execute(FExecutor)
    .FirstOrDefault<TMappingBook>();
  try
    Assert.AreEqual('Alias', Book.Title);
    Assert.AreEqual(0, Book.Id);
    Assert.AreEqual('constructor default', Book.DefaultValue);
    Assert.AreEqual('ignored default', Book.Ignored);
  finally
    Book.Free;
  end;
end;

procedure TFluentMappingTests.CopyAssignmentAndRawLifetime;
var
  A, B: TQueryResult;
  Raw: IQueryResult;
begin
  A := TQuery.Create('Books').Execute(FExecutor);
  B := A;
  A := Default (TQueryResult);
  FExecutor := nil;
  Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
  Assert.IsTrue(B.Next);
  Assert.AreEqual('Alpha', B.GetValue('BookTitle').AsString);
  Raw := B.AsRaw;
  B := Default (TQueryResult);
  Assert.AreEqual(FResultBaseline + 1, TMockQueryResult.LiveCount);
  Assert.IsTrue(Raw.Next);
  Assert.AreEqual('Beta', Raw.GetValue(1).AsString);
  Raw := nil;
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
end;

procedure TFluentMappingTests.ReaderDelegation;
var
  Rows, CopyOfRows: TQueryResult;
begin
  Rows := TQuery.Create('Books').Execute(FExecutor);
  CopyOfRows := Rows;
  Assert.IsTrue(Rows.HasResultSet);
  Assert.AreEqual<Int64>(-1, Rows.RowsAffected);
  Assert.AreEqual(2, Rows.ColumnCount);
  Assert.AreEqual('BookId', Rows.GetColumnName(0));
  Assert.AreEqual('BookTitle', Rows.ColumnNames[1]);
  Assert.AreEqual<TQueryValueType>(qtInt64, Rows.GetColumnType(0));
  Assert.AreEqual(1, Rows.GetColumnIndex('BOOKTITLE'));
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Rows.GetValue(0);
    end), EQueryException);
  Assert.IsTrue(Rows.Next);
  Assert.AreEqual<Int64>(1, CopyOfRows.GetValue(0).AsInt64);
  Assert.AreEqual('Alpha', Rows.GetValue('BookTitle').AsString);
  Assert.IsFalse(Rows.IsNull(0));
  Assert.IsFalse(Rows.IsNull('BookTitle'));
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Rows.GetColumnIndex('Missing');
    end), EQueryException);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Rows.GetColumnName(99);
    end), EQueryException);
  Assert.IsTrue(CopyOfRows.Next);
  Assert.AreEqual<Int64>(2, Rows.GetValue(0).AsInt64);
  Assert.IsFalse(Rows.Next);
  Assert.IsFalse(CopyOfRows.Next);
end;

procedure TFluentMappingTests.ImplicitConversionAndStaticMapper;
var
  Rows: IQueryResult;
  Books: TObjectList<TMappingBook>;
  Book: TMappingBook;
begin
  Rows := TQuery.Create('Books').Execute(FExecutor);
  Assert.IsTrue(Rows.Next);
  Assert.AreEqual('Alpha', Rows.GetValue('BookTitle').AsString);
  Book := TQueryMapper.FirstOrDefault<TMappingBook>(Rows);
  try
    Assert.AreEqual(2, Book.Id);
  finally
    Book.Free;
  end;
  // Conversion is also accepted for a const interface argument.
  Books := TQueryMapper.ToList<TMappingBook>(TQuery.Create('Books')
    .Execute(FExecutor));
  try
    Assert.AreEqual<NativeInt>(2, Books.Count);
    Assert.AreEqual('Beta', Books[1].Title);
  finally
    Books.Free;
  end;
end;

procedure TFluentMappingTests.CursorConsumption;
var
  Rows: TQueryResult;
  Book: TMappingBook;
  Books: TObjectList<TMappingBook>;
begin
  Rows := TQuery.Create('Books').Execute(FExecutor);
  Book := Rows.FirstOrDefault<TMappingBook>();
  try
    Assert.AreEqual(1, Book.Id);
  finally
    Book.Free;
  end;
  Books := Rows.ToList<TMappingBook>();
  try
    Assert.AreEqual<NativeInt>(1, Books.Count);
    Assert.AreEqual(2, Books[0].Id);
  finally
    Books.Free;
  end;
  Assert.IsFalse(Rows.Next);
  Rows := TQuery.Create('Books').Execute(FExecutor);
  Assert.IsTrue(Rows.Next);
  Book := Rows.FirstOrDefault<TMappingBook>();
  try
    Assert.AreEqual(2, Book.Id);
  finally
    Book.Free;
  end;
end;

procedure TFluentMappingTests.FailMapping(First: Integer);
begin
  if First = 1 then
    TQuery.Create('Books').Execute(FExecutor)
      .FirstOrDefault<TMappingBook>().Free
  else
    TQuery.Create('Books').Execute(FExecutor).ToList<TMappingBook>().Free;
end;

procedure TFluentMappingTests.MappingErrorsReleaseResources(First,
  Invalid: Integer);
var
  Value: TValue;
begin
  if Invalid = 1 then
    Value := 'not an integer'
  else
    Value := TValue.Empty;
  if First = 1 then
    TMockQueryExecutor.Data := TRows.Create(TValues.Create(Value, 'bad'))
  else
    TMockQueryExecutor.Data := TRows.Create(TValues.Create(1, 'good'),
      TValues.Create(Value, 'bad'));
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      FailMapping(First);
    end), EQueryMappingException);
  // A nested call scope ensures compiler-managed expression temporaries have
  // finalized before measuring resource lifetime.
  Assert.AreEqual(FResultBaseline, TMockQueryResult.LiveCount);
  Assert.AreEqual(TMappingBook.Created - FCreated, TMappingBook.Destroyed -
    FDestroyed);
  Assert.IsTrue(TMappingBook.Created > FCreated);
end;

procedure TFluentMappingTests.SetterExceptionIsPreserved;
begin
  TMockQueryExecutor.Names := TArray<string>.Create('Id');
  TMockQueryExecutor.Data := TRows.Create(TValues.Create(1));
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      TQuery.Create('Books').Execute(FExecutor)
        .FirstOrDefault<TSetterDTO>().Free;
    end), EInvalidOp);
end;

procedure TFluentMappingTests.CommandsCannotBeMapped(First: Integer);
var
  Command: TQueryResult;
begin
  TMockQueryExecutor.Affected := 7;
  Command := TQuery.Create('Books').Where('Id', 42).AsDelete.Execute(FExecutor);
  Assert.IsFalse(Command.HasResultSet);
  Assert.AreEqual<Int64>(7, Command.RowsAffected);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      if First = 1 then
        Command.FirstOrDefault<TMappingBook>().Free
      else
        Command.ToList<TMappingBook>().Free;
    end), EQueryMappingException);
  Assert.AreEqual(0, TMappingBook.Created - FCreated);
end;

procedure TFluentMappingTests.EmptyFacade;
var
  Rows: TQueryResult;
begin
  Rows := Default (TQueryResult);
  Assert.IsNull(Rows.AsRaw);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Rows.Next;
    end), EQueryException);
  Assert.WillRaise(TTestLocalMethod(
    procedure
    begin
      Rows.ToList<TMappingBook>().Free;
    end), EArgumentNilException);
end;

procedure TFluentMappingTests.FluentMappingInAnonymousMethod;
var
  Action: TProc;
begin
  Action := procedure
    var
      Books: TObjectList<TMappingBook>;
    begin
      Books := TQuery.Create('Books').Execute(FExecutor).ToList<TMappingBook>();
      try
        Assert.AreEqual<NativeInt>(2, Books.Count);
        Assert.AreEqual('Beta', Books[1].Title);
      finally
        Books.Free;
      end;
    end;
  Action();
end;

initialization

TDUnitX.RegisterTestFixture(TFluentMappingTests);

end.
