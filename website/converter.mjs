// The parser only reads SQL. Generated code uses the library's parameterized API.
import { numericLiteral, pagingLiteral } from './numbers.mjs';
const dialects = {
  MySQL: () => import('node-sql-parser/build/mysql.js'),
  PostgreSQL: () => import('node-sql-parser/build/postgresql.js'),
  TransactSQL: () => import('node-sql-parser/build/transactsql.js'),
  SQLite: () => import('node-sql-parser/build/sqlite.js'),
};
const unsupported = detail => { throw new Error(`${detail} is not supported in this version. No code was generated.`); };
const meaningful = value => value != null && value !== false && value !== '' &&
  (typeof value !== 'object' || Object.values(value).some(meaningful));
function check(node, keys, context) {
  for (const [key, value] of Object.entries(node)) {
    if (!keys.includes(key) && meaningful(value)) unsupported(`${context}: ${key}`);
  }
}
export function delphiString(value) {
  // Delphi strings cannot contain physical line breaks. Keep control characters explicit.
  return String(value).split(/([\x00-\x1f\x7f])/).filter(Boolean).map(part =>
    /^[\x00-\x1f\x7f]$/.test(part) ? `#${part.charCodeAt(0)}` : `'${part.replaceAll("'", "''")}'`
  ).join('') || "''";
}
function identifier(value) {
  if (typeof value !== 'string' || !/^[A-Za-z_][A-Za-z0-9_$]*$/.test(value)) unsupported('Identifiers containing spaces, punctuation or non-ASCII characters');
  return value;
}
function column(node, star = false) {
  if (node?.type !== 'column_ref') unsupported('Expressions, functions and subqueries in place of columns');
  check(node, ['type', 'table', 'column', 'parentheses', 'loc'], 'Column');
  const name = typeof node.column === 'object' ? node.column.expr?.value : node.column;
  return (node.table ? `${identifier(node.table)}.` : '') + (star && name === '*' ? '*' : identifier(name));
}
function table(node) {
  check(node, ['db', 'schema', 'table', 'as', 'join', 'on', 'loc'], 'FROM/JOIN');
  if (!node.table) unsupported('Derived tables');
  return [node.db, node.schema, node.table].filter(Boolean).map(identifier).join('.') + (node.as ? ` as ${identifier(node.as)}` : '');
}
function literal(node, literals) {
  if (!node) unsupported('Missing values');
  if (node.type === 'number' || node.type === 'unary_expr') {
    return numericLiteral(numericText(node, literals));
  }
  check(node, ['type', 'value', 'loc'], 'Value');
  if (['single_quote_string', 'string'].includes(node.type)) {
    if (!literals.strings.has(node.value)) unsupported('This string literal syntax');
    return delphiString(literals.strings.get(node.value));
  }
  if (['bool', 'boolean'].includes(node.type)) return node.value ? 'True' : 'False';
  unsupported('Parameters, NULL values in lists, or non-scalar values (use literal values for conversion)');
}
const comparisons = ['=', '!=', '<>', '<', '>', '<=', '>='];
function predicate(node, method = 'Where', indent = '    ', depth = 0, literals) {
  if (depth > 30) unsupported('Conditions nested more than 30 levels');
  if (node?.type !== 'binary_expr') unsupported('This condition');
  check(node, ['type', 'operator', 'left', 'right', 'parentheses', 'loc'], 'Condition');
  const op = node.operator.toUpperCase();
  if (['AND', 'OR'].includes(op)) {
    const base = method.replace(/^Or/, '');
    return `${indent}.${method}(\n${indent}  function(Q: IQuery): IQuery\n${indent}  begin\n${indent}    Result := Q\n` +
      predicate(node.left, base, indent + '      ', depth + 1, literals) + '\n' +
      predicate(node.right, (op === 'OR' ? 'Or' : '') + base, indent + '      ', depth + 1, literals) + `;\n${indent}  end)`;
  }
  const col = delphiString(column(node.left));
  if (['IS', 'IS NOT'].includes(op) && node.right.type === 'null') return `${indent}.${method}${op === 'IS NOT' ? 'Not' : ''}Null(${col})`;
  if (['IN', 'NOT IN', 'BETWEEN', 'NOT BETWEEN'].includes(op)) {
    if (node.right.type !== 'expr_list' || !Array.isArray(node.right.value)) unsupported('Subqueries in conditions');
    check(node.right, ['type', 'value', 'parentheses', 'loc'], 'Value list');
    const values = node.right.value.map(value => literal(value, literals));
    const between = op.includes('BETWEEN');
    if ((between && values.length !== 2) || !values.length) unsupported('This value list');
    return `${indent}.${method}${op.startsWith('NOT ') ? 'Not' : ''}${between ? 'Between' : 'In'}(${col}, ${between ? values.join(', ') : `[${values.join(', ')}]`})`;
  }
  if (![...comparisons, 'LIKE', 'NOT LIKE'].includes(op)) unsupported(`Operator ${op}`);
  if (node.right.type === 'column_ref') {
    if (!comparisons.includes(op)) unsupported('Column comparisons with LIKE');
    return `${indent}.${method}Columns(${col}, ${delphiString(op)}, ${delphiString(column(node.right))})`;
  }
  if (['LIKE', 'NOT LIKE'].includes(op)) {
    // Validate the scalar before choosing an idiomatic string helper. These
    // helpers add only their boundary wildcards and do not escape the value.
    literal(node.right, literals);
    const pattern = literals.strings.get(node.right.value);
    if (typeof pattern !== 'string') unsupported('LIKE with a non-string pattern');
    const simple = pattern.match(/^(%?)([^%_\\[\]]+)(%?)$/);
    let suffix = 'Like';
    let value = pattern;
    if (simple && (simple[1] || simple[3])) {
      suffix = simple[1] && simple[3] ? 'Contains' : simple[1] ? 'Ends' : 'Starts';
      value = simple[2];
    }
    return `${indent}.${method}${op === 'NOT LIKE' ? 'Not' : ''}${suffix}(${col}, ${delphiString(value)})`;
  }
  return `${indent}.${method}(${col}, ${delphiString(op.toLowerCase())}, ${literal(node.right, literals)})`;
}
function numericText(node, literals) {
  if (node?.type === 'unary_expr' && ['+', '-'].includes(node.operator)) {
    check(node, ['type', 'operator', 'expr', 'parentheses', 'loc'], 'Signed number');
    const text = numericText(node.expr, literals);
    return node.operator === '+' ? text : text.startsWith('-') ? text.slice(1) : '-' + text;
  }
  if (node?.type !== 'number') unsupported('Non-literal numeric values');
  check(node, ['type', 'value', 'loc'], 'Number');
  // The parser only sees small unique integer slots, never the user's numbers.
  const text = literals.numbers.get(String(Math.abs(node.value)));
  if (text == null) unsupported('Unrecognized numeric syntax');
  return (node.value < 0 ? '-' : '') + text;
}
function integer(node, max, literals) {
  return pagingLiteral(numericText(node, literals), max);
}
export async function convert(sql, dialect = 'MySQL') {
  if (!dialects[dialect]) unsupported('This SQL dialect');
  if (!sql.trim()) throw new Error('Enter a SELECT query to convert.');
  if (sql.length > 50000) throw new Error('Please use a query shorter than 50,000 characters.');
  const mod = await dialects[dialect]();
  const Parser = mod.Parser || mod.default?.Parser;
  let ast;
  // Preserve SQL literal values ourselves: the parser decodes backslash escapes
  // even in dialects where backslashes are ordinary characters.
  const literals = { strings: new Map(), numbers: new Map() };
  sql = sql.replace(/--[^\r\n]*|#[^\r\n]*|\/\*[\s\S]*?\*\/|"(?:""|[^"])*"|`(?:``|[^`])*`|\[(?:\]\]|[^\]])*\]|'(?:''|[^'])*'|[A-Za-z_][A-Za-z0-9_$]*|(?:\b\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/g, (token, offset) => {
    if (dialect === 'MySQL' && token.startsWith('/*!')) unsupported('MySQL executable comments');
    if (/^(?:\d|\.\d)/.test(token)) {
      const slot = String(7000000 + literals.numbers.size);
      literals.numbers.set(slot, token);
      return slot;
    }
    if (!token.startsWith("'")) return token;
    if (offset > 0 && /[A-Za-z0-9_$]/.test(sql[offset - 1])) unsupported('Prefixed string literals');
    if (dialect === 'MySQL' && token.includes('\\')) unsupported('MySQL string literals with backslash escapes (SQL mode dependent)');
    const marker = `QBD-LITERAL-${literals.strings.size}`;
    literals.strings.set(marker, token.slice(1, -1).replaceAll("''", "'"));
    return `'${marker}'`;
  });
  // PostgreSQL folds unquoted identifiers to lowercase. Preserve quoted tokens,
  // strings and comments, while normalizing the unquoted input before parsing.
  if (dialect === 'PostgreSQL') sql = sql.replace(/("(?:""|[^"])*"|'(?:''|[^'])*'|--[^\r\n]*|\/\*[\s\S]*?\*\/)|\b[A-Za-z_][A-Za-z0-9_$]*\b/g,
    (token, quoted) => quoted ? token : token.toLowerCase());
  try { ast = new Parser().astify(sql, { database: dialect }); }
  catch (error) { throw new Error(`Cannot parse this ${dialect} query: ${error.message}`); }
  if (Array.isArray(ast)) {
    if (ast.length !== 1) unsupported('Multiple statements');
    [ast] = ast;
  }
  if (ast.type !== 'select') unsupported('Statements other than SELECT');
  check(ast, ['type', 'columns', 'from', 'where', 'distinct', 'groupby', 'having', 'orderby', 'limit', 'top', 'loc', 'parentheses_symbol', '_parentheses'], 'SELECT');
  if (!Array.isArray(ast.from) || !ast.from.length) unsupported('SELECT without a table');
  const lines = [`  Result := TQuery.Create(${delphiString(table(ast.from[0]))})`];
  if (ast.from[0].join || ast.from[0].on) unsupported('This FROM clause');
  if (meaningful(ast.distinct)) {
    if (ast.distinct !== 'DISTINCT' && !(ast.distinct.type === 'DISTINCT' && !meaningful(ast.distinct.on))) unsupported('DISTINCT ON');
    lines.push('    .Distinct');
  }
  if (ast.columns === '*') lines.push("    .Select(['*'])");
  else lines.push(`    .Select([${ast.columns.map(item => {
    check(item, ['expr', 'as', 'type', 'loc'], 'SELECT item');
    if (item.type && item.type !== 'expr') unsupported('This SELECT item');
    const name = item.expr?.type === 'star' ? '*' : column(item.expr, true);
    return delphiString(name + (item.as ? ` as ${identifier(item.as)}` : ''));
  }).join(', ')}])`);
  for (const join of ast.from.slice(1)) {
    const target = delphiString(table(join));
    if (join.join === 'CROSS JOIN' && !join.on) { lines.push(`    .CrossJoin(${target})`); continue; }
    const method = { 'INNER JOIN': 'Join', 'LEFT JOIN': 'LeftJoin', 'RIGHT JOIN': 'RightJoin' }[join.join];
    const on = join.on;
    if (!method || on?.type !== 'binary_expr' || !comparisons.includes(on.operator)) unsupported('JOINs other than INNER/LEFT/RIGHT with a single column comparison, or CROSS JOIN');
    check(on, ['type', 'operator', 'left', 'right', 'parentheses', 'loc'], 'JOIN condition');
    lines.push(`    .${method}(${target}, ${delphiString(column(on.left))}, ${delphiString(column(on.right))}, ${delphiString(on.operator)})`);
  }
  if (ast.where) lines.push(predicate(ast.where, 'Where', '    ', 0, literals));
  if (ast.groupby) {
    const group = ast.groupby;
    if (!Array.isArray(group)) check(group, ['columns', 'modifiers'], 'GROUP BY');
    if (meaningful(group.modifiers)) unsupported('GROUP BY modifiers');
    lines.push(`    .GroupBy([${(Array.isArray(group) ? group : group.columns).map(c => delphiString(column(c))).join(', ')}])`);
  }
  if (ast.having) lines.push(predicate(ast.having, 'Having', '    ', 0, literals));
  for (const order of ast.orderby || []) {
    check(order, ['expr', 'type', 'loc'], 'ORDER BY');
    if (order.type && !['ASC', 'DESC'].includes(order.type)) unsupported('This sort direction');
    lines.push(`    .OrderBy${order.type === 'DESC' ? 'Desc' : ''}(${delphiString(column(order.expr))})`);
  }
  if (ast.top) {
    check(ast.top, ['value', 'percent', 'with_ties'], 'TOP');
    if (ast.top.percent || ast.top.with_ties) unsupported('TOP PERCENT/WITH TIES');
    const count = integer({ type: 'number', value: ast.top.value }, 2147483647n, literals);
    if (count.value === 0n) unsupported('TOP 0 (the library treats Limit(0) as unlimited)');
    lines.push(`    .Limit(${count.code})`);
  }
  if (ast.limit?.offset || ast.limit?.fetch) {
    check(ast.limit, ['offset', 'fetch'], 'Paging');
    if (ast.top) unsupported('TOP combined with OFFSET/FETCH');
    if (ast.limit.fetch) {
      const count = integer(ast.limit.fetch.value, 2147483647n, literals);
      if (count.value === 0n) unsupported('FETCH 0');
      lines.push(`    .Limit(${count.code})`);
    }
    if (ast.limit.offset) lines.push(`    .Offset(${integer(ast.limit.offset.value, 9223372036854775807n, literals).code})`);
  } else if (meaningful(ast.limit)) {
    check(ast.limit, ['value', 'seperator'], 'Paging');
    const values = ast.limit.value;
    if (!Array.isArray(values) || !values.length || values.length > 2 || !['', ',', 'offset'].includes(ast.limit.seperator || '')) unsupported('This paging syntax');
    const offsetFirst = ast.limit.seperator === ',';
    const count = values[offsetFirst ? 1 : 0];
    const offset = values.length === 2 ? values[offsetFirst ? 0 : 1] : null;
    const limit = integer(count, 2147483647n, literals);
    if (limit.value === 0n) unsupported('LIMIT 0 (the library treats Limit(0) as unlimited)');
    lines.push(`    .Limit(${limit.code})`);
    if (offset) lines.push(`    .Offset(${integer(offset, 9223372036854775807n, literals).code})`);
  }
  return `uses\n  QueryBuilder4Delphi.Query.Core,\n  QueryBuilder4Delphi.Query;\n\nfunction BuildQuery: IQuery;\nbegin\n${lines.join('\n')};\nend;\n`;
}
