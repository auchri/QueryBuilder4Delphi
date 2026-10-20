"""Generate repetitive Delphi fluent wrappers. Run from the repository root.

The semantic implementations live in src/SqlKata.Query.inc. This generator only
produces declarations and forwarding methods, keeping Where/Having symmetric.
"""
from pathlib import Path

decl, impl = [], []

def method(name, params, body, locals='', overload=False):
    if name == 'Except': name = '&Except'
    body = body.replace('Result := Except(', 'Result := &Except(')
    decl.append(f'    function {name}({params}): IQuery;'+(' overload;' if overload else ''))
    # default arguments belong only in the interface
    import re
    sig = re.sub(r' = (?:nil|True|False|\d+|\x27[^\x27]*\x27)', '', params)
    impl.append(f'function TQueryObject.{name}({sig}): IQuery;\n{locals}\nbegin\n{body}\nend;\n')

for component, root in [('where','Where'), ('having','Having')]:
    for prefix, flagor in [('',False),('Or',True)]:
        for neg in [False, True]:
            base = prefix+root+('Not' if neg else '')
            flags=f"'{component}', {str(flagor)}, {str(neg)}"
            def cond(name, params, kind, assignments, overload=False):
                before = "  if (Query = nil) or not Query.HasComponent('from') then raise EQueryException.Create('EXISTS requires a FROM clause');\n" if kind == 'ckExists' else ''
                method(name,params,before+f"  C := Condition({flags}, {kind});\n{assignments}\n  Result := Self;",'var C: TClause;',overload)
            cond(base,'const Column, Op: string; const Value: TValue','ckBasic','  C.Name := Column; C.Op := Op; C.Value := Value;',True)
            method(base,'const Column: string; const Value: TValue',f"  Result := {base}(Column, '=', Value);",overload=True)
            cond(base,'Group: IQuery','ckNested','  C.Query := Group.Clone;',True)
            method(base,'const Callback: TQueryCallback',f'  Q := CallbackQuery(Callback);\n  Result := {base}(Q);','var Q: IQuery;',True)
            cond(base,'const Column, Op: string; Query: IQuery','ckQuery','  C.Name := Column; C.Op := Op; C.Query := Query.Clone;',True)
            method(base,'const Column, Op: string; const Callback: TQueryCallback',f'  Q := CallbackQuery(Callback);\n  Result := {base}(Column, Op, Q);','var Q: IQuery;',True)
            cond(base+'Null','const Column: string','ckNull','  C.Name := Column;')
            for suffix,val in [('True','True'),('False','False')]:
                if not neg:
                    cond(base+suffix,'const Column: string','ckBoolean',f'  C.Name := Column; C.Value := {val};')
            cond(base+'Between','const Column: string; const Lower, Higher: TValue','ckBetween','  C.Name := Column; C.Value := Lower; C.Value2 := Higher;')
            cond(base+'In','const Column: string; const Values: array of TValue','ckIn','  C.Name := Column; C.Values := DistinctValues(Values);',True)
            cond(base+'In','const Column: string; Query: IQuery','ckInQuery','  C.Name := Column; C.Query := Query.Clone;',True)
            method(base+'In','const Column: string; const Callback: TQueryCallback',f'  Q := CallbackQuery(Callback);\n  Result := {base}In(Column, Q);','var Q: IQuery;',True)
            cond(base+'Exists','Query: IQuery','ckExists','  C.Query := Query.Clone;',True)
            method(base+'Exists','const Callback: TQueryCallback',f'  Q := CallbackQuery(Callback);\n  Result := {base}Exists(Q);','var Q: IQuery;',True)
            for suffix,op in [('Like','like'),('Starts','starts'),('Ends','ends'),('Contains','contains')]:
                cond(base+suffix,"const Column: string; const Value: TValue; const EscapeCharacter: string = ''",'ckString',f"  C.Name := Column; C.Value := Value; C.Op := '{op}'; C.Extra := EscapeCharacter;")
            for suffix,part in [('Date','date'),('Time','time')]:
                cond(base+suffix,'const Column, Op: string; const Value: TValue','ckDate',f"  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := '{part}';",True)
                method(base+suffix,'const Column: string; const Value: TValue',f"  Result := {base}{suffix}(Column, '=', Value);",overload=True)
            cond(base+'DatePart','const Part, Column, Op: string; const Value: TValue','ckDate','  C.Name := Column; C.Op := Op; C.Value := Value; C.Extra := Part;',True)
            method(base+'DatePart','const Part, Column: string; const Value: TValue',f"  Result := {base}DatePart(Part, Column, '=', Value);",overload=True)
        flags=f"'{component}', {str(flagor)}, False"
        for suffix,params,kind,assignments in [
            ('Raw','const Sql: string; const Bindings: array of TValue','ckRaw','  C.Name := Sql; C.Values := CopyValues(Bindings);'),
            ('Columns','const First, Op, Second: string','ckColumns','  C.Name := First; C.Op := Op; C.Extra := Second;')]:
            method(prefix+root+suffix,params,f'  C := Condition({flags}, {kind});\n{assignments}\n  Result := Self;','var C: TClause;',suffix=='Raw')
            if suffix=='Raw':
                method(prefix+root+suffix,'const Sql: string',f'  Result := {prefix}{root}Raw(Sql, []);',overload=True)
        method(prefix+root+'Sub','Query: IQuery; const Op: string; const Value: TValue',f'  C := Condition({flags}, ckSubQuery);\n  C.Query := Query.Clone; C.Op := Op; C.Value := Value;\n  Result := Self;','var C: TClause;',True)
        method(prefix+root+'Sub','Query: IQuery; const Value: TValue',f"  Result := {prefix}{root}Sub(Query, '=', Value);",overload=True)

for name,component in [('Select','select'),('GroupBy','group'),('OrderBy','order'),('OrderByDesc','order')]:
    method(name,'const Columns: array of string',f"  for S in Columns do\n    for E in ExpandExpression(S) do\n    begin\n      C := Add('{component}', ckIdentifier); C.Name := E; C.IsNot := {str(name=='OrderByDesc')};\n    end;\n"+("  Method := 'select';\n" if name=='Select' else '')+'  Result := Self;','var S, E: string; C: TClause;',True)
    method(name,'const Column: string',f'  Result := {name}([Column]);',overload=True)
for name,component in [('SelectRaw','select'),('FromRaw','from'),('OrderByRaw','order'),('GroupByRaw','group'),('CombineRaw','combine'),('UnionRaw','combine'),('ExceptRaw','combine'),('IntersectRaw','combine')]:
    before = "  Remove('from', EngineScope);\n" if component=='from' else ''
    if component == 'select': before += "  Method := 'select';\n"
    if component == 'combine': before += "  if Method <> 'select' then raise EQueryException.Create('Only select queries can be combined');\n"
    method(name,'const Sql: string; const Bindings: array of TValue',before+f"  C := Add('{component}', ckRaw); C.Name := Sql; C.Values := CopyValues(Bindings);\n  Result := Self;",'var C: TClause;',True)
    method(name,'const Sql: string',f'  Result := {name}(Sql, []);',overload=True)
for name,agg in [('AsCount','count'),('AsSum','sum'),('AsAvg','avg'),('AsAverage','avg'),('AsMin','min'),('AsMax','max')]:
    if name=='AsCount':
        method(name,"const Columns: array of string",f"  if Length(Columns) = 0 then Result := AsAggregate('{agg}', ['*'])\n  else Result := AsAggregate('{agg}', Columns);",overload=True)
        method(name,'',"  Result := AsCount([]);",overload=True)
    else: method(name,'const Column: string',f"  Result := AsAggregate('{agg}', [Column]);")
for name,agg in [('SelectSum','sum'),('SelectCount','count'),('SelectAvg','avg'),('SelectMin','min'),('SelectMax','max')]:
    method(name,'const Column: string; const Filter: TQueryCallback = nil',f"  Result := SelectAggregate('{agg}', Column, Filter);")
for name in ['Union','Except','Intersect']:
    method(name,'Query: IQuery; All: Boolean = False',f"  Result := Combine('{name.lower()}', All, Query);",overload=True)
    method(name,'const Callback: TQueryCallback; All: Boolean = False',f'  Q := CallbackQuery(Callback);\n  Result := {name}(Q, All);','var Q: IQuery;',True)
    method(name+'All','Query: IQuery',f'  Result := {name}(Query, True);',overload=True)
    method(name+'All','const Callback: TQueryCallback',f'  Result := {name}(Callback, True);',overload=True)
for name,engine in [('ForSqlServer','sqlsrv'),('ForPostgreSql','postgres'),('ForMySql','mysql'),('ForSqlite','sqlite'),('ForOracle','oracle'),('ForFirebird','firebird')]:
    method(name,'const Callback: TQueryCallback',f"  Result := &For('{engine}', Callback);")

Path('src/SqlKata.Fluent.Declarations.inc').write_text('\n'.join(decl)+'\n',encoding='utf-8',newline='\r\n')
Path('src/SqlKata.Fluent.Implementation.inc').write_text('\n'.join(impl),encoding='utf-8',newline='\r\n')

