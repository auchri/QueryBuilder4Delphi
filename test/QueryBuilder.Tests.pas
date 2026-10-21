unit QueryBuilder.Tests;

interface

uses System.SysUtils, System.Rtti, System.JSON, System.Generics.Collections,
  DUnitX.TestFramework, QueryBuilder4Delphi.Query.Core, QueryBuilder4Delphi.Query, QueryBuilder4Delphi.Compilers.Compiler,
  QueryBuilder4Delphi.Compilers.SqlServerCompiler,
  QueryBuilder4Delphi.Compilers.PostgresCompiler,
  QueryBuilder4Delphi.Compilers.MySqlCompiler,
  QueryBuilder4Delphi.Compilers.SqliteCompiler,
  QueryBuilder4Delphi.Compilers.OracleCompiler,
  QueryBuilder4Delphi.Compilers.FirebirdCompiler;

type
  [TestFixture]
  TQueryBuilderTests = class
  private
    FGolden: TJSONArray;
    function Build(const Name: string): IQuery;
    function Compiler(const Engine: string): ICompiler;
  public
    [SetupFixture] procedure LoadReference;
    [TearDownFixture] procedure FreeReference;
    // BEGIN GENERATED: reference cases
    [TestCase('sqlsrv.all', 'sqlsrv,all')]
    [TestCase('sqlsrv.columns', 'sqlsrv,columns')]
    [TestCase('sqlsrv.basic', 'sqlsrv,basic')]
    [TestCase('sqlsrv.bool', 'sqlsrv,bool')]
    [TestCase('sqlsrv.boolvalue', 'sqlsrv,boolvalue')]
    [TestCase('sqlsrv.null', 'sqlsrv,null')]
    [TestCase('sqlsrv.not', 'sqlsrv,not')]
    [TestCase('sqlsrv.between', 'sqlsrv,between')]
    [TestCase('sqlsrv.in', 'sqlsrv,in')]
    [TestCase('sqlsrv.induplicate', 'sqlsrv,induplicate')]
    [TestCase('sqlsrv.emptyin', 'sqlsrv,emptyin')]
    [TestCase('sqlsrv.strings', 'sqlsrv,strings')]
    [TestCase('sqlsrv.columnscondition', 'sqlsrv,columnscondition')]
    [TestCase('sqlsrv.nested', 'sqlsrv,nested')]
    [TestCase('sqlsrv.emptynested', 'sqlsrv,emptynested')]
    [TestCase('sqlsrv.raw', 'sqlsrv,raw')]
    [TestCase('sqlsrv.escapedraw', 'sqlsrv,escapedraw')]
    [TestCase('sqlsrv.group', 'sqlsrv,group')]
    [TestCase('sqlsrv.havingcallback', 'sqlsrv,havingcallback')]
    [TestCase('sqlsrv.filter', 'sqlsrv,filter')]
    [TestCase('sqlsrv.join', 'sqlsrv,join')]
    [TestCase('sqlsrv.joincallback', 'sqlsrv,joincallback')]
    [TestCase('sqlsrv.cross', 'sqlsrv,cross')]
    [TestCase('sqlsrv.selectsub', 'sqlsrv,selectsub')]
    [TestCase('sqlsrv.fromsub', 'sqlsrv,fromsub')]
    [TestCase('sqlsrv.insub', 'sqlsrv,insub')]
    [TestCase('sqlsrv.exists', 'sqlsrv,exists')]
    [TestCase('sqlsrv.notexists', 'sqlsrv,notexists')]
    [TestCase('sqlsrv.querycondition', 'sqlsrv,querycondition')]
    [TestCase('sqlsrv.cte', 'sqlsrv,cte')]
    [TestCase('sqlsrv.ctedependency', 'sqlsrv,ctedependency')]
    [TestCase('sqlsrv.cteraw', 'sqlsrv,cteraw')]
    [TestCase('sqlsrv.ctevalues', 'sqlsrv,ctevalues')]
    [TestCase('sqlsrv.union', 'sqlsrv,union')]
    [TestCase('sqlsrv.intersect', 'sqlsrv,intersect')]
    [TestCase('sqlsrv.except', 'sqlsrv,except')]
    [TestCase('sqlsrv.limit', 'sqlsrv,limit')]
    [TestCase('sqlsrv.offset', 'sqlsrv,offset')]
    [TestCase('sqlsrv.page', 'sqlsrv,page')]
    [TestCase('sqlsrv.limitoffset', 'sqlsrv,limitoffset')]
    [TestCase('sqlsrv.distinct', 'sqlsrv,distinct')]
    [TestCase('sqlsrv.random', 'sqlsrv,random')]
    [TestCase('sqlsrv.date_date', 'sqlsrv,date_date')]
    [TestCase('sqlsrv.date_time', 'sqlsrv,date_time')]
    [TestCase('sqlsrv.date_year', 'sqlsrv,date_year')]
    [TestCase('sqlsrv.date_month', 'sqlsrv,date_month')]
    [TestCase('sqlsrv.date_day', 'sqlsrv,date_day')]
    [TestCase('sqlsrv.date_hour', 'sqlsrv,date_hour')]
    [TestCase('sqlsrv.date_minute', 'sqlsrv,date_minute')]
    [TestCase('sqlsrv.date_second', 'sqlsrv,date_second')]
    [TestCase('sqlsrv.datenot', 'sqlsrv,datenot')]
    [TestCase('sqlsrv.count', 'sqlsrv,count')]
    [TestCase('sqlsrv.countdistinct', 'sqlsrv,countdistinct')]
    [TestCase('sqlsrv.countmulti', 'sqlsrv,countmulti')]
    [TestCase('sqlsrv.sum', 'sqlsrv,sum')]
    [TestCase('sqlsrv.insert', 'sqlsrv,insert')]
    [TestCase('sqlsrv.insertmany', 'sqlsrv,insertmany')]
    [TestCase('sqlsrv.insertid', 'sqlsrv,insertid')]
    [TestCase('sqlsrv.update', 'sqlsrv,update')]
    [TestCase('sqlsrv.increment', 'sqlsrv,increment')]
    [TestCase('sqlsrv.decrement', 'sqlsrv,decrement')]
    [TestCase('sqlsrv.delete', 'sqlsrv,delete')]
    [TestCase('sqlsrv.updatejoin', 'sqlsrv,updatejoin')]
    [TestCase('sqlsrv.deletejoin', 'sqlsrv,deletejoin')]
    [TestCase('sqlsrv.variable', 'sqlsrv,variable')]
    [TestCase('sqlsrv.literal', 'sqlsrv,literal')]
    [TestCase('sqlsrv.engine', 'sqlsrv,engine')]
    [TestCase('sqlsrv.when', 'sqlsrv,when')]
    [TestCase('postgres.all', 'postgres,all')]
    [TestCase('postgres.columns', 'postgres,columns')]
    [TestCase('postgres.basic', 'postgres,basic')]
    [TestCase('postgres.bool', 'postgres,bool')]
    [TestCase('postgres.boolvalue', 'postgres,boolvalue')]
    [TestCase('postgres.null', 'postgres,null')]
    [TestCase('postgres.not', 'postgres,not')]
    [TestCase('postgres.between', 'postgres,between')]
    [TestCase('postgres.in', 'postgres,in')]
    [TestCase('postgres.induplicate', 'postgres,induplicate')]
    [TestCase('postgres.emptyin', 'postgres,emptyin')]
    [TestCase('postgres.strings', 'postgres,strings')]
    [TestCase('postgres.columnscondition', 'postgres,columnscondition')]
    [TestCase('postgres.nested', 'postgres,nested')]
    [TestCase('postgres.emptynested', 'postgres,emptynested')]
    [TestCase('postgres.raw', 'postgres,raw')]
    [TestCase('postgres.escapedraw', 'postgres,escapedraw')]
    [TestCase('postgres.group', 'postgres,group')]
    [TestCase('postgres.havingcallback', 'postgres,havingcallback')]
    [TestCase('postgres.filter', 'postgres,filter')]
    [TestCase('postgres.join', 'postgres,join')]
    [TestCase('postgres.joincallback', 'postgres,joincallback')]
    [TestCase('postgres.cross', 'postgres,cross')]
    [TestCase('postgres.selectsub', 'postgres,selectsub')]
    [TestCase('postgres.fromsub', 'postgres,fromsub')]
    [TestCase('postgres.insub', 'postgres,insub')]
    [TestCase('postgres.exists', 'postgres,exists')]
    [TestCase('postgres.notexists', 'postgres,notexists')]
    [TestCase('postgres.querycondition', 'postgres,querycondition')]
    [TestCase('postgres.cte', 'postgres,cte')]
    [TestCase('postgres.ctedependency', 'postgres,ctedependency')]
    [TestCase('postgres.cteraw', 'postgres,cteraw')]
    [TestCase('postgres.ctevalues', 'postgres,ctevalues')]
    [TestCase('postgres.union', 'postgres,union')]
    [TestCase('postgres.intersect', 'postgres,intersect')]
    [TestCase('postgres.except', 'postgres,except')]
    [TestCase('postgres.limit', 'postgres,limit')]
    [TestCase('postgres.offset', 'postgres,offset')]
    [TestCase('postgres.page', 'postgres,page')]
    [TestCase('postgres.limitoffset', 'postgres,limitoffset')]
    [TestCase('postgres.distinct', 'postgres,distinct')]
    [TestCase('postgres.random', 'postgres,random')]
    [TestCase('postgres.date_date', 'postgres,date_date')]
    [TestCase('postgres.date_time', 'postgres,date_time')]
    [TestCase('postgres.date_year', 'postgres,date_year')]
    [TestCase('postgres.date_month', 'postgres,date_month')]
    [TestCase('postgres.date_day', 'postgres,date_day')]
    [TestCase('postgres.date_hour', 'postgres,date_hour')]
    [TestCase('postgres.date_minute', 'postgres,date_minute')]
    [TestCase('postgres.date_second', 'postgres,date_second')]
    [TestCase('postgres.datenot', 'postgres,datenot')]
    [TestCase('postgres.count', 'postgres,count')]
    [TestCase('postgres.countdistinct', 'postgres,countdistinct')]
    [TestCase('postgres.countmulti', 'postgres,countmulti')]
    [TestCase('postgres.sum', 'postgres,sum')]
    [TestCase('postgres.insert', 'postgres,insert')]
    [TestCase('postgres.insertmany', 'postgres,insertmany')]
    [TestCase('postgres.insertid', 'postgres,insertid')]
    [TestCase('postgres.update', 'postgres,update')]
    [TestCase('postgres.increment', 'postgres,increment')]
    [TestCase('postgres.decrement', 'postgres,decrement')]
    [TestCase('postgres.delete', 'postgres,delete')]
    [TestCase('postgres.updatejoin', 'postgres,updatejoin')]
    [TestCase('postgres.deletejoin', 'postgres,deletejoin')]
    [TestCase('postgres.variable', 'postgres,variable')]
    [TestCase('postgres.literal', 'postgres,literal')]
    [TestCase('postgres.engine', 'postgres,engine')]
    [TestCase('postgres.when', 'postgres,when')]
    [TestCase('mysql.all', 'mysql,all')]
    [TestCase('mysql.columns', 'mysql,columns')]
    [TestCase('mysql.basic', 'mysql,basic')]
    [TestCase('mysql.bool', 'mysql,bool')]
    [TestCase('mysql.boolvalue', 'mysql,boolvalue')]
    [TestCase('mysql.null', 'mysql,null')]
    [TestCase('mysql.not', 'mysql,not')]
    [TestCase('mysql.between', 'mysql,between')]
    [TestCase('mysql.in', 'mysql,in')]
    [TestCase('mysql.induplicate', 'mysql,induplicate')]
    [TestCase('mysql.emptyin', 'mysql,emptyin')]
    [TestCase('mysql.strings', 'mysql,strings')]
    [TestCase('mysql.columnscondition', 'mysql,columnscondition')]
    [TestCase('mysql.nested', 'mysql,nested')]
    [TestCase('mysql.emptynested', 'mysql,emptynested')]
    [TestCase('mysql.raw', 'mysql,raw')]
    [TestCase('mysql.escapedraw', 'mysql,escapedraw')]
    [TestCase('mysql.group', 'mysql,group')]
    [TestCase('mysql.havingcallback', 'mysql,havingcallback')]
    [TestCase('mysql.filter', 'mysql,filter')]
    [TestCase('mysql.join', 'mysql,join')]
    [TestCase('mysql.joincallback', 'mysql,joincallback')]
    [TestCase('mysql.cross', 'mysql,cross')]
    [TestCase('mysql.selectsub', 'mysql,selectsub')]
    [TestCase('mysql.fromsub', 'mysql,fromsub')]
    [TestCase('mysql.insub', 'mysql,insub')]
    [TestCase('mysql.exists', 'mysql,exists')]
    [TestCase('mysql.notexists', 'mysql,notexists')]
    [TestCase('mysql.querycondition', 'mysql,querycondition')]
    [TestCase('mysql.cte', 'mysql,cte')]
    [TestCase('mysql.ctedependency', 'mysql,ctedependency')]
    [TestCase('mysql.cteraw', 'mysql,cteraw')]
    [TestCase('mysql.ctevalues', 'mysql,ctevalues')]
    [TestCase('mysql.union', 'mysql,union')]
    [TestCase('mysql.intersect', 'mysql,intersect')]
    [TestCase('mysql.except', 'mysql,except')]
    [TestCase('mysql.limit', 'mysql,limit')]
    [TestCase('mysql.offset', 'mysql,offset')]
    [TestCase('mysql.page', 'mysql,page')]
    [TestCase('mysql.limitoffset', 'mysql,limitoffset')]
    [TestCase('mysql.distinct', 'mysql,distinct')]
    [TestCase('mysql.random', 'mysql,random')]
    [TestCase('mysql.date_date', 'mysql,date_date')]
    [TestCase('mysql.date_time', 'mysql,date_time')]
    [TestCase('mysql.date_year', 'mysql,date_year')]
    [TestCase('mysql.date_month', 'mysql,date_month')]
    [TestCase('mysql.date_day', 'mysql,date_day')]
    [TestCase('mysql.date_hour', 'mysql,date_hour')]
    [TestCase('mysql.date_minute', 'mysql,date_minute')]
    [TestCase('mysql.date_second', 'mysql,date_second')]
    [TestCase('mysql.datenot', 'mysql,datenot')]
    [TestCase('mysql.count', 'mysql,count')]
    [TestCase('mysql.countdistinct', 'mysql,countdistinct')]
    [TestCase('mysql.countmulti', 'mysql,countmulti')]
    [TestCase('mysql.sum', 'mysql,sum')]
    [TestCase('mysql.insert', 'mysql,insert')]
    [TestCase('mysql.insertmany', 'mysql,insertmany')]
    [TestCase('mysql.insertid', 'mysql,insertid')]
    [TestCase('mysql.update', 'mysql,update')]
    [TestCase('mysql.increment', 'mysql,increment')]
    [TestCase('mysql.decrement', 'mysql,decrement')]
    [TestCase('mysql.delete', 'mysql,delete')]
    [TestCase('mysql.updatejoin', 'mysql,updatejoin')]
    [TestCase('mysql.deletejoin', 'mysql,deletejoin')]
    [TestCase('mysql.variable', 'mysql,variable')]
    [TestCase('mysql.literal', 'mysql,literal')]
    [TestCase('mysql.engine', 'mysql,engine')]
    [TestCase('mysql.when', 'mysql,when')]
    [TestCase('sqlite.all', 'sqlite,all')]
    [TestCase('sqlite.columns', 'sqlite,columns')]
    [TestCase('sqlite.basic', 'sqlite,basic')]
    [TestCase('sqlite.bool', 'sqlite,bool')]
    [TestCase('sqlite.boolvalue', 'sqlite,boolvalue')]
    [TestCase('sqlite.null', 'sqlite,null')]
    [TestCase('sqlite.not', 'sqlite,not')]
    [TestCase('sqlite.between', 'sqlite,between')]
    [TestCase('sqlite.in', 'sqlite,in')]
    [TestCase('sqlite.induplicate', 'sqlite,induplicate')]
    [TestCase('sqlite.emptyin', 'sqlite,emptyin')]
    [TestCase('sqlite.strings', 'sqlite,strings')]
    [TestCase('sqlite.columnscondition', 'sqlite,columnscondition')]
    [TestCase('sqlite.nested', 'sqlite,nested')]
    [TestCase('sqlite.emptynested', 'sqlite,emptynested')]
    [TestCase('sqlite.raw', 'sqlite,raw')]
    [TestCase('sqlite.escapedraw', 'sqlite,escapedraw')]
    [TestCase('sqlite.group', 'sqlite,group')]
    [TestCase('sqlite.havingcallback', 'sqlite,havingcallback')]
    [TestCase('sqlite.filter', 'sqlite,filter')]
    [TestCase('sqlite.join', 'sqlite,join')]
    [TestCase('sqlite.joincallback', 'sqlite,joincallback')]
    [TestCase('sqlite.cross', 'sqlite,cross')]
    [TestCase('sqlite.selectsub', 'sqlite,selectsub')]
    [TestCase('sqlite.fromsub', 'sqlite,fromsub')]
    [TestCase('sqlite.insub', 'sqlite,insub')]
    [TestCase('sqlite.exists', 'sqlite,exists')]
    [TestCase('sqlite.notexists', 'sqlite,notexists')]
    [TestCase('sqlite.querycondition', 'sqlite,querycondition')]
    [TestCase('sqlite.cte', 'sqlite,cte')]
    [TestCase('sqlite.ctedependency', 'sqlite,ctedependency')]
    [TestCase('sqlite.cteraw', 'sqlite,cteraw')]
    [TestCase('sqlite.ctevalues', 'sqlite,ctevalues')]
    [TestCase('sqlite.union', 'sqlite,union')]
    [TestCase('sqlite.intersect', 'sqlite,intersect')]
    [TestCase('sqlite.except', 'sqlite,except')]
    [TestCase('sqlite.limit', 'sqlite,limit')]
    [TestCase('sqlite.offset', 'sqlite,offset')]
    [TestCase('sqlite.page', 'sqlite,page')]
    [TestCase('sqlite.limitoffset', 'sqlite,limitoffset')]
    [TestCase('sqlite.distinct', 'sqlite,distinct')]
    [TestCase('sqlite.random', 'sqlite,random')]
    [TestCase('sqlite.date_date', 'sqlite,date_date')]
    [TestCase('sqlite.date_time', 'sqlite,date_time')]
    [TestCase('sqlite.date_year', 'sqlite,date_year')]
    [TestCase('sqlite.date_month', 'sqlite,date_month')]
    [TestCase('sqlite.date_day', 'sqlite,date_day')]
    [TestCase('sqlite.date_hour', 'sqlite,date_hour')]
    [TestCase('sqlite.date_minute', 'sqlite,date_minute')]
    [TestCase('sqlite.date_second', 'sqlite,date_second')]
    [TestCase('sqlite.datenot', 'sqlite,datenot')]
    [TestCase('sqlite.count', 'sqlite,count')]
    [TestCase('sqlite.countdistinct', 'sqlite,countdistinct')]
    [TestCase('sqlite.countmulti', 'sqlite,countmulti')]
    [TestCase('sqlite.sum', 'sqlite,sum')]
    [TestCase('sqlite.insert', 'sqlite,insert')]
    [TestCase('sqlite.insertmany', 'sqlite,insertmany')]
    [TestCase('sqlite.insertid', 'sqlite,insertid')]
    [TestCase('sqlite.update', 'sqlite,update')]
    [TestCase('sqlite.increment', 'sqlite,increment')]
    [TestCase('sqlite.decrement', 'sqlite,decrement')]
    [TestCase('sqlite.delete', 'sqlite,delete')]
    [TestCase('sqlite.updatejoin', 'sqlite,updatejoin')]
    [TestCase('sqlite.deletejoin', 'sqlite,deletejoin')]
    [TestCase('sqlite.variable', 'sqlite,variable')]
    [TestCase('sqlite.literal', 'sqlite,literal')]
    [TestCase('sqlite.engine', 'sqlite,engine')]
    [TestCase('sqlite.when', 'sqlite,when')]
    [TestCase('oracle.all', 'oracle,all')]
    [TestCase('oracle.columns', 'oracle,columns')]
    [TestCase('oracle.basic', 'oracle,basic')]
    [TestCase('oracle.bool', 'oracle,bool')]
    [TestCase('oracle.boolvalue', 'oracle,boolvalue')]
    [TestCase('oracle.null', 'oracle,null')]
    [TestCase('oracle.not', 'oracle,not')]
    [TestCase('oracle.between', 'oracle,between')]
    [TestCase('oracle.in', 'oracle,in')]
    [TestCase('oracle.induplicate', 'oracle,induplicate')]
    [TestCase('oracle.emptyin', 'oracle,emptyin')]
    [TestCase('oracle.strings', 'oracle,strings')]
    [TestCase('oracle.columnscondition', 'oracle,columnscondition')]
    [TestCase('oracle.nested', 'oracle,nested')]
    [TestCase('oracle.emptynested', 'oracle,emptynested')]
    [TestCase('oracle.raw', 'oracle,raw')]
    [TestCase('oracle.escapedraw', 'oracle,escapedraw')]
    [TestCase('oracle.havingcallback', 'oracle,havingcallback')]
    [TestCase('oracle.join', 'oracle,join')]
    [TestCase('oracle.joincallback', 'oracle,joincallback')]
    [TestCase('oracle.cross', 'oracle,cross')]
    [TestCase('oracle.selectsub', 'oracle,selectsub')]
    [TestCase('oracle.fromsub', 'oracle,fromsub')]
    [TestCase('oracle.insub', 'oracle,insub')]
    [TestCase('oracle.exists', 'oracle,exists')]
    [TestCase('oracle.notexists', 'oracle,notexists')]
    [TestCase('oracle.querycondition', 'oracle,querycondition')]
    [TestCase('oracle.cte', 'oracle,cte')]
    [TestCase('oracle.ctedependency', 'oracle,ctedependency')]
    [TestCase('oracle.cteraw', 'oracle,cteraw')]
    [TestCase('oracle.ctevalues', 'oracle,ctevalues')]
    [TestCase('oracle.union', 'oracle,union')]
    [TestCase('oracle.intersect', 'oracle,intersect')]
    [TestCase('oracle.except', 'oracle,except')]
    [TestCase('oracle.limit', 'oracle,limit')]
    [TestCase('oracle.offset', 'oracle,offset')]
    [TestCase('oracle.page', 'oracle,page')]
    [TestCase('oracle.limitoffset', 'oracle,limitoffset')]
    [TestCase('oracle.distinct', 'oracle,distinct')]
    [TestCase('oracle.random', 'oracle,random')]
    [TestCase('oracle.date_date', 'oracle,date_date')]
    [TestCase('oracle.date_time', 'oracle,date_time')]
    [TestCase('oracle.date_year', 'oracle,date_year')]
    [TestCase('oracle.date_month', 'oracle,date_month')]
    [TestCase('oracle.date_day', 'oracle,date_day')]
    [TestCase('oracle.date_hour', 'oracle,date_hour')]
    [TestCase('oracle.date_minute', 'oracle,date_minute')]
    [TestCase('oracle.date_second', 'oracle,date_second')]
    [TestCase('oracle.datenot', 'oracle,datenot')]
    [TestCase('oracle.count', 'oracle,count')]
    [TestCase('oracle.countdistinct', 'oracle,countdistinct')]
    [TestCase('oracle.countmulti', 'oracle,countmulti')]
    [TestCase('oracle.sum', 'oracle,sum')]
    [TestCase('oracle.insert', 'oracle,insert')]
    [TestCase('oracle.insertmany', 'oracle,insertmany')]
    [TestCase('oracle.insertid', 'oracle,insertid')]
    [TestCase('oracle.update', 'oracle,update')]
    [TestCase('oracle.increment', 'oracle,increment')]
    [TestCase('oracle.decrement', 'oracle,decrement')]
    [TestCase('oracle.delete', 'oracle,delete')]
    [TestCase('oracle.updatejoin', 'oracle,updatejoin')]
    [TestCase('oracle.deletejoin', 'oracle,deletejoin')]
    [TestCase('oracle.variable', 'oracle,variable')]
    [TestCase('oracle.literal', 'oracle,literal')]
    [TestCase('oracle.engine', 'oracle,engine')]
    [TestCase('oracle.when', 'oracle,when')]
    [TestCase('firebird.all', 'firebird,all')]
    [TestCase('firebird.columns', 'firebird,columns')]
    [TestCase('firebird.basic', 'firebird,basic')]
    [TestCase('firebird.bool', 'firebird,bool')]
    [TestCase('firebird.boolvalue', 'firebird,boolvalue')]
    [TestCase('firebird.null', 'firebird,null')]
    [TestCase('firebird.not', 'firebird,not')]
    [TestCase('firebird.between', 'firebird,between')]
    [TestCase('firebird.in', 'firebird,in')]
    [TestCase('firebird.induplicate', 'firebird,induplicate')]
    [TestCase('firebird.emptyin', 'firebird,emptyin')]
    [TestCase('firebird.strings', 'firebird,strings')]
    [TestCase('firebird.columnscondition', 'firebird,columnscondition')]
    [TestCase('firebird.nested', 'firebird,nested')]
    [TestCase('firebird.emptynested', 'firebird,emptynested')]
    [TestCase('firebird.raw', 'firebird,raw')]
    [TestCase('firebird.escapedraw', 'firebird,escapedraw')]
    [TestCase('firebird.group', 'firebird,group')]
    [TestCase('firebird.havingcallback', 'firebird,havingcallback')]
    [TestCase('firebird.filter', 'firebird,filter')]
    [TestCase('firebird.join', 'firebird,join')]
    [TestCase('firebird.joincallback', 'firebird,joincallback')]
    [TestCase('firebird.cross', 'firebird,cross')]
    [TestCase('firebird.selectsub', 'firebird,selectsub')]
    [TestCase('firebird.fromsub', 'firebird,fromsub')]
    [TestCase('firebird.insub', 'firebird,insub')]
    [TestCase('firebird.exists', 'firebird,exists')]
    [TestCase('firebird.notexists', 'firebird,notexists')]
    [TestCase('firebird.querycondition', 'firebird,querycondition')]
    [TestCase('firebird.cte', 'firebird,cte')]
    [TestCase('firebird.ctedependency', 'firebird,ctedependency')]
    [TestCase('firebird.cteraw', 'firebird,cteraw')]
    [TestCase('firebird.ctevalues', 'firebird,ctevalues')]
    [TestCase('firebird.union', 'firebird,union')]
    [TestCase('firebird.intersect', 'firebird,intersect')]
    [TestCase('firebird.except', 'firebird,except')]
    [TestCase('firebird.limit', 'firebird,limit')]
    [TestCase('firebird.offset', 'firebird,offset')]
    [TestCase('firebird.page', 'firebird,page')]
    [TestCase('firebird.limitoffset', 'firebird,limitoffset')]
    [TestCase('firebird.distinct', 'firebird,distinct')]
    [TestCase('firebird.random', 'firebird,random')]
    [TestCase('firebird.date_date', 'firebird,date_date')]
    [TestCase('firebird.date_time', 'firebird,date_time')]
    [TestCase('firebird.date_year', 'firebird,date_year')]
    [TestCase('firebird.date_month', 'firebird,date_month')]
    [TestCase('firebird.date_day', 'firebird,date_day')]
    [TestCase('firebird.date_hour', 'firebird,date_hour')]
    [TestCase('firebird.date_minute', 'firebird,date_minute')]
    [TestCase('firebird.date_second', 'firebird,date_second')]
    [TestCase('firebird.datenot', 'firebird,datenot')]
    [TestCase('firebird.count', 'firebird,count')]
    [TestCase('firebird.countdistinct', 'firebird,countdistinct')]
    [TestCase('firebird.countmulti', 'firebird,countmulti')]
    [TestCase('firebird.sum', 'firebird,sum')]
    [TestCase('firebird.insert', 'firebird,insert')]
    [TestCase('firebird.insertmany', 'firebird,insertmany')]
    [TestCase('firebird.insertid', 'firebird,insertid')]
    [TestCase('firebird.update', 'firebird,update')]
    [TestCase('firebird.increment', 'firebird,increment')]
    [TestCase('firebird.decrement', 'firebird,decrement')]
    [TestCase('firebird.delete', 'firebird,delete')]
    [TestCase('firebird.updatejoin', 'firebird,updatejoin')]
    [TestCase('firebird.deletejoin', 'firebird,deletejoin')]
    [TestCase('firebird.variable', 'firebird,variable')]
    [TestCase('firebird.literal', 'firebird,literal')]
    [TestCase('firebird.engine', 'firebird,engine')]
    [TestCase('firebird.when', 'firebird,when')]
    [TestCase('sqlsrv_legacy.all', 'sqlsrv_legacy,all')]
    [TestCase('sqlsrv_legacy.columns', 'sqlsrv_legacy,columns')]
    [TestCase('sqlsrv_legacy.basic', 'sqlsrv_legacy,basic')]
    [TestCase('sqlsrv_legacy.bool', 'sqlsrv_legacy,bool')]
    [TestCase('sqlsrv_legacy.boolvalue', 'sqlsrv_legacy,boolvalue')]
    [TestCase('sqlsrv_legacy.null', 'sqlsrv_legacy,null')]
    [TestCase('sqlsrv_legacy.not', 'sqlsrv_legacy,not')]
    [TestCase('sqlsrv_legacy.between', 'sqlsrv_legacy,between')]
    [TestCase('sqlsrv_legacy.in', 'sqlsrv_legacy,in')]
    [TestCase('sqlsrv_legacy.induplicate', 'sqlsrv_legacy,induplicate')]
    [TestCase('sqlsrv_legacy.emptyin', 'sqlsrv_legacy,emptyin')]
    [TestCase('sqlsrv_legacy.strings', 'sqlsrv_legacy,strings')]
    [TestCase('sqlsrv_legacy.columnscondition', 'sqlsrv_legacy,columnscondition')]
    [TestCase('sqlsrv_legacy.nested', 'sqlsrv_legacy,nested')]
    [TestCase('sqlsrv_legacy.emptynested', 'sqlsrv_legacy,emptynested')]
    [TestCase('sqlsrv_legacy.raw', 'sqlsrv_legacy,raw')]
    [TestCase('sqlsrv_legacy.escapedraw', 'sqlsrv_legacy,escapedraw')]
    [TestCase('sqlsrv_legacy.group', 'sqlsrv_legacy,group')]
    [TestCase('sqlsrv_legacy.havingcallback', 'sqlsrv_legacy,havingcallback')]
    [TestCase('sqlsrv_legacy.filter', 'sqlsrv_legacy,filter')]
    [TestCase('sqlsrv_legacy.join', 'sqlsrv_legacy,join')]
    [TestCase('sqlsrv_legacy.joincallback', 'sqlsrv_legacy,joincallback')]
    [TestCase('sqlsrv_legacy.cross', 'sqlsrv_legacy,cross')]
    [TestCase('sqlsrv_legacy.selectsub', 'sqlsrv_legacy,selectsub')]
    [TestCase('sqlsrv_legacy.fromsub', 'sqlsrv_legacy,fromsub')]
    [TestCase('sqlsrv_legacy.insub', 'sqlsrv_legacy,insub')]
    [TestCase('sqlsrv_legacy.exists', 'sqlsrv_legacy,exists')]
    [TestCase('sqlsrv_legacy.notexists', 'sqlsrv_legacy,notexists')]
    [TestCase('sqlsrv_legacy.querycondition', 'sqlsrv_legacy,querycondition')]
    [TestCase('sqlsrv_legacy.cte', 'sqlsrv_legacy,cte')]
    [TestCase('sqlsrv_legacy.ctedependency', 'sqlsrv_legacy,ctedependency')]
    [TestCase('sqlsrv_legacy.cteraw', 'sqlsrv_legacy,cteraw')]
    [TestCase('sqlsrv_legacy.ctevalues', 'sqlsrv_legacy,ctevalues')]
    [TestCase('sqlsrv_legacy.union', 'sqlsrv_legacy,union')]
    [TestCase('sqlsrv_legacy.intersect', 'sqlsrv_legacy,intersect')]
    [TestCase('sqlsrv_legacy.except', 'sqlsrv_legacy,except')]
    [TestCase('sqlsrv_legacy.limit', 'sqlsrv_legacy,limit')]
    [TestCase('sqlsrv_legacy.offset', 'sqlsrv_legacy,offset')]
    [TestCase('sqlsrv_legacy.page', 'sqlsrv_legacy,page')]
    [TestCase('sqlsrv_legacy.limitoffset', 'sqlsrv_legacy,limitoffset')]
    [TestCase('sqlsrv_legacy.distinct', 'sqlsrv_legacy,distinct')]
    [TestCase('sqlsrv_legacy.random', 'sqlsrv_legacy,random')]
    [TestCase('sqlsrv_legacy.date_date', 'sqlsrv_legacy,date_date')]
    [TestCase('sqlsrv_legacy.date_time', 'sqlsrv_legacy,date_time')]
    [TestCase('sqlsrv_legacy.date_year', 'sqlsrv_legacy,date_year')]
    [TestCase('sqlsrv_legacy.date_month', 'sqlsrv_legacy,date_month')]
    [TestCase('sqlsrv_legacy.date_day', 'sqlsrv_legacy,date_day')]
    [TestCase('sqlsrv_legacy.date_hour', 'sqlsrv_legacy,date_hour')]
    [TestCase('sqlsrv_legacy.date_minute', 'sqlsrv_legacy,date_minute')]
    [TestCase('sqlsrv_legacy.date_second', 'sqlsrv_legacy,date_second')]
    [TestCase('sqlsrv_legacy.datenot', 'sqlsrv_legacy,datenot')]
    [TestCase('sqlsrv_legacy.count', 'sqlsrv_legacy,count')]
    [TestCase('sqlsrv_legacy.countdistinct', 'sqlsrv_legacy,countdistinct')]
    [TestCase('sqlsrv_legacy.countmulti', 'sqlsrv_legacy,countmulti')]
    [TestCase('sqlsrv_legacy.sum', 'sqlsrv_legacy,sum')]
    [TestCase('sqlsrv_legacy.insert', 'sqlsrv_legacy,insert')]
    [TestCase('sqlsrv_legacy.insertmany', 'sqlsrv_legacy,insertmany')]
    [TestCase('sqlsrv_legacy.insertid', 'sqlsrv_legacy,insertid')]
    [TestCase('sqlsrv_legacy.update', 'sqlsrv_legacy,update')]
    [TestCase('sqlsrv_legacy.increment', 'sqlsrv_legacy,increment')]
    [TestCase('sqlsrv_legacy.decrement', 'sqlsrv_legacy,decrement')]
    [TestCase('sqlsrv_legacy.delete', 'sqlsrv_legacy,delete')]
    [TestCase('sqlsrv_legacy.updatejoin', 'sqlsrv_legacy,updatejoin')]
    [TestCase('sqlsrv_legacy.deletejoin', 'sqlsrv_legacy,deletejoin')]
    [TestCase('sqlsrv_legacy.variable', 'sqlsrv_legacy,variable')]
    [TestCase('sqlsrv_legacy.literal', 'sqlsrv_legacy,literal')]
    [TestCase('sqlsrv_legacy.engine', 'sqlsrv_legacy,engine')]
    [TestCase('sqlsrv_legacy.when', 'sqlsrv_legacy,when')]
    [TestCase('oracle_legacy.all', 'oracle_legacy,all')]
    [TestCase('oracle_legacy.columns', 'oracle_legacy,columns')]
    [TestCase('oracle_legacy.basic', 'oracle_legacy,basic')]
    [TestCase('oracle_legacy.bool', 'oracle_legacy,bool')]
    [TestCase('oracle_legacy.boolvalue', 'oracle_legacy,boolvalue')]
    [TestCase('oracle_legacy.null', 'oracle_legacy,null')]
    [TestCase('oracle_legacy.not', 'oracle_legacy,not')]
    [TestCase('oracle_legacy.between', 'oracle_legacy,between')]
    [TestCase('oracle_legacy.in', 'oracle_legacy,in')]
    [TestCase('oracle_legacy.induplicate', 'oracle_legacy,induplicate')]
    [TestCase('oracle_legacy.emptyin', 'oracle_legacy,emptyin')]
    [TestCase('oracle_legacy.strings', 'oracle_legacy,strings')]
    [TestCase('oracle_legacy.columnscondition', 'oracle_legacy,columnscondition')]
    [TestCase('oracle_legacy.nested', 'oracle_legacy,nested')]
    [TestCase('oracle_legacy.emptynested', 'oracle_legacy,emptynested')]
    [TestCase('oracle_legacy.raw', 'oracle_legacy,raw')]
    [TestCase('oracle_legacy.escapedraw', 'oracle_legacy,escapedraw')]
    [TestCase('oracle_legacy.havingcallback', 'oracle_legacy,havingcallback')]
    [TestCase('oracle_legacy.join', 'oracle_legacy,join')]
    [TestCase('oracle_legacy.joincallback', 'oracle_legacy,joincallback')]
    [TestCase('oracle_legacy.cross', 'oracle_legacy,cross')]
    [TestCase('oracle_legacy.selectsub', 'oracle_legacy,selectsub')]
    [TestCase('oracle_legacy.fromsub', 'oracle_legacy,fromsub')]
    [TestCase('oracle_legacy.insub', 'oracle_legacy,insub')]
    [TestCase('oracle_legacy.exists', 'oracle_legacy,exists')]
    [TestCase('oracle_legacy.notexists', 'oracle_legacy,notexists')]
    [TestCase('oracle_legacy.querycondition', 'oracle_legacy,querycondition')]
    [TestCase('oracle_legacy.cte', 'oracle_legacy,cte')]
    [TestCase('oracle_legacy.ctedependency', 'oracle_legacy,ctedependency')]
    [TestCase('oracle_legacy.cteraw', 'oracle_legacy,cteraw')]
    [TestCase('oracle_legacy.ctevalues', 'oracle_legacy,ctevalues')]
    [TestCase('oracle_legacy.union', 'oracle_legacy,union')]
    [TestCase('oracle_legacy.intersect', 'oracle_legacy,intersect')]
    [TestCase('oracle_legacy.except', 'oracle_legacy,except')]
    [TestCase('oracle_legacy.limit', 'oracle_legacy,limit')]
    [TestCase('oracle_legacy.offset', 'oracle_legacy,offset')]
    [TestCase('oracle_legacy.page', 'oracle_legacy,page')]
    [TestCase('oracle_legacy.limitoffset', 'oracle_legacy,limitoffset')]
    [TestCase('oracle_legacy.distinct', 'oracle_legacy,distinct')]
    [TestCase('oracle_legacy.random', 'oracle_legacy,random')]
    [TestCase('oracle_legacy.date_date', 'oracle_legacy,date_date')]
    [TestCase('oracle_legacy.date_time', 'oracle_legacy,date_time')]
    [TestCase('oracle_legacy.date_year', 'oracle_legacy,date_year')]
    [TestCase('oracle_legacy.date_month', 'oracle_legacy,date_month')]
    [TestCase('oracle_legacy.date_day', 'oracle_legacy,date_day')]
    [TestCase('oracle_legacy.date_hour', 'oracle_legacy,date_hour')]
    [TestCase('oracle_legacy.date_minute', 'oracle_legacy,date_minute')]
    [TestCase('oracle_legacy.date_second', 'oracle_legacy,date_second')]
    [TestCase('oracle_legacy.datenot', 'oracle_legacy,datenot')]
    [TestCase('oracle_legacy.count', 'oracle_legacy,count')]
    [TestCase('oracle_legacy.countdistinct', 'oracle_legacy,countdistinct')]
    [TestCase('oracle_legacy.countmulti', 'oracle_legacy,countmulti')]
    [TestCase('oracle_legacy.sum', 'oracle_legacy,sum')]
    [TestCase('oracle_legacy.insert', 'oracle_legacy,insert')]
    [TestCase('oracle_legacy.insertmany', 'oracle_legacy,insertmany')]
    [TestCase('oracle_legacy.insertid', 'oracle_legacy,insertid')]
    [TestCase('oracle_legacy.update', 'oracle_legacy,update')]
    [TestCase('oracle_legacy.increment', 'oracle_legacy,increment')]
    [TestCase('oracle_legacy.decrement', 'oracle_legacy,decrement')]
    [TestCase('oracle_legacy.delete', 'oracle_legacy,delete')]
    [TestCase('oracle_legacy.updatejoin', 'oracle_legacy,updatejoin')]
    [TestCase('oracle_legacy.deletejoin', 'oracle_legacy,deletejoin')]
    [TestCase('oracle_legacy.variable', 'oracle_legacy,variable')]
    [TestCase('oracle_legacy.literal', 'oracle_legacy,literal')]
    [TestCase('oracle_legacy.engine', 'oracle_legacy,engine')]
    [TestCase('oracle_legacy.when', 'oracle_legacy,when')]
    // END GENERATED: reference cases
    procedure MatchesCSharp(const Engine, Name: string);
    [Test] procedure CloneAndSubqueryOwnership;
    [Test] procedure CallbackExceptionAndScopeRestoration;
    [Test] procedure ParameterTypesAndInvariantDebugSql;
    [Test] procedure RejectsUnsafeOperator;
    [Test] procedure InvalidWritesDoNotReplaceValidData;
    [Test] procedure BatchParameterNumbering;
    [Test] procedure NestedVariableResolution;
    [Test] procedure RawArrayExpansion;
    [Test] procedure ReadmeExamplesProduceDocumentedSql;
    [Test] procedure TypedArraysAndEmptyGroups;
    [Test] procedure RttiMappingHonorsColumnKeyAndIgnore;
    [Test] procedure SharedInterfacesKeepQueryAlive;
    [Test] procedure ScopeExitReleasesQueryTrees;
    [Test] procedure TemporaryFluentChainsReleaseOnFailure;
    [Test] procedure CallbackQueryCanBeRetained;
    [Test] procedure CallbackFailuresReleaseQueries;
    [Test] procedure SqlResultRetainsOriginalQuery;
    [Test] procedure CompilerAndResultReleaseAtScopeExit;
    [TestCase('sqlsrv','sqlsrv')]
    [TestCase('postgres','postgres')]
    [TestCase('mysql','mysql')]
    [TestCase('sqlite','sqlite')]
    [TestCase('oracle','oracle')]
    [TestCase('firebird','firebird')]
    [TestCase('sqlsrv_legacy','sqlsrv_legacy')]
    [TestCase('oracle_legacy','oracle_legacy')]
    procedure CorrectedHavingCallback(const Engine: string);
    [TestCase('OracleGroup','oracle,group')]
    [TestCase('OracleFilter','oracle,filter')]
    [TestCase('OracleLegacyGroup','oracle_legacy,group')]
    [TestCase('OracleLegacyFilter','oracle_legacy,filter')]
    procedure CorrectedOracleAggregateAlias(const Engine, Name: string);
  end;

implementation

uses System.IOUtils, System.RegularExpressions, System.TypInfo, ReadmeExamples, Oracle.Scenarios;

type
  TUserData = class
  private
    FId: Integer;
    FName, FInternal: string;
  public
    [QueryBuilder4Delphi.Query.Core.Key('UserId')]
    property Id: Integer read FId write FId;
    [QueryBuilder4Delphi.Query.Core.Column('DisplayName')]
    property Name: string read FName write FName;
    [QueryBuilder4Delphi.Query.Core.Ignore]
    property Internal: string read FInternal write FInternal;
  end;

var
  LiveQueries, LiveCompilers, LiveResults: Integer;

type
  TTrackedQuery = class(TQueryObject)
  public
    constructor Create;
    destructor Destroy; override;
    function NewQuery: IQuery; override;
  end;
  TTrackedCompiler = class(TCompiler)
  public
    constructor CreateInstance; override;
    destructor Destroy; override;
  end;
  TTrackedResult = class(TSqlResult)
  public
    constructor Create;
    destructor Destroy; override;
  end;

constructor TTrackedQuery.Create;
begin Inc(LiveQueries); inherited Create; end;
destructor TTrackedQuery.Destroy;
begin Dec(LiveQueries); inherited; end;
function TTrackedQuery.NewQuery: IQuery;
begin Result := TTrackedQuery.Create; end;
constructor TTrackedCompiler.CreateInstance;
begin Inc(LiveCompilers); inherited; end;
destructor TTrackedCompiler.Destroy;
begin Dec(LiveCompilers); inherited; end;
constructor TTrackedResult.Create;
begin Inc(LiveResults); inherited; end;
destructor TTrackedResult.Destroy;
begin Dec(LiveResults); inherited; end;

function TrackedQuery: IQuery;
begin Result := TTrackedQuery.Create; end;
function TrackedCompiler: ICompiler;
begin Result := TTrackedCompiler.Create; end;

procedure TQueryBuilderTests.SharedInterfacesKeepQueryAlive;
  procedure Exercise;
  var Q, Alias: IQuery;
  begin
    Q := TrackedQuery;
    Alias := Q;
    Q := nil;
    Assert.AreEqual(1,LiveQueries);
    Alias.&From('Books').Where('Id',1);
    Assert.IsTrue(Alias.HasConditions);
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries);
end;

procedure TQueryBuilderTests.ScopeExitReleasesQueryTrees;
  procedure Exercise;
  var Q, Clone: IQuery;
  begin
    Q := TrackedQuery.&From('Books')
      .WhereIn('AuthorId',TrackedQuery.&From('Authors').Select('Id'))
      .Join('Countries',function(J:IQuery):IQuery
        begin Result := J.On('Countries.Id','Books.CountryId'); end)
      .&With('published',TrackedQuery.&From('Books').WhereTrue('Published'));
    Clone := Q.Clone;
    Assert.IsTrue(LiveQueries > 2);
    Assert.IsTrue(Clone.HasComponent('join'));
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries,'Query trees and independent clones must be released');
end;

procedure TQueryBuilderTests.TemporaryFluentChainsReleaseOnFailure;
  procedure Exercise;
  begin
    TrackedQuery.&From('Books').Where('Id',1).Select('Title');
    Assert.WillRaise(procedure begin
      TrackedCompiler.Compile(TrackedQuery.&From('Books').Where('Id','unsafe operator',1));
    end,EQueryException);
    Assert.WillRaise(procedure begin
      TrackedQuery.&From('Books').AsInsert(['Id','Title'],[1]);
    end,EQueryException);
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries);
  Assert.AreEqual(0,LiveCompilers);
end;

procedure TQueryBuilderTests.CallbackQueryCanBeRetained;
  procedure Exercise;
  var Q, Saved: IQuery;
  begin
    Q := TrackedQuery.&From('Books');
    Q.Where(function(Child:IQuery):IQuery
      begin Saved := Child; Result := Child.Where('Id',1); end);
    Q := nil;
    Assert.IsTrue(Saved.HasConditions);
    Assert.AreEqual('SELECT * WHERE "Id" = @p0',TCompiler.Create.Compile(Saved).Sql);
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries);
end;

procedure TQueryBuilderTests.CallbackFailuresReleaseQueries;
  procedure Exercise;
  begin
    Assert.WillRaise(procedure begin
      TrackedQuery.Where(function(Child:IQuery):IQuery
        begin raise EQueryException.Create('callback failure'); end);
    end,EQueryException);
    Assert.WillRaise(procedure begin
      TrackedQuery.Where(function(Child:IQuery):IQuery
        begin Result := TrackedQuery; end);
    end,EQueryException);
    Assert.WillRaise(procedure begin
      TrackedQuery.When(True,function(Child:IQuery):IQuery
        begin Result := nil; end);
    end,EQueryException);
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries);
end;

procedure TQueryBuilderTests.SqlResultRetainsOriginalQuery;
  procedure Exercise;
  var R: ISqlResult;
    function CompileTemporary: ISqlResult;
    begin Result := TCompiler.Create.Compile(TrackedQuery.&From('Books').Where('Id',7)); end;
  begin
    R := CompileTemporary;
    Assert.AreEqual(1,LiveQueries);
    Assert.IsTrue(R.Query.HasConditions);
    Assert.AreEqual(7,R.Bindings[0].AsInteger);
    Assert.AreEqual('SELECT * FROM "Books" WHERE "Id" = 7',R.ToString);
  end;
begin
  Exercise;
  Assert.AreEqual(0,LiveQueries);
end;

procedure TQueryBuilderTests.CompilerAndResultReleaseAtScopeExit;
var Raised: Boolean;
  procedure Exercise;
  var C: ICompiler; R: ISqlResult;
  begin
    C := TrackedCompiler.Whitelist(['@>']);
    R := TTrackedResult.Create;
    R.Query := TrackedQuery;
    Assert.AreEqual(1,LiveQueries);
    Assert.AreEqual(1,LiveCompilers);
    Assert.AreEqual(1,LiveResults);
    Assert.AreEqual('generic',C.EngineCode);
    raise EQueryException.Create('scope failure');
  end;
begin
  Raised := False;
  try Exercise; except on E: EQueryException do Raised := True; end;
  Assert.IsTrue(Raised);
  Assert.AreEqual(0,LiveQueries);
  Assert.AreEqual(0,LiveCompilers);
  Assert.AreEqual(0,LiveResults);
end;

function Normalize(const S: string): string;
begin Result := TRegEx.Replace(S, '\s+', ' ').Trim; end;
function TQueryBuilderTests.Build(const Name: string): IQuery;
begin
  Result := BuildOracleQuery(Name);
end;
function TQueryBuilderTests.Compiler(const Engine: string): ICompiler;
begin
  if Engine.StartsWith('sqlsrv') then Result := TSqlServerCompiler.Create
  else if Engine.StartsWith('oracle') then Result := TOracleCompiler.Create
  else if Engine = 'postgres' then Result := TPostgresCompiler.Create
  else if Engine = 'mysql' then Result := TMySqlCompiler.Create
  else if Engine = 'sqlite' then Result := TSqliteCompiler.Create
  else if Engine = 'firebird' then Result := TFirebirdCompiler.Create
  else raise EQueryException.Create('Unknown engine');
  Result.UseLegacyPagination := Engine.EndsWith('_legacy');
end;
procedure TQueryBuilderTests.LoadReference;
var Filename: string;
begin
  Filename := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..\test\golden.json'));
  FGolden := TJSONObject.ParseJSONValue(TFile.ReadAllText(Filename,TEncoding.UTF8)) as TJSONArray;
  Assert.IsNotNull(FGolden);
end;
procedure TQueryBuilderTests.FreeReference;
begin FreeAndNil(FGolden); end;
procedure TQueryBuilderTests.MatchesCSharp(const Engine, Name: string);
var Item, Expected: TJSONObject; Entry: TJSONValue; Binds: TJSONArray; Q: IQuery;
  C: ICompiler; R: ISqlResult; I: Integer; V: TValue; Actual: string; Raised: Boolean;
begin
  Expected := nil;
  for Entry in FGolden do
  begin
    Item := Entry as TJSONObject;
    if (Item.GetValue<string>('engine') = Engine) and (Item.GetValue<string>('name') = Name) then begin Expected := Item; Break; end;
  end;
  Assert.IsNotNull(Expected,'Missing C# fixture');
  Q := Build(Name); C := Compiler(Engine);
  if Expected.GetValue('error') <> nil then
  begin
    Raised := False;
    try R := C.Compile(Q); R := nil; except on E: EQueryException do Raised := True; end;
    Assert.IsTrue(Raised,'C# rejects this query'); Exit;
  end;
  R := C.Compile(Q);
  Assert.AreEqual(Normalize(Expected.GetValue<string>('sql')),Normalize(R.Sql),Engine+'.'+Name+' SQL');
  Assert.AreEqual(Normalize(Expected.GetValue<string>('raw')),Normalize(R.RawSql),Engine+'.'+Name+' RawSql');
  Binds := Expected.GetValue<TJSONArray>('bindings');
  Assert.AreEqual<NativeInt>(Binds.Count,R.Bindings.Count,'Binding count');
  for I := 0 to Binds.Count-1 do
  begin
    V := R.Bindings[I];
    if V.IsEmpty then Actual := '<NULL>'
    else if V.TypeInfo = TypeInfo(Boolean) then if V.AsBoolean then Actual := 'True' else Actual := 'False'
    else Actual := V.ToString;
    Assert.AreEqual(Binds.Items[I].Value,Actual,'Binding '+IntToStr(I));
  end;
  Assert.AreEqual<NativeInt>(R.Bindings.Count,R.NamedBindings.Count,'Named binding count');
end;

procedure TQueryBuilderTests.CloneAndSubqueryOwnership;
var Q, Sub, Clone: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books'); Sub := TQuery.Create('Authors'); C := TSqliteCompiler.Create;
  Sub.Select('Id').Where('Country','AT'); Q.WhereIn('AuthorId',Sub);
  Sub := nil;
  Clone := Q.Clone;
  Q.ClearComponent('where');
  R := C.Compile(Clone);
  Assert.AreEqual('SELECT * FROM "Books" WHERE "AuthorId" IN (SELECT "Id" FROM "Authors" WHERE "Country" = @p0)',R.Sql);
end;

procedure TQueryBuilderTests.CallbackExceptionAndScopeRestoration;
var Q: IQuery;
begin
  Q := TQuery.Create;
  Q.SetEngineScope('oracle');
  Assert.WillRaise(procedure begin Q.&For('sqlsrv',function(Child:IQuery):IQuery
    begin raise EQueryException.Create('callback failure'); end); end,EQueryException);
  Assert.AreEqual('oracle',Q.EngineScope);
  Assert.WillRaise(procedure begin Q.Where(function(Child:IQuery):IQuery
    begin raise EQueryException.Create('callback failure'); end); end,EQueryException);
end;

procedure TQueryBuilderTests.ParameterTypesAndInvariantDebugSql;
var Q: IQuery; C: ICompiler; R: ISqlResult; Old: Char; D: TDateTime;
begin
  Q := TQuery.Create('Books'); C := TSqliteCompiler.Create; D := EncodeDate(2025,1,2);
  Old := FormatSettings.DecimalSeparator;
  try
    FormatSettings.DecimalSeparator := ',';
    Q.Where('Price',TValue.From<Double>(1.25)).Where('Created',TValue.From<TDateTime>(D)).Where('Title','O''Brien');
    R := C.Compile(Q);
    Assert.IsTrue(R.Bindings[0].TypeInfo = TypeInfo(Double));
    Assert.IsTrue(R.Bindings[1].TypeInfo = TypeInfo(TDateTime));
    Assert.AreEqual('SELECT * FROM "Books" WHERE "Price" = 1.25 AND "Created" = ''2025-01-02'' AND "Title" = ''O''''Brien''',R.ToString);
  finally FormatSettings.DecimalSeparator := Old; end;
end;
procedure TQueryBuilderTests.RejectsUnsafeOperator;
var Q: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books').Where('Id','= 1; DROP TABLE Books --',1); C := TCompiler.Create;
  Assert.WillRaise(procedure begin R := C.Compile(Q); R := nil; end,EQueryException);
  Q.ClearComponent('where').Where('Id','@>',1); C.Whitelist(['@>']);
  R := C.Compile(Q); Assert.IsTrue(R.Sql.Contains(' @> @p0'));
end;
procedure TQueryBuilderTests.InvalidWritesDoNotReplaceValidData;
var Q: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books').AsInsert(['Title'],['A']); C := TCompiler.Create;
  Assert.WillRaise(procedure begin Q.AsInsert(['Title','Id'],['B']); end,EQueryException);
  R := C.Compile(Q); Assert.AreEqual('A',R.Bindings[0].AsString);
end;
procedure TQueryBuilderTests.BatchParameterNumbering;
var Q1, Q2: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q1 := TQuery.Create('Books').Where('Id',1); Q2 := TQuery.Create('Authors').Where('Id',2); C := TCompiler.Create;
  R := C.Compile([Q1,Q2]);
  Assert.IsTrue(R.Sql.Contains('@p0;'+#10+'SELECT'));
  Assert.IsTrue(R.Sql.EndsWith('@p1')); Assert.AreEqual<NativeInt>(2,R.Bindings.Count);
end;
procedure TQueryBuilderTests.NestedVariableResolution;
var Q: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books').Define('id',5).WhereExists(function(Child:IQuery):IQuery
    begin Result := Child.&From('Authors').Where('Id',TVariable.Create('id')); end);
  C := TCompiler.Create;
  R := C.Compile(Q); Assert.AreEqual(5,R.Bindings[0].AsInteger);
end;
procedure TQueryBuilderTests.RawArrayExpansion;
var Q: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books').WhereRaw('[Id] IN (?)',[TValue.From<TArray<Integer>>(TArray<Integer>.Create(1,2,3))]);
  C := TCompiler.Create;
  R := C.Compile(Q);
  Assert.AreEqual('SELECT * FROM "Books" WHERE "Id" IN (@p0,@p1,@p2)',R.Sql); Assert.AreEqual<NativeInt>(3,R.Bindings.Count);
end;

procedure TQueryBuilderTests.TypedArraysAndEmptyGroups;
var Q: IQuery; C: ICompiler; R: ISqlResult;
begin
  Q := TQuery.Create('Books'); C := TCompiler.Create;
  Q.WhereIn('Id',TSqlValues.&Of<Integer>(TArray<Integer>.Create(1,2))).Where(function(Child:IQuery):IQuery begin Result:=Child; end);
  R := C.Compile(Q);
  Assert.AreEqual('SELECT * FROM "Books" WHERE "Id" IN (@p0, @p1)',R.Sql);
end;
procedure TQueryBuilderTests.RttiMappingHonorsColumnKeyAndIgnore;
var Q: IQuery; Data: TUserData; C: ICompiler; R: ISqlResult;
begin
  Data := TUserData.Create; Q := TQuery.Create('Users'); C := TCompiler.Create;
  try
    Data.Id := 5; Data.Name := 'Jane'; Data.Internal := 'ignored'; Q.AsUpdate(Data);
    R := C.Compile(Q);
    Assert.IsTrue(R.Sql.Contains('"UserId" = @p0'));
    Assert.IsTrue(R.Sql.Contains('"DisplayName" = @p1'));
    Assert.IsTrue(R.Sql.EndsWith('WHERE "UserId" = @p2'));
    Assert.IsFalse(R.Sql.Contains('Internal')); Assert.AreEqual<NativeInt>(3,R.Bindings.Count);
  finally Data.Free; end;
end;

procedure TQueryBuilderTests.ReadmeExamplesProduceDocumentedSql;
var C: ICompiler;
  procedure Check(Q: IQuery; const Expected: string; BindingCount: Integer);
  var R: ISqlResult;
  begin
    R := C.Compile(Q);
    Assert.AreEqual(Normalize(Expected),Normalize(R.Sql)); Assert.AreEqual<NativeInt>(BindingCount,R.Bindings.Count);
  end;
begin
  C := TSqlServerCompiler.Create;
  Check(PublishedBooks,'SELECT [Id], [Title] FROM [Books] WHERE [IsPublished] = cast(1 as bit) AND [Lang] = @p0 ORDER BY [PublishedAt] DESC OFFSET @p1 ROWS FETCH NEXT @p2 ROWS ONLY',3);
  Check(BooksWithAuthors,'SELECT [Books].*, [Authors].[Name] AS [AuthorName] FROM [Books] INNER JOIN [Authors] ON [Authors].[Id] = [Books].[AuthorId]',0);
  Check(NestedConditions,'SELECT * FROM [Books] WHERE ([Lang] = @p0 OR [Lang] = @p1) AND [PublishedAt] IS NOT NULL',2);
  Check(PublishedCte,'WITH [published] AS (SELECT * FROM [Books] WHERE [IsPublished] = cast(1 as bit)) SELECT [Title] FROM [published]',0);
  Check(InsertUser,'INSERT INTO [Users] ([Name], [CountryId]) VALUES (@p0, @p1)',2);
  Check(UpdateUser,'UPDATE [Users] SET [Name] = @p0, [CountryId] = @p1 WHERE [Id] = @p2',3);
  Check(DeleteUser,'DELETE FROM [Users] WHERE [Id] = @p0',1);
end;

procedure TQueryBuilderTests.CorrectedHavingCallback(const Engine: string);
var Q: IQuery; C: ICompiler; R: ISqlResult; Expected, P: string;
begin
  Q := Build('havingnested'); C := Compiler(Engine);
  P := '@p'; if C.EngineCode = 'oracle' then P := ':p';
  Expected := 'SELECT * FROM '+C.Wrap('Books')+' GROUP BY '+C.Wrap('Id')+
    ' HAVING ('+C.Wrap('Id')+' = '+P+'0 OR '+C.Wrap('Id')+' = '+P+'1)';
  R := C.Compile(Q);
  Assert.AreEqual(Expected,R.Sql);
  Assert.AreEqual<NativeInt>(2,R.Bindings.Count);
  Assert.AreEqual(1,R.Bindings[0].AsInteger); Assert.AreEqual(2,R.Bindings[1].AsInteger);
end;
procedure TQueryBuilderTests.CorrectedOracleAggregateAlias(const Engine, Name: string);
var Q: IQuery; C: ICompiler; R: ISqlResult; Expected: string;
begin
  Q := Build(Name); C := Compiler(Engine);
  if Name = 'group' then Expected := 'SELECT "Category", COUNT("Id") "Count" FROM "Books" GROUP BY "Category" HAVING "Category" = :p0 OR "Category" IS NULL'
  else Expected := 'SELECT COUNT(CASE WHEN "Published" = true THEN "Id" END) "Published" FROM "Books"';
  R := C.Compile(Q);
  Assert.AreEqual(Expected,R.Sql);
  if Name = 'group' then begin Assert.AreEqual<NativeInt>(1,R.Bindings.Count); Assert.AreEqual('A',R.Bindings[0].AsString); end
  else Assert.AreEqual<NativeInt>(0,R.Bindings.Count);
end;

initialization
  TDUnitX.RegisterTestFixture(TQueryBuilderTests);
end.
