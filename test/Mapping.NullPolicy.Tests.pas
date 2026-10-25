unit Mapping.NullPolicy.Tests;

interface

uses
  System.SysUtils, System.Rtti, System.Generics.Collections,
  DUnitX.TestFramework, QueryBuilder4Delphi.Query.Core,
  QueryBuilder4Delphi.Mapping, QueryBuilder4Delphi.Nullable;

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TInitializedDTO<T> = class
  private
    FValue: T;
    FAssignments: Integer;
    procedure SetValue(const Value: T);
  public
    class var InitialValue: T;
    constructor Create;
    property Value: T read FValue write SetValue;
    property Assignments: Integer read FAssignments;
  end;
{$RTTI INHERIT}

  [TestFixture]
  TNullPolicyTests = class
  private
    function NullRows: IQueryResult;
    procedure CheckDefault<T>(const Seed: T);
  public
    [Test]
    procedure SupportedDefaultsOverwriteConstructors;
    [TestCase('OmittedOptionsUnsupported', '0')]
    [TestCase('DefaultUnsupported', '1')]
    [TestCase('ThrowSupported', '2')]
    [TestCase('ThrowUnsupported', '3')]
    procedure SqlNullDiagnostics(Mode: Integer);
    [TestCase('Default', '0')]
    [TestCase('Throw', '1')]
    [TestCase('Skip', '2')]
    procedure NullableSemantics(Policy: Integer);
    [TestCase('Default', '0')]
    [TestCase('Throw', '1')]
    [TestCase('Skip', '2')]
    procedure ConvertersAndRegistrations(Policy: Integer);
    [TestCase('Default', '0')]
    [TestCase('Throw', '1')]
    [TestCase('Skip', '2')]
    procedure FluentOperationsAndCleanup(Policy: Integer);
  end;

implementation

uses
  DUnitX.Assert, Data.FmtBcd, Data.SqlTimSt, Execution.Mock,
  Mapping.Tests, Mapping.Values.Tests, QueryBuilder4Delphi.Query;

function PolicyRows(const Names: TArray<string>; const Data: TRows)
  : IQueryResult;
begin
  Result := TMockQueryResult.Create(Names, nil, Data, True, -1);
end;

constructor TInitializedDTO<T>.Create;
begin
  inherited;
  FValue := InitialValue;
end;

procedure TInitializedDTO<T>.SetValue(const Value: T);
begin
  Inc(FAssignments);
  FValue := Value;
end;

function TNullPolicyTests.NullRows: IQueryResult;
begin
  Result := PolicyRows(['Value'], TRows.Create(TValues.Create(TValue.Empty)));
end;

procedure TNullPolicyTests.CheckDefault<T>(const Seed: T);
var
  Options: TQueryMappingOptions;
  Item: TInitializedDTO<T>;
  Items: TObjectList<TInitializedDTO<T>>;
  Mode: Integer;
begin
  TInitializedDTO<T>.InitialValue := Seed;
  Options := nil;
  try
    for Mode := 0 to 4 do
    begin
      if Mode = 1 then
        Options := TQueryMappingOptions.Create;
      if Mode = 2 then
        Options.NullBehavior := nmbDefault;
      if Mode = 3 then
        Options.NullBehavior := nmbSkip;
      if Mode = 4 then
      begin
        Options.NullBehavior := nmbThrow;
        Assert.WillRaise(TTestLocalMethod(
          procedure
          begin
            TQueryMapper.FirstOrDefault < TInitializedDTO < T >> (NullRows,
              Options).Free;
          end), EQueryMappingException);
        Assert.WillRaise(TTestLocalMethod(
          procedure
          begin
            TQueryMapper.ToList < TInitializedDTO < T >> (NullRows,
              Options).Free;
          end), EQueryMappingException);
        Continue;
      end;
      Item := TQueryMapper.FirstOrDefault < TInitializedDTO < T >>
        (NullRows, Options);
      try
        if Mode = 3 then
        begin
          Assert.AreEqual<T>(Seed, Item.Value);
          Assert.AreEqual(0, Item.Assignments);
        end
        else
        begin
          Assert.AreEqual<T>(Default (T), Item.Value);
          Assert.AreEqual(1, Item.Assignments);
        end;
      finally
        Item.Free;
      end;
      Items := TQueryMapper.ToList < TInitializedDTO < T >> (NullRows, Options);
      try
        Assert.AreEqual<NativeInt>(1, Items.Count);
        if Mode = 3 then
          Assert.AreEqual<T>(Seed, Items[0].Value)
        else
          Assert.AreEqual<T>(Default (T), Items[0].Value);
      finally
        Items.Free;
      end;
    end;
  finally
    Options.Free;
    TInitializedDTO<T>.InitialValue := Default (T);
  end;
end;

procedure TNullPolicyTests.SupportedDefaultsOverwriteConstructors;
begin
  CheckDefault<string>('constructor');
  CheckDefault<Boolean>(True);
  CheckDefault<ShortInt>(-7);
  CheckDefault<SmallInt>(-7);
  CheckDefault<Integer>(-7);
  CheckDefault<Int64>(-7);
  CheckDefault<Byte>(7);
  CheckDefault<Word>(7);
  CheckDefault<Cardinal>(7);
  CheckDefault<UInt64>(7);
  CheckDefault<Single>(1.5);
  CheckDefault<Double>(1.5);
  CheckDefault<Extended>(1.5);
  CheckDefault<Currency>(1.5);
  CheckDefault<TDateTime>(EncodeDate(2026, 10, 24));
  CheckDefault<TGUID>(StringToGUID('{20BF89A2-91B6-45CB-B610-98320D788099}'));
  CheckDefault<TBytes>(TBytes.Create(1, 2));
  CheckDefault<TBcd>(StrToBcd('12.34', TFormatSettings.Invariant));
  CheckDefault<TSQLTimeStamp>(DateTimeToSQLTimeStamp(Now));
  CheckDefault<TSQLTimeStampOffset>(DateTimeToSQLTimeStampOffset(Now, 2, 0));
end;

procedure TNullPolicyTests.SqlNullDiagnostics(Mode: Integer);
var
  Options: TQueryMappingOptions;
  Rows: IQueryResult;
  Baseline: Integer;
begin
  Baseline := TMockQueryResult.LiveCount;
  Options := nil;
  try
    if Mode > 0 then
    begin
      Options := TQueryMappingOptions.Create;
      Assert.AreEqual(nmbDefault, Options.NullBehavior);
      if Mode >= 2 then
        Options.NullBehavior := nmbThrow;
    end;
    Rows := NullRows;
    try
      if Mode = 2 then
        TQueryMapper.First < TTypedDTO < Integer >> (Rows, Options).Free
      else
        TQueryMapper.First < TTypedDTO < TApplicationCode >>
          (Rows, Options).Free;
      Assert.Fail('Expected SQL NULL mapping failure');
    except
      on E: EQueryMappingException do
      begin
        Assert.IsTrue(Pos('row 1', E.Message) > 0, E.Message);
        Assert.IsTrue(Pos('column "Value" [0]', E.Message) > 0, E.Message);
        Assert.IsTrue(Pos('source SQL NULL', E.Message) > 0, E.Message);
        if Mode >= 2 then
        begin
          Assert.IsTrue(Pos('rejected by nmbThrow', E.Message) > 0, E.Message);
          Assert.IsTrue(Pos('does not support default-value mapping',
            E.Message) = 0);
        end
        else
        begin
          Assert.IsTrue(Pos('does not support default-value mapping', E.Message)
            > 0, E.Message);
          Assert.IsTrue(Pos('nmbThrow', E.Message) = 0);
        end;
      end;
    end;
    Assert.AreEqual(Baseline + 1, TMockQueryResult.LiveCount,
      'Static mapping keeps the caller-owned result alive after failure');
  finally
    Rows := nil;
    Options.Free;
  end;
  Assert.AreEqual(Baseline, TMockQueryResult.LiveCount);
end;

procedure TNullPolicyTests.NullableSemantics(Policy: Integer);
var
  Options: TQueryMappingOptions;
  Items: TObjectList<TNullableBook>;
  Registration: Integer;
begin
  Options := TQueryMappingOptions.Create;
  try
    Options.NullBehavior := TNullMappingBehavior(Policy);
    for Registration := 0 to 1 do
    begin
      if Registration = 1 then
      begin
        Options.RegisterNullable<Integer>;
        Options.RegisterNullable<string>;
        Options.RegisterNullable<Boolean>;
      end;
      Items := TQueryMapper.ToList<TNullableBook>
        (PolicyRows(['Rating', 'Title', 'Published'],
        TRows.Create(TValues.Create(TValue.Empty, TValue.Empty, TValue.Empty),
        TValues.Create(0, '', False))), Options);
      try
        Assert.IsFalse(Items[0].Rating.HasValue);
        Assert.IsFalse(Items[0].Title.HasValue);
        Assert.IsFalse(Items[0].Published.HasValue);
        Assert.IsTrue(Items[1].Rating.HasValue);
        Assert.AreEqual(0, Items[1].Rating.Value);
        Assert.IsTrue(Items[1].Title.HasValue);
        Assert.AreEqual('', Items[1].Title.Value);
        Assert.IsTrue(Items[1].Published.HasValue);
        Assert.IsFalse(Items[1].Published.Value);
      finally
        Items.Free;
      end;
    end;
  finally
    Options.Free;
  end;
end;

procedure TNullPolicyTests.ConvertersAndRegistrations(Policy: Integer);
var
  Options: TQueryMappingOptions;
  Item: TTypedDTO<TNullable<TApplicationCode>>;
  Calls: Integer;
begin
  Calls := 0;
  Options := TQueryMappingOptions.Create;
  try
    Options.NullBehavior := TNullMappingBehavior(Policy);
    Options.RegisterNullable<TApplicationCode>;
    Options.RegisterConverter<string, TApplicationCode>(
      function(Text: string): TApplicationCode
      begin
        Inc(Calls);
        Result.Text := 'converted:' + Text;
      end);
    Item := TQueryMapper.First < TTypedDTO < TNullable<TApplicationCode> >>
      (NullRows, Options);
    try
      Assert.IsFalse(Item.Value.HasValue);
      Assert.AreEqual(0, Calls);
    finally
      Item.Free;
    end;
    Item := TQueryMapper.First < TTypedDTO < TNullable<TApplicationCode> >>
      (PolicyRows(['Value'], TRows.Create(TValues.Create(''))), Options);
    try
      Assert.IsTrue(Item.Value.HasValue);
      Assert.AreEqual('converted:', Item.Value.Value.Text);
      Assert.AreEqual(1, Calls);
    finally
      Item.Free;
    end;
    // SQL NULL must never invoke an ordinary converter, even for a supported target.
    Options.RegisterConverter<Integer, Integer>(
      function(Value: Integer): Integer
      begin
        Inc(Calls);
        Result := Value + 10;
      end);
    if Policy <> Ord(nmbThrow) then
    begin
      TQueryMapper.First < TTypedDTO < Integer >> (NullRows, Options).Free;
      Assert.AreEqual(1, Calls);
    end;
    Assert.WillRaise(TTestLocalMethod(
      procedure
      begin
        TQueryMapper.First < TTypedDTO < Integer >> (PolicyRows(['Value'],
          TRows.Create(TValues.Create('bad'))), Options).Free;
      end), EQueryMappingException);
    // A custom converter does not enable default construction of arbitrary records.
    if Policy <> Ord(nmbSkip) then
      Assert.WillRaise(TTestLocalMethod(
        procedure
        begin
          TQueryMapper.First < TTypedDTO < TApplicationCode >> (NullRows,
            Options).Free;
        end), EQueryMappingException);
  finally
    Options.Free;
  end;
end;

procedure TNullPolicyTests.FluentOperationsAndCleanup(Policy: Integer);
var
  Options: TQueryMappingOptions;
  Executor: IQueryExecutor;
  Item: TMappingBook;
  Nullable: TNullableBook;
  Items: TObjectList<TMappingBook>;
  Method, Baseline, Created, Destroyed, Seen: Integer;
  Rows: TQueryResult;
  Check: TProc<TMappingBook>;
  Run: TProc;
begin
  Options := TQueryMappingOptions.Create;
  Executor := TMockQueryExecutor.Create(TSqlDialect.Sqlite);
  Baseline := TMockQueryResult.LiveCount;
  try
    Options.NullBehavior := TNullMappingBehavior(Policy);
    Check := procedure(Book: TMappingBook)
      begin
        Inc(Seen);
        if Policy = Ord(nmbSkip) then
          Assert.AreEqual('constructor title', Book.Title)
        else
          Assert.AreEqual('', Book.Title);
      end;
    for Method := 0 to 4 do
    begin
      Created := TMappingBook.Created;
      Destroyed := TMappingBook.Destroyed;
      Seen := 0;
      TMockQueryExecutor.Names := TArray<string>.Create('BookTitle');
      TMockQueryExecutor.Data := TRows.Create(TValues.Create(TValue.Empty));
      Run := procedure
        begin
          Rows := TQuery.Create('Books').Execute(Executor);
          Item := nil;
          Items := nil;
          try
            case Method of
              0:
                begin
                  Items := Rows.ToList<TMappingBook>(Options);
                  Check(Items[0]);
                end;
              1:
                Item := Rows.FirstOrDefault<TMappingBook>(Options);
              2:
                Item := Rows.First<TMappingBook>(Options);
              3:
                Item := Rows.Single<TMappingBook>(Options);
              4:
                Rows.ForEach<TMappingBook>(Check, Options);
            end;
            if Item <> nil then
              Check(Item);
          finally
            Item.Free;
            Items.Free;
            Assert.IsNull(Rows.AsRaw);
            Rows := Default (TQueryResult);
          end;
        end;
      if Policy = Ord(nmbThrow) then
        Assert.WillRaise(TTestLocalMethod(Run), EQueryMappingException)
      else
      begin
        Run();
        Assert.AreEqual(1, Seen);
      end;
      Assert.AreEqual(Created + 1, TMappingBook.Created);
      Assert.AreEqual(Destroyed + 1, TMappingBook.Destroyed);
      Assert.AreEqual(Baseline, TMockQueryResult.LiveCount,
        'method ' + IntToStr(Method));
      TMockQueryExecutor.Names := TArray<string>.Create('Rating', 'Title');
      TMockQueryExecutor.Data :=
        TRows.Create(TValues.Create(TValue.Empty, TValue.Empty));
      Nullable := nil;
      case Method of
        0:
          begin
            TQuery.Create('Books').Execute(Executor).ToList<TNullableBook>
              (Options).Free;
          end;
        1:
          Nullable := TQuery.Create('Books').Execute(Executor)
            .FirstOrDefault<TNullableBook>(Options);
        2:
          Nullable := TQuery.Create('Books').Execute(Executor)
            .First<TNullableBook>(Options);
        3:
          Nullable := TQuery.Create('Books').Execute(Executor)
            .Single<TNullableBook>(Options);
        4:
          TQuery.Create('Books').Execute(Executor).ForEach<TNullableBook>(
            procedure(Book: TNullableBook)
            begin
              Assert.IsFalse(Book.Rating.HasValue);
              Assert.IsFalse(Book.Title.HasValue);
            end, Options);
      end;
      try
        if Nullable <> nil then
        begin
          Assert.IsFalse(Nullable.Rating.HasValue);
          Assert.IsFalse(Nullable.Title.HasValue);
        end;
      finally
        Nullable.Free;
      end;
      Assert.AreEqual(Baseline, TMockQueryResult.LiveCount,
        'method ' + IntToStr(Method));
    end;
  finally
    Run := nil;
    Check := nil;
    Options.Free;
  end;
end;

initialization

TDUnitX.RegisterTestFixture(TNullPolicyTests);

end.
