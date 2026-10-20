# QueryBuilder4Delphi

Delphi-Portierung des SqlKata-QueryBuilders aus dem lokalen C#-Stand
`df4a2377750d34fc057c81886b481e7309ef975e`.
Ziel ist **Delphi 12 oder neuer unter Windows, Win32 und Win64**.

Die Bibliothek baut SQL und Parameterlisten. `SqlKata.Execution`, FireDAC,
Datenbankverbindungen, Ergebnismapping, `Get`, `First` und `Paginate` sind nicht
Bestandteil dieses Piloten. `ForPage` erzeugt dagegen LIMIT/OFFSET bzw. die
entsprechende SQL-Dialektvariante und ist vorhanden.

## Einbinden

`src` zum Delphi-Suchpfad hinzufügen. Die Bibliothek benötigt nur die Delphi-RTL.
Ein Package oder weitere Laufzeitbibliotheken sind nicht erforderlich.

```pascal
uses
  System.SysUtils, System.Rtti,
  SqlKata, SqlKata.Compilers;
```

Abfragen, Compiler und Ergebnisse verwenden **referenzgezählte Interfaces**:
`IQuery`, `ICompiler` und `ISqlResult`. Sie werden beim Verlassen des Scopes
automatisch freigegeben, auch bei Exceptions. `Free` und `try..finally` sind
dafür nicht nötig. `TQuery.Create` und die Compiler-Factories liefern direkt
Interfaces; die vertrauten Fluent-Aufrufe bleiben erhalten.
Übergebene Unterabfragen, Joins, Filter und ConditionGroups werden weiterhin
kopiert. Ein Callback erhält und liefert `IQuery` und muss die ihm übergebene
Abfrage zurückgeben.

## Vollständiges Beispiel

```pascal
program BooksSql;

{$APPTYPE CONSOLE}

uses
  System.SysUtils, SqlKata, SqlKata.Compilers;

var
  Q: IQuery;
  Compiler: ICompiler;
  Compiled: ISqlResult;
begin
  Q := TQuery.Create('Books')
    .Select(['Id', 'Title'])
    .WhereTrue('IsPublished')
    .Where('Lang', 'de')
    .OrderByDesc('PublishedAt')
    .Limit(10);

  Compiler := TSqlServerCompiler.Create;
  Compiled := Compiler.Compile(Q);
  Writeln(Compiled.Sql);
  Writeln(Compiled.Bindings[0].AsString); // de
end.
```

SQL:

```sql
SELECT [Id], [Title] FROM [Books]
WHERE [IsPublished] = cast(1 as bit) AND [Lang] = @p0
ORDER BY [PublishedAt] DESC
OFFSET @p1 ROWS FETCH NEXT @p2 ROWS ONLY
```

Bindings in dieser Reihenfolge: `de`, `0` (Offset), `10` (Limit).

`Sql` enthält benannte Parameter; `RawSql` enthält `?`-Platzhalter.
`Bindings` enthält `TValue`-Werte in SQL-Reihenfolge und `NamedBindings` dieselben
Werte unter `@p0`, `@p1`, … bzw. bei Oracle `:p0`, `:p1`, ….
`ToString` ersetzt Parameter für die Diagnose; zum Ausführen sind SQL und Bindings
getrennt zu verwenden. `ISqlResult.Query` hält die ursprüngliche Abfrage am
Leben. Die Abfrage wird beim Kompilieren nicht verändert.

## Weitere geprüfte Beispiele

Die folgenden Funktionen stehen auch in `test/ReadmeExamples.pas`. DUnitX
kompiliert sie und prüft das erzeugte SQL und die Parameteranzahl.
Die zurückgegebenen Interfaces verwalten ihre Lebensdauer automatisch.

### Join mit Alias

```pascal
function BooksWithAuthors: IQuery;
begin
  Result := TQuery.Create('Books');
  Result.Join('Authors', 'Authors.Id', 'Books.AuthorId')
    .Select(['Books.*', 'Authors.Name as AuthorName']);
end;
```

```sql
SELECT [Books].*, [Authors].[Name] AS [AuthorName]
FROM [Books]
INNER JOIN [Authors] ON [Authors].[Id] = [Books].[AuthorId]
```

### Verschachtelte Bedingungen

```pascal
function NestedConditions: IQuery;
begin
  Result := TQuery.Create('Books');
  Result.Where(
    function(Q: IQuery): IQuery
    begin
      Result := Q.Where('Lang', 'de').OrWhere('Lang', 'en');
    end).WhereNotNull('PublishedAt');
end;
```

```sql
SELECT * FROM [Books]
WHERE ([Lang] = @p0 OR [Lang] = @p1) AND [PublishedAt] IS NOT NULL
```

### CTE

```pascal
function PublishedCte: IQuery;
begin
  Result := TQuery.Create('published');
  Result.&With('published',
    function(Q: IQuery): IQuery
    begin
      Result := Q.&From('Books').WhereTrue('IsPublished');
    end).Select('Title');
end;
```

```sql
WITH [published] AS (
  SELECT * FROM [Books] WHERE [IsPublished] = cast(1 as bit)
)
SELECT [Title] FROM [published]
```

### INSERT, UPDATE und DELETE

```pascal
function InsertUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.AsInsert(['Name', 'CountryId'], ['Jane', 1]);
end;

function UpdateUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.Where('Id', 1).AsUpdate(['Name', 'CountryId'], ['Jane', 2]);
end;

function DeleteUser: IQuery;
begin
  Result := TQuery.Create('Users');
  Result.Where('Id', 1).AsDelete;
end;
```

```sql
INSERT INTO [Users] ([Name], [CountryId]) VALUES (@p0, @p1)
UPDATE [Users] SET [Name] = @p0, [CountryId] = @p1 WHERE [Id] = @p2
DELETE FROM [Users] WHERE [Id] = @p0
```

Diese Methoden erzeugen Anweisungen; sie liefern keine betroffenen Datensätze
oder zurückgegebenen IDs. `AsInsert` mit `ReturnId=True` ergänzt bei den
Dialekten SQL Server, MySQL, PostgreSQL und SQLite die Anweisung aus der C#-Vorlage.

## API und Datentypen

Methodennamen orientieren sich an C#. Delphi-Schlüsselwörter erhalten ein `&`:
`&From`, `&As`, `&With`, `&For`, `&Or`, `&And`, `&Not`, `&Except`.
Mehrere Spalten oder Werte werden als Array übergeben, z. B.
`Select(['Id', 'Title'])` oder `WhereIn('Id', [1, 2, 3])`.
Für typisierte Arrays gibt es `TSqlValues.&Of<Integer>(Ids)`.

Parameter verwenden `TValue`. Zahlen, Strings und Boolean werden implizit
übernommen. SQL-NULL wird mit `TValue.Empty` oder `WhereNull` ausgedrückt.
Datumswerte lassen sich explizit mit `TValue.From<TDateTime>(Datum)` übergeben.
`TBytes` bleiben ein einzelner Binärparameter. Raw-Arrayparameter werden eine
Ebene aufgefaltet. `\?` schützt ein Fragezeichen in einem Raw-Ausdruck.

Vorhanden sind u. a. WHERE/HAVING mit OR/NOT, NULL, Boolean, IN, BETWEEN,
LIKE/Starts/Ends/Contains, Datumsteilen, verschachtelten Gruppen, Unterabfragen
und EXISTS; SELECT-Aggregate einschließlich Filter, GROUP BY, ORDER BY,
Joins, CTEs einschließlich Wertetabellen, UNION/EXCEPT/INTERSECT, Schreibabfragen,
Klonen, Variablen, `When` und enginebezogene `For…`-Callbacks.

Objektdaten werden über RTTI-lesbare Properties eingelesen. `[Column('Name')]`,
`[Key('Id')]` und `[Ignore]` entsprechen der C#-Vorlage; bei `AsUpdate` erzeugt
ein Key zusätzlich die WHERE-Bedingung. Dictionaries verwenden
`TDictionary<string,TValue>`; explizite Spaltenarrays geben die Reihenfolge vor.

Details zu Besitzverhältnissen, API-Grenzen und den ausdrücklich korrigierten
C#-Fehlern stehen in [docs/API.md](docs/API.md).

## SQL-Dialekte

| Factory (`Create` liefert `ICompiler`) | EngineCode | Parameter |
| --- | --- | --- |
| `TSqlServerCompiler` | `sqlsrv` | `@p0` |
| `TPostgresCompiler` | `postgres` | `@p0` |
| `TMySqlCompiler` | `mysql` | `@p0` |
| `TSqliteCompiler` | `sqlite` | `@p0` |
| `TOracleCompiler` | `oracle` | `:p0` |
| `TFirebirdCompiler` | `firebird` | `@p0` |

SQL Server und Oracle verwenden standardmäßig OFFSET/FETCH.
`UseLegacyPagination := True` aktiviert für SQL Server TOP/ROW_NUMBER bzw.
für Oracle ROWNUM. Firebird unterstützt FIRST/SKIP/ROWS.
Schreibabfragen mit Joins werden entsprechend der C#-Vorlage nur für
SQL Server und MySQL unterstützt; die übrigen Compiler weisen sie zurück.

## DUnitX ausführen

DUnitX wird nur für die Tests benötigt. Das Testprojekt verwendet die mit
Delphi gelieferte Quelle unter `$(BDS)\source\DUnitX`.

**IDE, einschließlich Community Edition:**

1. `test/QueryBuilder.Tests.dproj` öffnen.
2. Windows 32 Bit wählen und **Projekt → Erzeugen** (`Umschalt+F9`) ausführen.
3. Windows 64 Bit wählen und ebenfalls **Erzeugen** ausführen.
4. Im Repository `./tools/build.ps1 -TestsOnly` ausführen.

**Delphi-Ausgaben mit Kommandozeilen-Compiler:**

```powershell
./tools/build.ps1 -BdsRoot 'C:\Program Files (x86)\Embarcadero\Studio\23.0'
```

Einzelplattform: zusätzlich `-Platform Win32` oder `-Platform Win64`.
Ergebnisse liegen unter `build/Win32` und `build/Win64`:
Testprogramm, `tests.log` und NUnit-XML `results.xml`.
Der Testprozess liefert bei Fehlern einen von null verschiedenen Exitcode.

Die eingecheckte `test/golden.json` enthält Ausgaben der tatsächlichen
C#-Vorlage. Der SQL-Vergleich normalisiert Leerraum; Bindings werden in ihrer
Reihenfolge verglichen. Bekannte, bewusst korrigierte Vorlagefehler werden
separat gegen die korrigierte Ausgabe geprüft. Die Tests benötigen weder .NET
noch eine Datenbank. Details zum Prüfstand: [docs/VALIDATION.md](docs/VALIDATION.md).

Nur zum **Neuerzeugen** der Referenzdaten werden Python und ein .NET-SDK mit
.NET-8-Unterstützung benötigt:

```powershell
python tools/generate_oracle.py ../querybuilder
dotnet run --project tools/oracle/Oracle.csproj -- test/golden.json
```

Die generierten Fluent-Weiterleitungen lassen sich mit
`python tools/generate_query.py` erneut erzeugen. Semantikänderungen gehören in
die Pascal-Units und die zugehörigen Tests.

## Lizenz

MIT, einschließlich des Copyright-Hinweises der C#-Vorlage; siehe [LICENSE](LICENSE).
