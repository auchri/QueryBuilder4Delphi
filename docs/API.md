# API-Zuordnung und Grenzen

## Öffentliche Fluent API

Die öffentlichen `Query`-Methodennamen der Vorlage sind auf `IQuery` vorhanden,
außer `Include` und `IncludeMany`: diese dienen der hier ausdrücklich
ausgeschlossenen Execution-/Relation-Loading-Schicht.

`Query` → `IQuery`, `Compiler` → `ICompiler`, `SqlResult` → `ISqlResult`.
`TQuery.Create` und `T…Compiler.Create` sind Record-Factories, die sofort ein
Interface liefern. Auch temporäre Fluent-Ketten benötigen kein manuelles Free.
Alle Compiler befinden sich in der Unit `SqlKata.Compilers`; das Modell in
`SqlKata`. Die sechs Compiler-Factories tragen jeweils das Delphi-Präfix `T`.
`EngineCodes` heißt `TEngineCodes`.

`object`-Parameter werden durch `TValue` ersetzt, `params`-/`IEnumerable`-
Parameter durch offene Arrays bzw. `TArray`. Für IN-Werte aus typisierten Arrays
wandelt `TSqlValues.&Of<T>` in `TValues` um. Mehrfachzeilen sind `TRows` mit
`TValues` pro Zeile. Wörterbücher sind `TDictionary<string,TValue>` bzw.
Arrays von `TPair<string,TValue>`. Es gibt keine C#-anonymen Datentypen;
Objektdaten verwenden RTTI-lesbare Delphi-Properties.

`TUnsafeLiteral` und `TVariable` sind Wertrecords mit impliziter Umwandlung in
`TValue`; sie brauchen kein `Free`. `TUnsafeLiteral.Create(SQL, False)` lässt
den SQL-Text unverändert. Die Hilfsklasse `Expressions` ist durch diese
Record-Konstruktoren ersetzt.

`TConditionGroup` und `TJoin` sind Aliase des gemeinsamen Fluent-Modells
`IQuery` (auch als `IConditionGroup` und `IJoin`). Die C#-internen
Clause-Unterklassen, Interfaces, getrennten
`Wheres`-/`Havings`-/Clause-Properties und die Visitor-/CompileContext-
Erweiterungsschnittstelle werden nicht binär oder typgleich nachgebildet.
Stattdessen existieren `TClause`, `Clauses`, `GetComponents`, `GetOne` und
`ClearComponent`; Komponenten sind `where`, `having`, `select`, `from`, `group`,
`order`, `join`, `cte`, `combine`, `limit`, `offset`, `aggregate`, `insert`,
`update`. Diese internen Listen gehören der Abfrage. Eigene Compiler können
die geschützten virtuellen Methoden von `TCompilerObject` bzw. den
dialektspezifischen
`T…CompilerObject`-Klassen überschreiben. Eigene Query-Implementierungen können
von `TQueryObject` ableiten und `NewQuery`/`Clone` überschreiben. Instanzen dieser
Implementierungsklassen immer als Interface halten; die Factories sind die
regulären Einstiegspunkte.

## Speicher und Lebensdauer

- `IQuery`, `ICompiler` und `ISqlResult` sind über `TInterfacedObject`
  referenzgezählt. Zuweisungen teilen dieselbe Instanz; `Clone` erzeugt eine
  unabhängige Abfrage. Scope-Ende oder `Q := nil` gibt eine Referenz frei.
  Niemals `Free`/`FreeAndNil` auf die Implementierungsobjekte anwenden.
- `ISqlResult.Query` hält beim Einzelaufruf von `Compile` die ursprüngliche
  Abfrage am Leben. Bei Batch-Ergebnissen ist `Query` wie bisher `nil`.
- `Clauses`, `Variables`, `Bindings` und `NamedBindings` sind geliehene
  RTL-Listen. Sie gehören ihrem Query bzw. Ergebnis und dürfen nicht separat
  freigegeben werden. Das zugehörige Interface muss bei ihrer Verwendung leben.
- Eingehende Query-Objekte werden kopiert. Der Aufrufer darf das Original
  nach dem Methodenaufruf verändern oder freigeben.
- Callback-Hilfsqueries werden intern erzeugt und kopiert; ihre Lebensdauer
  ist ebenfalls referenzgezählt. Ein gespeichertes Callback-Interface bleibt
  nach dem Callback gültig. Callbacks werden nicht im Query gespeichert.
  Callbacks müssen ihren übergebenen Query zurückgeben; fremde oder `nil`
  Rückgaben lösen eine Exception aus. `When` und `For` arbeiten direkt auf dem
  ursprünglichen Query und verlangen ebenfalls dessen Rückgabe.
- `TValue` hält skalare Werte, Records und referenzgezählte Daten gemäß RTL.
  Als Parameter eingepackte beliebige `TObject`-Instanzen werden nicht besessen.
- Query-Klone besitzen unabhängige Clauses und Unterabfragen. Vom Aufrufer
  eingebettete Referenzobjekte innerhalb eigener `TValue`-Daten werden nicht
  tief geklont.
- Wie bei allen referenzgezählten Interfaces müssen eigene Erweiterungen
  zyklische starke Referenzen vermeiden. Die eingebauten Query-Bäume besitzen
  keine Rückverweise; Unterabfragen werden geklont.
- Query-Instanzen und konfigurierbare Compiler sind keine synchronisierten
  gemeinsam veränderbaren Objekte. Separate Instanzen pro Thread verwenden.

## Bewusst korrigierte Vorlagefehler

Vom Auftraggeber ausdrücklich freigegeben:

1. `Having(function(Q: IQuery): IQuery begin Result := Q.Where(...); end)` erzeugt
   tatsächlich eine HAVING-Gruppe. Die C#-Vorlage prüft bei diesem Overload nur
   `query.Havings` und verwirft Bedingungen aus `query.Wheres`. Auch ein Callback
   mit `Q.Having(...)` funktioniert. Bei beiden Komponenten verwendet Delphi
   vorrangig die Where-Gruppe und bei deren Abwesenheit die Having-Gruppe.
2. `TOracleCompiler.Create.Compile(TQuery.Create.SelectCount('Id as Total'))`
   erzeugt `COUNT("Id") "Total"`. Die C#-Vorlage verliert bei der Aliaszerlegung das
   Schlüsselwort AS und setzt den Alias in den Aggregatausdruck:
   `COUNT("Id" "Total")`. Die Delphi-Korrektur gilt auch für gefilterte
   Aggregate und für den Oracle-Legacy-Modus.

Die unveränderten C#-Referenzen dieser Fälle bleiben in `test/golden.json`.
Die zwölf betroffenen Engine-/Szenariokombinationen werden durch explizite
Korrekturtests ersetzt, nicht stillschweigend an neue Referenzdaten angepasst.

## Weitere Unterschiede durch Delphi und Lebensdauer

- `For` stellt einen vorherigen EngineScope auch bei Exceptions wieder her.
- `Clone` erhält den Kommentar. Die aktuelle C#-Vorlage kopiert ihn nicht.
- Batch-Kompilierung leerer Arrays liefert ein leeres Ergebnis.
- Raw-Bindings müssen zur Anzahl ungeschützter `?` passen; Abweichungen werden
  frühzeitig mit `EQueryException` gemeldet.
- Operatoren werden gegen die Whitelist geprüft. Aggregatnamen und Datumsteile
  müssen einfache SQL-Funktions-/Teilnamen sein. Dialektspezifische Namen wie
  `quarter` sind möglich; Raw-Ausdrücke sind für freie SQL-Fragmente vorhanden.
- Die kompakte Modellimplementierung gibt keine Zusage zur Reihenfolge von
  RTTI-Properties oder Dictionary-Einträgen. Explizite Spalten-/Wertearrays
  legen die Reihenfolge fest.
- Im kompilierten SQL kann sich die Formatierung des Leerraums unterscheiden.
  Im Paritätsvergleich werden ausschließlich diese Leerraumunterschiede
  normalisiert. Es werden keine Datenbankserver angesprochen.

`Comment`/`GetComment` dienen wie in der lokalen C#-Compilerfassung der
Modellmetadatenverwaltung; der Kommentar wird nicht in SQL eingefügt.
