import test from 'node:test';
import assert from 'node:assert/strict';
import { convert } from '../converter.mjs';
import { numericLiteral } from '../numbers.mjs';

const values = [
  ['0', '0'], ['00042', '42'], ['-0', '0'], ['+42', '42'], ['- 42', '-42'],
  ['2147483647', '2147483647'], ['-2147483648', 'Low(Integer)'],
  ['2147483648', 'Int64(2147483648)'], ['-2147483649', 'Int64(-2147483649)'],
  ['9007199254740993', 'Int64(9007199254740993)'],
  ['9223372036854775807', 'Int64(9223372036854775807)'],
  ['-9223372036854775808', 'Low(Int64)'],
];
for (const dialect of ['MySQL', 'PostgreSQL', 'TransactSQL', 'SQLite']) {
  test(`${dialect}: exact integer text and signed boundaries`, async () => {
    for (const [sql, delphi] of values) {
      const code = await convert(`SELECT * FROM t WHERE a = ${sql}`, dialect);
      assert.ok(code.includes(`.Where('a', '=', ${delphi})`), `${sql}: ${code}`);
      assert.ok(!code.includes('Data.FmtBcd'));
    }
  });
  test(`${dialect}: ordinary decimals produce natural Delphi literals`, async () => {
    for (const [sql, output] of [
      ['0.1', '0.1'], ['19.99', '19.99'], ['1.2300', '1.23'], ['1.000', '1.0'], ['.125', '0.125'],
      ['-0.000000000000000001', '-0.000000000000000001'],
      ['0001.0200', '1.02'], ['1.', '1.0'], ['0.000', '0.0'], ['- 19.990', '-19.99'],
      ['0.123456789012345', '0.123456789012345'],
    ]) {
      const code = await convert(`SELECT * FROM t WHERE a = ${sql}`, dialect);
      assert.ok(code.includes(`.Where('a', '=', ${output})`), code);
      for (const extra of ['TValue.From', 'StrToBcd', 'Data.FmtBcd', 'System.Rtti', 'System.SysUtils']) assert.ok(!code.includes(extra), code);
    }
  });
  test(`${dialect}: precise numbers in lists, ranges and HAVING`, async () => {
    const code = await convert('SELECT a FROM t WHERE a IN (9007199254740993, -9223372036854775808) AND a BETWEEN 0.100 AND 1.2500 GROUP BY a HAVING a > 0.050', dialect);
    assert.ok(code.includes(".WhereIn('a', [Int64(9007199254740993), Low(Int64)])"));
    assert.ok(code.includes(".WhereBetween('a', 0.1, 1.25)"));
    assert.ok(code.includes(".Having('a', '>', 0.05)"));
  });
  test(`${dialect}: rejects unrepresentable integers and ambiguous scientific values`, async () => {
    for (const value of ['9223372036854775808', '-9223372036854775809']) await assert.rejects(convert(`SELECT * FROM t WHERE a = ${value}`, dialect), /signed Delphi Int64 range/);
    for (const value of ['1e3', '-1E-20', '1e-324', '1e309', '0e0']) await assert.rejects(convert(`SELECT * FROM t WHERE a = ${value}`, dialect), /Scientific notation is not supported/);
    for (const value of ['0.1234567890123456', '100000000000000.000001', '9007199254740993.0', '12345678901234567890123456789012.3']) await assert.rejects(convert(`SELECT * FROM t WHERE a = ${value}`, dialect), /15 significant digits.*Currency or TBcd/);
    for (const value of ['0.' + '0'.repeat(309) + '1', '1' + '0'.repeat(309) + '.0']) await assert.rejects(convert(`SELECT * FROM t WHERE a = ${value}`, dialect), /normal Double range/);
  });
}
test('decimal safety is based on significant digits, not insignificant zeros', () => {
  assert.equal(numericLiteral('123456789012345.0000000'), '123456789012345.0');
  assert.equal(numericLiteral('0.0000000000000000001'), '0.0000000000000000001');
  assert.equal(numericLiteral('000.123450000000000000000'), '0.12345');
  assert.throws(() => numericLiteral('0.1234567890123456'), /15 significant digits/);
});
test('normal Double range checks use exact decimal bounds', () => {
  const small = '0.' + '0'.repeat(307);
  const largeZeros = '0'.repeat(294) + '.0';
  assert.equal(numericLiteral(small + '222507385850721'), small + '222507385850721');
  assert.throws(() => numericLiteral(small + '22250738585072'), /normal Double range/);
  assert.equal(numericLiteral('179769313486231' + largeZeros), '179769313486231' + largeZeros);
  assert.throws(() => numericLiteral('179769313486232' + largeZeros), /normal Double range/);
});
test('numeric token preservation does not alter strings, comments or identifiers', async () => {
  const code = await convert("SELECT a2, `price$20` FROM `t42$123` WHERE a2 = '1.2300 and 9999999999999999999999' AND a2 > 9007199254740993 /* 1e999 */");
  assert.ok(code.includes("'1.2300 and 9999999999999999999999'"));
  assert.ok(code.includes('Int64(9007199254740993)'));
  assert.ok(code.includes("TQuery.Create('t42$123')"));
  assert.ok(code.includes("'price$20'"));
});
test('paging is checked from exact integer text', async () => {
  assert.match(await convert('SELECT a FROM t ORDER BY a LIMIT 20 OFFSET 9223372036854775807'), /\.Offset\(Int64\(9223372036854775807\)\)/);
  for (const suffix of ['LIMIT 1.0', 'LIMIT 1e1', 'LIMIT 2147483648', 'LIMIT 20 OFFSET 9223372036854775808']) await assert.rejects(convert(`SELECT a FROM t ${suffix}`), /Paging requires/);
});
