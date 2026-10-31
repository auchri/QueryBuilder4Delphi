import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { convert, delphiString } from '../converter.mjs';

for (const dialect of ['MySQL', 'PostgreSQL', 'TransactSQL', 'SQLite']) {
  test(`${dialect}: basic query and aliases`, async () => {
    const code = await convert('SELECT b.Id, b.Title AS BookTitle FROM Books b WHERE b.AuthorId = 42 ORDER BY b.Title DESC', dialect);
    const folded = dialect === 'PostgreSQL';
    assert.ok(code.includes(`TQuery.Create('${folded ? 'books' : 'Books'} as b')`));
    assert.ok(code.includes(folded ? "'b.title as booktitle'" : "'b.Title as BookTitle'"));
    assert.ok(code.includes(folded ? ".Where('b.authorid', '=', 42)" : ".Where('b.AuthorId', '=', 42)"));
    assert.match(code, /\.OrderByDesc\(/);
  });
  test(`${dialect}: standard string escaping and NULL`, async () => {
    const code = await convert("SELECT * FROM Books WHERE Title = 'O''Reilly' AND DeletedAt IS NOT NULL", dialect);
    assert.match(code, /, '=', 'O''Reilly'\)/);
    assert.match(code, /\.WhereNotNull\(/);
    assert.match(code, /\.Select\(\['\*'\]\)/);
  });
  test(`${dialect}: distinct, grouping and HAVING`, async () => {
    const code = await convert('SELECT DISTINCT AuthorId FROM Books GROUP BY AuthorId HAVING AuthorId > 2', dialect);
    assert.match(code, /\.Distinct/);
    assert.match(code, /\.GroupBy\(/);
    assert.match(code, /\.Having\(/);
  });
  test(`${dialect}: joins use column arguments in library order`, async () => {
    const code = await convert('SELECT b.Id FROM Books b LEFT JOIN Authors a ON a.Id = b.AuthorId', dialect);
    assert.ok(code.includes(dialect === 'PostgreSQL' ? ".LeftJoin('authors as a', 'a.id', 'b.authorid', '=')" : ".LeftJoin('Authors as a', 'a.Id', 'b.AuthorId', '=')"));
  });
  test(`${dialect}: reject unions, subqueries and aggregates`, async () => {
    for (const query of ['SELECT Id FROM Books UNION SELECT Id FROM Authors', 'SELECT COUNT(*) FROM Books', 'SELECT Id FROM Books WHERE Id IN (SELECT Id FROM Authors)', 'SELECT * FROM (SELECT Id FROM Books) b']) {
      await assert.rejects(convert(query, dialect), /not supported|Cannot parse/);
    }
  });
}
test('keeps mixed AND/OR precedence through nested callbacks', async () => {
  const code = await convert('SELECT Id FROM Books WHERE (A = 1 OR B = 2) AND (C = 3 OR D = 4)');
  assert.equal((code.match(/function\(Q: IQuery\)/g) || []).length, 3);
  assert.match(code, /\.Where\('A', '=', 1\)\n\s+\.OrWhere\('B', '=', 2\)/);
  assert.match(code, /\.Where\('C', '=', 3\)\n\s+\.OrWhere\('D', '=', 4\)/);
});
test('IN, BETWEEN, LIKE and column comparisons', async () => {
  const code = await convert("SELECT Id FROM Books WHERE Id NOT IN (1, 2) AND Price BETWEEN 10 AND 20 AND Title LIKE 'Delphi%' AND A >= B");
  assert.match(code, /\.WhereNotIn\('Id', \[1, 2\]\)/);
  assert.match(code, /\.WhereBetween\('Price', 10, 20\)/);
  assert.match(code, /\.WhereStarts\('Title', 'Delphi'\)/);
  assert.match(code, /\.WhereColumns\('A', '>=', 'B'\)/);
});
for (const dialect of ['MySQL', 'PostgreSQL', 'TransactSQL', 'SQLite']) {
  test(`${dialect}: LIKE uses the matching fluent string helper`, async () => {
    for (const [pattern, method, value] of [
      ['foo%', 'Starts', 'foo'], ['%foo', 'Ends', 'foo'], ['%foo%', 'Contains', 'foo'],
      ['foo', 'Like', 'foo'], ['f%oo%', 'Like', 'f%oo%'], ['foo_%', 'Like', 'foo_%'],
      ['[ab]%', 'Like', '[ab]%'], ['%', 'Like', '%'], ['%%', 'Like', '%%'], ['', 'Like', ''],
    ]) {
      for (const negated of [false, true]) {
        const code = await convert(`SELECT * FROM test WHERE a ${negated ? 'NOT ' : ''}LIKE '${pattern}'`, dialect);
        assert.ok(code.includes(`.Where${negated ? 'Not' : ''}${method}('a', '${value}')`), code);
      }
    }
  });
}
test('LIKE helpers preserve OR and HAVING context', async () => {
  const code = await convert("SELECT a FROM test WHERE a LIKE 'foo%' OR a NOT LIKE '%bar%' GROUP BY a HAVING a LIKE '%end'");
  assert.match(code, /\.WhereStarts\('a', 'foo'\)/);
  assert.match(code, /\.OrWhereNotContains\('a', 'bar'\)/);
  assert.match(code, /\.HavingEnds\('a', 'end'\)/);
});
test('dialect paging', async () => {
  for (const dialect of ['MySQL', 'PostgreSQL', 'SQLite']) {
    assert.match(await convert('SELECT Id FROM Books ORDER BY Id LIMIT 20 OFFSET 40', dialect), /\.Limit\(20\)\n\s+\.Offset\(40\)/);
  }
  assert.match(await convert('SELECT Id FROM Books LIMIT 40,20'), /\.Limit\(20\)\n\s+\.Offset\(40\)/);
  assert.match(await convert('SELECT TOP 20 Id FROM Books', 'TransactSQL'), /\.Limit\(20\)/);
  assert.match(await convert('SELECT Id FROM Books ORDER BY Id OFFSET 40 ROWS FETCH NEXT 20 ROWS ONLY', 'TransactSQL'), /\.Limit\(20\)\n\s+\.Offset\(40\)/);
});
test('PostgreSQL quoted identifiers retain case', async () => {
  assert.match(await convert('SELECT "Id" FROM "Books" WHERE "Title" = \'ABC\'', 'PostgreSQL'), /TQuery.Create\('Books'\)[\s\S]*\.Select\(\['Id'\]\)[\s\S]*\.Where\('Title', '=', 'ABC'\)/);
});
test('Delphi strings encode controls and quotes', () => {
  assert.equal(delphiString("O'Reilly\nline\r\t"), "'O''Reilly'#10'line'#13#9");
  assert.equal(delphiString(''), "''");
});
test('literal contents survive parser escape rules without double decoding', async () => {
  for (const dialect of ['PostgreSQL', 'TransactSQL', 'SQLite']) {
    assert.ok((await convert(String.raw`SELECT * FROM Books WHERE Title = 'a\nb'`, dialect)).includes(String.raw`'a\nb'`));
    assert.ok((await convert("SELECT * FROM Books WHERE Title = 'O''''Reilly'", dialect)).includes("'O''''Reilly'"));
    assert.ok((await convert("SELECT * FROM Books WHERE Title = 'line\nnext'", dialect)).includes("'line'#10'next'"));
  }
});
test('large signed integer literals use an explicit Int64', async () => {
  assert.match(await convert('SELECT Id FROM Books WHERE Id = 3000000000'), /Int64\(3000000000\)/);
});
test('reject statements and clauses that would otherwise silently lose meaning', async () => {
  for (const query of [
    'DELETE FROM Books', 'SELECT Id FROM Books; SELECT Id FROM Authors',
    'SELECT SQL_CALC_FOUND_ROWS Id FROM Books', 'SELECT Id INTO Other FROM Books',
    'SELECT Id FROM Books FOR UPDATE', 'SELECT Id FROM Books b, Authors a',
    'SELECT b.Id FROM Books b JOIN Authors a ON a.Id=b.AuthorId AND a.Id>0',
    'SELECT Id FROM Books WHERE Id = NULL', 'SELECT Id FROM Books WHERE Id = ?',
    'SELECT Id FROM Books ORDER BY Id + 1', 'SELECT Id FROM Books GROUP BY Id WITH ROLLUP',
    'SELECT `odd.column` FROM Books', 'SELECT * FROM Books LIMIT -1',
    'SELECT * FROM Books LIMIT 0', 'SELECT /*! DISTINCT */ Id FROM Books',
    'SELECT Id FROM Books WHERE Id = 1e-324',
    String.raw`SELECT * FROM Books WHERE Title = 'a\nb'`,
  ]) await assert.rejects(convert(query), /not supported|Cannot parse|Paging requires/, query);
  await assert.rejects(convert('SELECT TOP 10 PERCENT Id FROM Books', 'TransactSQL'), /not supported/);
  await assert.rejects(convert('SELECT TOP 0 Id FROM Books', 'TransactSQL'), /not supported/);
  await assert.rejects(convert("SELECT * FROM Books WHERE Title = E'abc'", 'PostgreSQL'), /not supported/);
  await assert.rejects(convert('SELECT DISTINCT ON (Id) Id FROM Books', 'PostgreSQL'), /not supported/);
  await assert.rejects(convert(''), /Enter a SELECT/);
});
test('generated fluent calls exist in the Delphi interface', async () => {
  const api = await readFile(new URL('../../src/QueryBuilder4Delphi.Query.Core.pas', import.meta.url), 'utf8');
  const code = await convert("SELECT DISTINCT b.Id FROM Books b RIGHT JOIN Authors a ON b.AuthorId=a.Id WHERE b.Price NOT BETWEEN 1 AND 2 OR b.Title NOT LIKE 'A%' GROUP BY b.Id HAVING b.Id IN (1,2) ORDER BY b.Id DESC LIMIT 10 OFFSET 5");
  for (const [, method] of code.matchAll(/\.(\w+)(?:\(|\n)/g)) {
    if (method === 'Create') continue;
    assert.match(api, new RegExp(`function ${method}\\b`, 'i'), method);
  }
});
