"""Generate paired C#/Delphi scenarios; run C# project to refresh golden.json.

Usage: python tools/generate_oracle.py [path-to-CSharp-querybuilder]
The C# repository is only needed to regenerate fixtures, never to run DUnitX.
"""
from pathlib import Path
import sys, json, os

source = Path(sys.argv[1] if len(sys.argv) > 1 else '../querybuilder').resolve()
cases = []
def case(name, cs, pas):
    cases.append((name, cs, pas))

case('all', 'new Query("Books")', "TQuery.Create('Books')")
case('columns', 'new Query("Books as b").Select("b.{Id,Title}", "b.AuthorId as Writer")', "TQuery.Create('Books as b').Select(['b.{Id,Title}', 'b.AuthorId as Writer'])")
case('basic', 'new Query("Books").Where("Id",145).Where("Lang","en")', "TQuery.Create('Books').Where('Id',145).Where('Lang','en')")
case('bool', 'new Query("Books").WhereTrue("Published").OrWhereFalse("Hidden")', "TQuery.Create('Books').WhereTrue('Published').OrWhereFalse('Hidden')")
case('boolvalue', 'new Query("Books").Where("Published",true).Where("Hidden","!=",false)', "TQuery.Create('Books').Where('Published',True).Where('Hidden','!=',False)")
case('null', 'new Query("Books").Where("Deleted",null).OrWhere("AuthorId","!=",(object)null)', "TQuery.Create('Books').Where('Deleted',TValue.Empty).OrWhere('AuthorId','!=',TValue.Empty)")
case('not', 'new Query("Books").WhereNot("Id",1).OrWhereNot("Lang","de")', "TQuery.Create('Books').WhereNot('Id',1).OrWhereNot('Lang','de')")
case('between', 'new Query("Books").WhereBetween("Id",1,9).OrWhereNotBetween("Price",10,20)', "TQuery.Create('Books').WhereBetween('Id',1,9).OrWhereNotBetween('Price',10,20)")
case('in', 'new Query("Books").WhereIn("Lang",new[]{"de","en"}).WhereNotIn("Id",new[]{1,2})', "TQuery.Create('Books').WhereIn('Lang',['de','en']).WhereNotIn('Id',[1,2])")
case('induplicate', 'new Query("Books").WhereIn("Id",new[]{1,1,2,2,3})', "TQuery.Create('Books').WhereIn('Id',[1,1,2,2,3])")
case('emptyin', 'new Query("Books").WhereIn("Id",Array.Empty<int>()).OrWhereNotIn("Other",Array.Empty<int>())', "TQuery.Create('Books').WhereIn('Id',[]).OrWhereNotIn('Other',[])")
case('strings', 'new Query("Books").WhereLike("Title","A%").WhereNotContains("Title","SQL").OrWhereStarts("Title","Delphi").WhereEnds("Title","!","!")', "TQuery.Create('Books').WhereLike('Title','A%').WhereNotContains('Title','SQL').OrWhereStarts('Title','Delphi').WhereEnds('Title','!','!')")
case('columnscondition','new Query("Books").WhereColumns("Created","<","Updated")', "TQuery.Create('Books').WhereColumns('Created','<','Updated')")
case('nested', 'new Query("Books").Where(q=>q.Where("Id",1).OrWhere("Id",2)).WhereNot(q=>q.WhereNull("Title"))', "TQuery.Create('Books').Where(function(Q:IQuery):IQuery begin Result:=Q.Where('Id',1).OrWhere('Id',2); end).WhereNot(function(Q:IQuery):IQuery begin Result:=Q.WhereNull('Title'); end)")
case('emptynested', 'new Query("Books").Where(q=>q).Where("Id",3)', "TQuery.Create('Books').Where(function(Q:IQuery):IQuery begin Result:=Q; end).Where('Id',3)")
case('raw', 'new Query("Books").SelectRaw("coalesce([Price], ?) as [Amount]",10).WhereRaw("[Id] > ?",2).OrderByRaw("[Amount] + ?",3)', "TQuery.Create('Books').SelectRaw('coalesce([Price], ?) as [Amount]',[10]).WhereRaw('[Id] > ?',[2]).OrderByRaw('[Amount] + ?',[3])")
case('escapedraw','new Query("Books").WhereRaw(@"[Text] = ? AND [Other] = \\?", "a")', "TQuery.Create('Books').WhereRaw('[Text] = ? AND [Other] = \\?',['a'])")
case('group', 'new Query("Books").Select("Category").SelectCount("Id as Count").GroupBy("Category").Having("Category","A").OrHavingNull("Category")', "TQuery.Create('Books').Select('Category').SelectCount('Id as Count').GroupBy('Category').Having('Category','A').OrHavingNull('Category')")
case('havingnested','new Query("Books").GroupBy("Id").Having(q=>q.Where("Id",1).OrWhere("Id",2))', "TQuery.Create('Books').GroupBy('Id').Having(function(Q:IQuery):IQuery begin Result:=Q.Where('Id',1).OrWhere('Id',2); end)")
case('havingcallback','new Query("Books").GroupBy("Id").Having(q=>q.Having("Id",1).OrHaving("Id",2))', "TQuery.Create('Books').GroupBy('Id').Having(function(Q:IQuery):IQuery begin Result:=Q.Having('Id',1).OrHaving('Id',2); end)")
case('filter', 'new Query("Books").SelectCount("Id as Published",q=>q.WhereTrue("Published"))', "TQuery.Create('Books').SelectCount('Id as Published',function(Q:IQuery):IQuery begin Result:=Q.WhereTrue('Published'); end)")
case('join','new Query("Books").Join("Authors","Authors.Id","Books.AuthorId").Select("Books.*","Authors.Name as AuthorName")', "TQuery.Create('Books').Join('Authors','Authors.Id','Books.AuthorId').Select(['Books.*','Authors.Name as AuthorName'])")
case('joincallback','new Query("Books").LeftJoin("Authors",j=>j.On("Authors.Id","Books.AuthorId").WhereTrue("Authors.Active"))', "TQuery.Create('Books').LeftJoin('Authors',function(Q:IQuery):IQuery begin Result:=Q.On('Authors.Id','Books.AuthorId').WhereTrue('Authors.Active'); end)")
case('cross','new Query("Books").CrossJoin("Languages")', "TQuery.Create('Books').CrossJoin('Languages')")
case('selectsub','new Query("Books").Select(q=>q.From("Authors").Select("Name").WhereColumns("Authors.Id","=","Books.AuthorId"),"Author")', "TQuery.Create('Books').Select(function(Q:IQuery):IQuery begin Result:=Q.&From('Authors').Select('Name').WhereColumns('Authors.Id','=','Books.AuthorId'); end,'Author')")
case('fromsub','new Query().From(q=>q.From("Books").WhereTrue("Published"),"b").Where("b.Id",1)', "TQuery.Create.&From(function(Q:IQuery):IQuery begin Result:=Q.&From('Books').WhereTrue('Published'); end,'b').Where('b.Id',1)")
case('insub','new Query("Books").WhereIn("AuthorId",q=>q.From("Authors").Select("Id").Where("Country","AT"))', "TQuery.Create('Books').WhereIn('AuthorId',function(Q:IQuery):IQuery begin Result:=Q.&From('Authors').Select('Id').Where('Country','AT'); end)")
case('exists','new Query("Books").WhereExists(q=>q.From("Authors").WhereColumns("Authors.Id","=","Books.AuthorId"))', "TQuery.Create('Books').WhereExists(function(Q:IQuery):IQuery begin Result:=Q.&From('Authors').WhereColumns('Authors.Id','=','Books.AuthorId'); end)")
case('notexists','new Query("Books").WhereNotExists(q=>q.From("Authors").Where("Active",true))', "TQuery.Create('Books').WhereNotExists(function(Q:IQuery):IQuery begin Result:=Q.&From('Authors').Where('Active',True); end)")
case('querycondition','new Query("Books").Where("Price",">",q=>q.From("Books").AsAvg("Price"))', "TQuery.Create('Books').Where('Price','>',function(Q:IQuery):IQuery begin Result:=Q.&From('Books').AsAvg('Price'); end)")
case('cte','new Query("published").With("published",q=>q.From("Books").WhereTrue("Published")).Where("Id",4)', "TQuery.Create('published').&With('published',function(Q:IQuery):IQuery begin Result:=Q.&From('Books').WhereTrue('Published'); end).Where('Id',4)")
case('ctedependency','new Query("a").With("a",q=>q.From("b").With("b",b=>b.From("Books").Where("Id",7)))', "TQuery.Create('a').&With('a',function(Q:IQuery):IQuery begin Result:=Q.&From('b').&With('b',function(B:IQuery):IQuery begin Result:=B.&From('Books').Where('Id',7); end); end)")
case('cteraw','new Query("x").WithRaw("x","SELECT ? AS [Id]",4)', "TQuery.Create('x').WithRaw('x','SELECT ? AS [Id]',[4])")
case('ctevalues','new Query("x").With("x",new[]{"Id","Name"},new[]{new object[]{1,"A"},new object[]{2,"B"}})', "TQuery.Create('x').&With('x',['Id','Name'],TRows.Create(TValues.Create(1,'A'),TValues.Create(2,'B')))")
case('union','new Query("Books").Where("Lang","en").Union(q=>q.From("Books").Where("Lang","de"))', "TQuery.Create('Books').Where('Lang','en').Union(function(Q:IQuery):IQuery begin Result:=Q.&From('Books').Where('Lang','de'); end)")
case('intersect','new Query("Books").Select("Id").IntersectAll(q=>q.From("Orders").Select("BookId"))', "TQuery.Create('Books').Select('Id').IntersectAll(function(Q:IQuery):IQuery begin Result:=Q.&From('Orders').Select('BookId'); end)")
case('except','new Query("Books").Select("Id").Except(q=>q.From("Orders").Select("BookId"))', "TQuery.Create('Books').Select('Id').&Except(function(Q:IQuery):IQuery begin Result:=Q.&From('Orders').Select('BookId'); end)")
for name,chain,pchain in [('limit','.Limit(10)', '.Limit(10)'),('offset','.Offset(20)', '.Offset(20)'),('page','.OrderByDesc("Id").ForPage(3,10)', ".OrderByDesc('Id').ForPage(3,10)"),('limitoffset','.Limit(10).Offset(20)', '.Limit(10).Offset(20)'),('distinct','.Distinct().Select("Lang").Limit(5)', ".Distinct.Select('Lang').Limit(5)"),('random','.OrderByRandom(42)', '.OrderByRandom(42)')]:
    case(name,'new Query("Books")'+chain,"TQuery.Create('Books')"+pchain)
for part,val in [('date','2025-01-01'),('time','13:14'),('year',2025),('month',10),('day',20),('hour',13),('minute',14),('second',15)]:
    cv = json.dumps(val); pv = str(val) if isinstance(val,int) else "'"+val+"'"
    case('date_'+part,f'new Query("Books").WhereDatePart("{part}","Created",">=",{cv})',f"TQuery.Create('Books').WhereDatePart('{part}','Created','>=',{pv})")
case('datenot','new Query("Books").WhereNotDate("Created","2025-01-01")', "TQuery.Create('Books').WhereNotDate('Created','2025-01-01')")
for name,cs,pas in [('count','.AsCount()', '.AsCount'),('countdistinct','.Distinct().AsCount(new[]{"Lang"})', ".Distinct.AsCount(['Lang'])"),('countmulti','.AsCount(new[]{"Id","Lang"})', ".AsCount(['Id','Lang'])"),('sum','.AsSum("Price")', ".AsSum('Price')")]:
    case(name,'new Query("Books").Where("Active",true)'+cs,"TQuery.Create('Books').Where('Active',True)"+pas)
case('insert','new Query("Users").AsInsert(new[]{"Name","CountryId"},new object[]{"Jane",1})', "TQuery.Create('Users').AsInsert(['Name','CountryId'],['Jane',1])")
case('insertmany','new Query("Users").AsInsert(new[]{"Name","CountryId"},new[]{new object[]{"Jane",1},new object[]{"John",2}})', "TQuery.Create('Users').AsInsert(['Name','CountryId'],TRows.Create(TValues.Create('Jane',1),TValues.Create('John',2)))")
case('insertid','new Query("Users").AsInsert(new Dictionary<string,object>{{"Name","Jane"}},true)', "TQuery.Create('Users').AsInsert([TPair<string,TValue>.Create('Name','Jane')],True)")
case('update','new Query("Users").Where("Id",1).AsUpdate(new[]{"Name","CountryId"},new object[]{"Jane",2})', "TQuery.Create('Users').Where('Id',1).AsUpdate(['Name','CountryId'],['Jane',2])")
case('increment','new Query("Books").Where("Id",1).AsIncrement("Stock",2)', "TQuery.Create('Books').Where('Id',1).AsIncrement('Stock',2)")
case('decrement','new Query("Books").AsDecrement("Stock",3)', "TQuery.Create('Books').AsDecrement('Stock',3)")
case('delete','new Query("Users").Where("Id",1).AsDelete()', "TQuery.Create('Users').Where('Id',1).AsDelete")
case('updatejoin','new Query("Users as u").Join("Countries as c","c.Id","u.CountryId").Where("c.Name","AT").AsUpdate(new[]{"Active"},new object[]{true})', "TQuery.Create('Users as u').Join('Countries as c','c.Id','u.CountryId').Where('c.Name','AT').AsUpdate(['Active'],[True])")
case('deletejoin','new Query("Users as u").Join("Countries as c","c.Id","u.CountryId").AsDelete()', "TQuery.Create('Users as u').Join('Countries as c','c.Id','u.CountryId').AsDelete")
case('variable','new Query("Books").Define("id",7).Where("Id",new Variable("id"))', "TQuery.Create('Books').Define('id',7).Where('Id',TVariable.Create('id'))")
case('literal','new Query("Books").Where("Created",new UnsafeLiteral("CURRENT_TIMESTAMP",false))', "TQuery.Create('Books').Where('Created',TUnsafeLiteral.Create('CURRENT_TIMESTAMP',False))")
case('engine','new Query("Books").ForSqlServer(q=>q.Where("Engine","MSSQL")).ForPostgreSql(q=>q.Where("Engine","PG")).Where("Id",1)', "TQuery.Create('Books').ForSqlServer(function(Q:IQuery):IQuery begin Result:=Q.Where('Engine','MSSQL'); end).ForPostgreSql(function(Q:IQuery):IQuery begin Result:=Q.Where('Engine','PG'); end).Where('Id',1)")
case('when','new Query("Books").When(false,q=>q.Where("Id",1),q=>q.Where("Id",2))', "TQuery.Create('Books').When(False,function(Q:IQuery):IQuery begin Result:=Q.Where('Id',1); end,function(Q:IQuery):IQuery begin Result:=Q.Where('Id',2); end)")

root = Path('tools/oracle'); root.mkdir(exist_ok=True)
(root/'Oracle.csproj').write_text(f'''<Project Sdk="Microsoft.NET.Sdk">
<PropertyGroup><OutputType>Exe</OutputType><TargetFramework>net8.0</TargetFramework><ImplicitUsings>enable</ImplicitUsings></PropertyGroup>
<ItemGroup><ProjectReference Include="{os.path.relpath(source / 'QueryBuilder/QueryBuilder.csproj',root)}" /></ItemGroup>
</Project>''',encoding='utf-8')
cs = '''using System.Globalization;
using System.Text.Json;
using SqlKata;
using SqlKata.Compilers;
using SqlKata.Extensions;
var engines = new Dictionary<string,Compiler> {
 ["sqlsrv"]=new SqlServerCompiler(), ["postgres"]=new PostgresCompiler(),
 ["mysql"]=new MySqlCompiler(), ["sqlite"]=new SqliteCompiler(),
 ["oracle"]=new OracleCompiler(), ["firebird"]=new FirebirdCompiler(),
 ["sqlsrv_legacy"]=new SqlServerCompiler{UseLegacyPagination=true},
 ["oracle_legacy"]=new OracleCompiler{UseLegacyPagination=true}};
var cases = new Dictionary<string,Func<Query>> {
'''
cs += ',\n'.join(f' ["{name}"]=()=>{expr}' for name,expr,_ in cases)
cs += '''};
var output = new List<object>();
foreach(var engine in engines)
 foreach(var scenario in cases) {
   try {
     var r = engine.Value.Compile(scenario.Value());
     output.Add(new {engine=engine.Key, name=scenario.Key, sql=r.Sql,
       raw=r.RawSql, bindings=r.Bindings.Select(v=>v==null?"<NULL>":Convert.ToString(v,CultureInfo.InvariantCulture)).ToArray()});
   } catch (Exception ex) { output.Add(new {engine=engine.Key,name=scenario.Key,error=ex.GetType().Name}); }
 }
File.WriteAllText(args[0],JsonSerializer.Serialize(output,new JsonSerializerOptions{WriteIndented=true}).Replace(Environment.NewLine, "\\n"));
Console.WriteLine($"{output.Count} reference results generated");
'''
(root/'Program.cs').write_text(cs,encoding='utf-8')
Path('test/Oracle.Scenarios.inc').write_text('\n'.join(f"  if Name = '{name}' then Exit({expr});" for name,_,expr in cases)+"\n  raise EQueryException.Create('Unknown scenario: '+Name);\n",encoding='utf-8',newline='\r\n')
# These 12 combinations have dedicated corrected-behavior tests. Keep their
# unmodified C# output in golden.json so the intentional differences are auditable.
def corrected(engine, name):
    return name == 'havingnested' or (engine.startswith('oracle') and name in ('group','filter'))
Path('test/Oracle.Cases.inc').write_text('\n'.join(f"    [TestCase('{engine}.{name}', '{engine},{name}')]" for engine in ['sqlsrv','postgres','mysql','sqlite','oracle','firebird','sqlsrv_legacy','oracle_legacy'] for name,_,_ in cases if not corrected(engine,name))+'\n',encoding='utf-8',newline='\r\n')
print(f'{len(cases)} paired scenarios generated')
