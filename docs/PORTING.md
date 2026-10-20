# Portierungsplan

Vorlage: SqlKata, lokaler Commit df4a2377750d34fc057c81886b481e7309ef975e.
Ziel: Delphi 12 und neuer, Windows Win32/Win64. Keine Execution-Schicht.
Klassische Klassen; der Aufrufer gibt Query, Compiler und SqlResult frei.
Übergebene Unterabfragen werden kopiert. Callback-Abfragen werden intern freigegeben.

Arbeitspakete / Commits:
1. Projektstruktur, Lizenz, Build und Testgerüst.
2. Abfragemodell und Fluent API mit Bedingungen.
3. SELECT-Compiler, Joins, Unterabfragen, CTEs, Mengenoperationen.
4. Schreiboperationen und Aggregate.
5. Dialekte und Regressionstests gegen die C#-Vorlage.
6. README, ausführbare Beispiele, abschließende Win32-/Win64-Prüfung.

Sprachbedingte API-Unterschiede und verbleibende Lücken werden in docs/API.md geführt.
