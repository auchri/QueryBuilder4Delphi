# Prüfstand vom 20. Oktober 2026

## Tatsächlich ausgeführt

Delphi 12 Community Edition, RAD Studio-Verzeichnis `23.0`, Windows.
Die Suite wurde über **Projekt → Erzeugen** jeweils vollständig neu gebaut.
Beide endgültigen Builds meldeten **0 Fehler und 0 Warnungen**.
Das Kommandozeilen-Buildangebot der installierten Community Edition ist nicht
verfügbar; die Builds wurden deshalb in der IDE vorgenommen.

Anschließend wurden die beiden eigenständigen Testprogramme mit
`tools/build.ps1 -TestsOnly` ausgeführt.

| Ziel | DUnitX-Tests | Bestanden | Fehlgeschlagen | Fehler | Ignoriert |
| --- | ---: | ---: | ---: | ---: | ---: |
| Win32 | 570 | 570 | 0 | 0 | 0 |
| Win64 | 570 | 570 | 0 | 0 | 0 |

DUnitX meldete in beiden Läufen `Tests Leaked: 0`.
Zusätzlich ist `ReportMemoryLeaksOnShutdown` im Testprogramm aktiviert.
Die PE-Header der Testprogramme wurden als x86 (`0x14c`) bzw. x64 (`0x8664`)
geprüft. Die maschinenlesbare Zusammenfassung einschließlich SHA-256-Werten
steht in [validation-results.json](validation-results.json).
`tools/record_validation.py` kann diese Zusammenfassung aus neuen erfolgreichen
Testläufen erneut erstellen; das Prüfdatum im Skript ist bei einem neuen
Prüfstand entsprechend anzupassen.

## Referenzvergleich

Die C#-Ausgaben stammen unmittelbar aus der lokalen Vorlage mit Commit
`df4a2377750d34fc057c81886b481e7309ef975e`.
`tools/oracle` referenziert deren `QueryBuilder.csproj`; es enthält keinen
nachgebauten C#-Compiler. 69 gepaarte Abfragen werden für sechs Dialekte sowie
die beiden SQL-Server-/Oracle-Legacy-Varianten kompiliert: 552 Referenzergebnisse.
Ein erneuter C#-Lauf reproduzierte `test/golden.json` bytegleich.

540 Engine-/Szenariokombinationen prüfen das benannte SQL, RawSql sowie Anzahl,
Werte und Reihenfolge der Bindings gegen diese C#-Daten. Bei den in der Vorlage
abgelehnten JOIN-Schreiboperationen wird die Ablehnung geprüft.
Leerraum im SQL wird normalisiert.

Die zwölf ausdrücklich freigegebenen Abweichungen für HAVING-Callbacks und
Oracle-Aggregataliase haben eigene Tests mit explizit erwarteter korrigierter
Ausgabe; die ursprünglichen C#-Referenzen bleiben erhalten. Siehe [API.md](API.md).

Elf bestehende Zusatztests prüfen Besitzverhältnisse beim Klonen/Freigeben von
Unterabfragen, Exceptions in Callbacks und EngineScope-Wiederherstellung,
Datentypen und kulturunabhängiges Diagnose-SQL, Operatorprüfung,
ungültige Schreibdaten, Batch-Parameter, Variablen in Unterabfragen,
Raw-Arrayparameter, typisierte Arrays, RTTI-Attribute und README-Beispiele.

Sieben weitere Tests prüfen die referenzgezählte API mit Destruktorzählern:
geteilte Interfaces, automatische Freigabe von Query-Bäumen und Klonen,
temporäre Fluent-Ketten bei Exceptions, aufbewahrte Callback-Queries,
Callback-Fehler, vom SQL-Ergebnis gehaltene Queries sowie Compiler- und
Ergebnisfreigabe beim Verlassen eines Scopes durch eine Exception.
Alle README-Funktionen verwenden `IQuery`; das vollständige Beispiel kommt
ohne `try..finally` aus.

## Grenzen der Aussage

Geprüft wurden die SQL-Erzeugung und das Laufzeitverhalten der Bibliothek mit
Delphi 12 für Win32/Win64. Es wurden keine Datenbankserver angesprochen und
keine SqlKata.Execution-Funktionen portiert. Neuere Delphi-Versionen wurden
nicht lokal ausgeführt. Die Suite ist kein vollständiger Nachweis jedes
möglichen SQL-Fragments oder jeder Kombination von Fluent-Overloads.

Die ursprünglichen temporären Modell-Smoke-Projekte wurden durch das DUnitX-
Projekt ersetzt. Buildprodukte und ausführliche NUnit-Protokolle bleiben unter
`build/Win32` und `build/Win64` und werden nicht eingecheckt.
