# Portierungsplan

Vorlage: SqlKata, lokaler Commit df4a2377750d34fc057c81886b481e7309ef975e.
Ziel: Delphi 12 und neuer, Windows Win32/Win64. Keine Execution-Schicht.
Klassische Klassen; der Aufrufer gibt Query, Compiler und SqlResult frei.
Übergebene Unterabfragen werden kopiert. Callback-Abfragen werden intern freigegeben.

Abgeschlossene Arbeitspakete:
1. Projektstruktur, Lizenz und Portierungsplan (`5eac4fa`).
2. Abfragemodell und Fluent API mit Bedingungen und Besitzverwaltung (`802ed35`).
3. SQL-Compiler für SELECT, Joins, Unterabfragen, CTEs, Mengenoperationen,
   Schreiboperationen und Aggregate einschließlich aller sechs Dialekte (`3955bc5`).
4. DUnitX-Projekt, C#-Referenzdaten und Buildskript; 563 erfolgreiche Tests
   je Plattform unter Win32 und Win64, beide Builds ohne Warnungen.
5. README mit geprüften Beispielen, API-Zuordnung und dokumentiertem Prüfstand.

Sprachbedingte API-Unterschiede und Grenzen stehen in [API.md](API.md).
Der tatsächliche Prüfstand steht in [VALIDATION.md](VALIDATION.md).
Die vom Auftraggeber freigegebenen Korrekturen an HAVING-Callbacks und
Oracle-Aggregat-Aliasen sind dort getrennt von der C#-Parität dokumentiert.
