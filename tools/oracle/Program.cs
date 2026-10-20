using System.Globalization;
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
 ["all"]=()=>new Query("Books"),
 ["columns"]=()=>new Query("Books as b").Select("b.{Id,Title}", "b.AuthorId as Writer"),
 ["basic"]=()=>new Query("Books").Where("Id",145).Where("Lang","en"),
 ["bool"]=()=>new Query("Books").WhereTrue("Published").OrWhereFalse("Hidden"),
 ["boolvalue"]=()=>new Query("Books").Where("Published",true).Where("Hidden","!=",false),
 ["null"]=()=>new Query("Books").Where("Deleted",null).OrWhere("AuthorId","!=",(object)null),
 ["not"]=()=>new Query("Books").WhereNot("Id",1).OrWhereNot("Lang","de"),
 ["between"]=()=>new Query("Books").WhereBetween("Id",1,9).OrWhereNotBetween("Price",10,20),
 ["in"]=()=>new Query("Books").WhereIn("Lang",new[]{"de","en"}).WhereNotIn("Id",new[]{1,2}),
 ["induplicate"]=()=>new Query("Books").WhereIn("Id",new[]{1,1,2,2,3}),
 ["emptyin"]=()=>new Query("Books").WhereIn("Id",Array.Empty<int>()).OrWhereNotIn("Other",Array.Empty<int>()),
 ["strings"]=()=>new Query("Books").WhereLike("Title","A%").WhereNotContains("Title","SQL").OrWhereStarts("Title","Delphi").WhereEnds("Title","!","!"),
 ["columnscondition"]=()=>new Query("Books").WhereColumns("Created","<","Updated"),
 ["nested"]=()=>new Query("Books").Where(q=>q.Where("Id",1).OrWhere("Id",2)).WhereNot(q=>q.WhereNull("Title")),
 ["emptynested"]=()=>new Query("Books").Where(q=>q).Where("Id",3),
 ["raw"]=()=>new Query("Books").SelectRaw("coalesce([Price], ?) as [Amount]",10).WhereRaw("[Id] > ?",2).OrderByRaw("[Amount] + ?",3),
 ["escapedraw"]=()=>new Query("Books").WhereRaw(@"[Text] = ? AND [Other] = \?", "a"),
 ["group"]=()=>new Query("Books").Select("Category").SelectCount("Id as Count").GroupBy("Category").Having("Category","A").OrHavingNull("Category"),
 ["havingnested"]=()=>new Query("Books").GroupBy("Id").Having(q=>q.Where("Id",1).OrWhere("Id",2)),
 ["havingcallback"]=()=>new Query("Books").GroupBy("Id").Having(q=>q.Having("Id",1).OrHaving("Id",2)),
 ["filter"]=()=>new Query("Books").SelectCount("Id as Published",q=>q.WhereTrue("Published")),
 ["join"]=()=>new Query("Books").Join("Authors","Authors.Id","Books.AuthorId").Select("Books.*","Authors.Name as AuthorName"),
 ["joincallback"]=()=>new Query("Books").LeftJoin("Authors",j=>j.On("Authors.Id","Books.AuthorId").WhereTrue("Authors.Active")),
 ["cross"]=()=>new Query("Books").CrossJoin("Languages"),
 ["selectsub"]=()=>new Query("Books").Select(q=>q.From("Authors").Select("Name").WhereColumns("Authors.Id","=","Books.AuthorId"),"Author"),
 ["fromsub"]=()=>new Query().From(q=>q.From("Books").WhereTrue("Published"),"b").Where("b.Id",1),
 ["insub"]=()=>new Query("Books").WhereIn("AuthorId",q=>q.From("Authors").Select("Id").Where("Country","AT")),
 ["exists"]=()=>new Query("Books").WhereExists(q=>q.From("Authors").WhereColumns("Authors.Id","=","Books.AuthorId")),
 ["notexists"]=()=>new Query("Books").WhereNotExists(q=>q.From("Authors").Where("Active",true)),
 ["querycondition"]=()=>new Query("Books").Where("Price",">",q=>q.From("Books").AsAvg("Price")),
 ["cte"]=()=>new Query("published").With("published",q=>q.From("Books").WhereTrue("Published")).Where("Id",4),
 ["ctedependency"]=()=>new Query("a").With("a",q=>q.From("b").With("b",b=>b.From("Books").Where("Id",7))),
 ["cteraw"]=()=>new Query("x").WithRaw("x","SELECT ? AS [Id]",4),
 ["ctevalues"]=()=>new Query("x").With("x",new[]{"Id","Name"},new[]{new object[]{1,"A"},new object[]{2,"B"}}),
 ["union"]=()=>new Query("Books").Where("Lang","en").Union(q=>q.From("Books").Where("Lang","de")),
 ["intersect"]=()=>new Query("Books").Select("Id").IntersectAll(q=>q.From("Orders").Select("BookId")),
 ["except"]=()=>new Query("Books").Select("Id").Except(q=>q.From("Orders").Select("BookId")),
 ["limit"]=()=>new Query("Books").Limit(10),
 ["offset"]=()=>new Query("Books").Offset(20),
 ["page"]=()=>new Query("Books").OrderByDesc("Id").ForPage(3,10),
 ["limitoffset"]=()=>new Query("Books").Limit(10).Offset(20),
 ["distinct"]=()=>new Query("Books").Distinct().Select("Lang").Limit(5),
 ["random"]=()=>new Query("Books").OrderByRandom(42),
 ["date_date"]=()=>new Query("Books").WhereDatePart("date","Created",">=","2025-01-01"),
 ["date_time"]=()=>new Query("Books").WhereDatePart("time","Created",">=","13:14"),
 ["date_year"]=()=>new Query("Books").WhereDatePart("year","Created",">=",2025),
 ["date_month"]=()=>new Query("Books").WhereDatePart("month","Created",">=",10),
 ["date_day"]=()=>new Query("Books").WhereDatePart("day","Created",">=",20),
 ["date_hour"]=()=>new Query("Books").WhereDatePart("hour","Created",">=",13),
 ["date_minute"]=()=>new Query("Books").WhereDatePart("minute","Created",">=",14),
 ["date_second"]=()=>new Query("Books").WhereDatePart("second","Created",">=",15),
 ["datenot"]=()=>new Query("Books").WhereNotDate("Created","2025-01-01"),
 ["count"]=()=>new Query("Books").Where("Active",true).AsCount(),
 ["countdistinct"]=()=>new Query("Books").Where("Active",true).Distinct().AsCount(new[]{"Lang"}),
 ["countmulti"]=()=>new Query("Books").Where("Active",true).AsCount(new[]{"Id","Lang"}),
 ["sum"]=()=>new Query("Books").Where("Active",true).AsSum("Price"),
 ["insert"]=()=>new Query("Users").AsInsert(new[]{"Name","CountryId"},new object[]{"Jane",1}),
 ["insertmany"]=()=>new Query("Users").AsInsert(new[]{"Name","CountryId"},new[]{new object[]{"Jane",1},new object[]{"John",2}}),
 ["insertid"]=()=>new Query("Users").AsInsert(new Dictionary<string,object>{{"Name","Jane"}},true),
 ["update"]=()=>new Query("Users").Where("Id",1).AsUpdate(new[]{"Name","CountryId"},new object[]{"Jane",2}),
 ["increment"]=()=>new Query("Books").Where("Id",1).AsIncrement("Stock",2),
 ["decrement"]=()=>new Query("Books").AsDecrement("Stock",3),
 ["delete"]=()=>new Query("Users").Where("Id",1).AsDelete(),
 ["updatejoin"]=()=>new Query("Users as u").Join("Countries as c","c.Id","u.CountryId").Where("c.Name","AT").AsUpdate(new[]{"Active"},new object[]{true}),
 ["deletejoin"]=()=>new Query("Users as u").Join("Countries as c","c.Id","u.CountryId").AsDelete(),
 ["variable"]=()=>new Query("Books").Define("id",7).Where("Id",new Variable("id")),
 ["literal"]=()=>new Query("Books").Where("Created",new UnsafeLiteral("CURRENT_TIMESTAMP",false)),
 ["engine"]=()=>new Query("Books").ForSqlServer(q=>q.Where("Engine","MSSQL")).ForPostgreSql(q=>q.Where("Engine","PG")).Where("Id",1),
 ["when"]=()=>new Query("Books").When(false,q=>q.Where("Id",1),q=>q.Where("Id",2))};
var output = new List<object>();
foreach(var engine in engines)
 foreach(var scenario in cases) {
   try {
     var r = engine.Value.Compile(scenario.Value());
     output.Add(new {engine=engine.Key, name=scenario.Key, sql=r.Sql,
       raw=r.RawSql, bindings=r.Bindings.Select(v=>v==null?"<NULL>":Convert.ToString(v,CultureInfo.InvariantCulture)).ToArray()});
   } catch (Exception ex) { output.Add(new {engine=engine.Key,name=scenario.Key,error=ex.GetType().Name}); }
 }
File.WriteAllText(args[0],JsonSerializer.Serialize(output,new JsonSerializerOptions{WriteIndented=true}).Replace(Environment.NewLine, "\n"));
Console.WriteLine($"{output.Count} reference results generated");
