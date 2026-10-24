program MappingBenchmarks;
{$APPTYPE CONSOLE}
{$O+}

uses
  System.SysUtils, System.Rtti, System.Diagnostics, System.Generics.Collections,
  QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Mapping,
  QueryBuilder4Delphi.Nullable, Execution.Mock in '..\test\Execution.Mock.pas';

type
{$RTTI EXPLICIT METHODS([vcPublic]) PROPERTIES([vcPublic]) FIELDS([])}
  TBenchmarkBook = class
  private
    FId: Integer;
    FTitle: string;
    FPrice: TNullable<Currency>;
    FActive: Boolean;
  public
    class var Live, Peak: Integer;
    constructor Create;
    destructor Destroy; override;
    property Id: Integer read FId write FId;
    property Title: string read FTitle write FTitle;
    property Price: TNullable<Currency> read FPrice write FPrice;
    property Active: Boolean read FActive write FActive;
  end;
{$RTTI INHERIT}

constructor TBenchmarkBook.Create;
begin
  inherited;
  Inc(Live);
  if Live > Peak then
    Peak := Live;
end;

destructor TBenchmarkBook.Destroy;
begin
  Dec(Live);
  inherited;
end;

function HeapAllocatedBytes: Int64;
var
  State: TMemoryManagerState;
  Block: TSmallBlockTypeState;
begin
  // Windows-only benchmark: use supported RTL memory manager statistics.
{$WARN SYMBOL_PLATFORM OFF}
  GetMemoryManagerState(State);
{$WARN SYMBOL_PLATFORM ON}
  Result := Int64(State.TotalAllocatedMediumBlockSize) +
    Int64(State.TotalAllocatedLargeBlockSize);
  for Block in State.SmallBlockTypeStates do
    Inc(Result, Int64(Block.AllocatedBlockCount) * Block.UseableBlockSize);
end;

procedure Run(Count: Integer; Stream: Boolean; const Cache: string);
var
  Data: TRows;
  R: IQueryResult;
  Books: TObjectList<TBenchmarkBook>;
  I, Seen: Integer;
  Checksum, BeforeBytes, SampleBytes: Int64;
  Watch: TStopwatch;
  MappingMs: Double;
  Method: string;
begin
  // Fixture generation/copying is excluded from both timing and heap deltas.
  SetLength(Data, Count);
  for I := 0 to Count - 1 do
    Data[I] := TValues.Create(I + 1, 'Benchmark title',
      TValue.From<Currency>(12.5), True);
  R := TMockQueryResult.Create(['Id', 'Title', 'Price', 'Active'], nil, Data,
    True, -1);
  Data := nil;
  TBenchmarkBook.Peak := 0;
  Checksum := 0;
  Seen := 0;
  BeforeBytes := HeapAllocatedBytes;
  SampleBytes := BeforeBytes;
  Watch := TStopwatch.StartNew;
  if Stream then
  begin
    Method := 'ForEach';
    TQueryMapper.ForEach<TBenchmarkBook>(R,
      procedure(Book: TBenchmarkBook)
      begin
        Inc(Seen);
        Inc(Checksum, Book.Id);
        if Seen = 1 then
          SampleBytes := HeapAllocatedBytes;
      end);
    MappingMs := Watch.Elapsed.TotalMilliseconds;
  end
  else
  begin
    Method := 'ToList';
    Books := TQueryMapper.ToList<TBenchmarkBook>(R);
    try
      MappingMs := Watch.Elapsed.TotalMilliseconds;
      SampleBytes := HeapAllocatedBytes;
      for I := 0 to Books.Count - 1 do
      begin
        Inc(Seen);
        Inc(Checksum, Books[I].Id);
      end;
    finally
      Books.Free;
    end;
  end;
  Watch.Stop;
  if (Seen <> Count) or (Checksum <> Int64(Count) * (Count + 1) div 2) or
    (TBenchmarkBook.Live <> 0) then
    raise Exception.Create('Benchmark validation failed');
  Writeln(Format('%s,%d,%s,%.3f,%.3f,%d,%d,%d', [Cache, Count, Method,
    MappingMs, Watch.Elapsed.TotalMilliseconds, SampleBytes - BeforeBytes,
    TBenchmarkBook.Peak, Checksum], TFormatSettings.Invariant));
end;

var
  Count, I: Integer;
  Stream: Boolean;

begin
  ReportMemoryLeaksOnShutdown := True;
  try
    Count := StrToIntDef(ParamStr(1), 100);
    if (Count <> 100) and (Count <> 10000) and (Count <> 100000) then
      raise EArgumentException.Create('Use 100, 10000 or 100000 rows');
    Stream := SameText(ParamStr(2), 'stream');
    Writeln('cache,rows,method,mapping_ms,total_ms,sampled_heap_delta_bytes,peak_live_objects,checksum');
    Run(Count, Stream, 'cold');
    for I := 1 to 5 do
      Run(Count, Stream, 'warm');
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      ExitCode := 1;
    end;
  end;

end.
