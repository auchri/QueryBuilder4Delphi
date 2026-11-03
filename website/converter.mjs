// The parser only reads SQL. Generated code uses the library's parameterized API.
import { numericLiteral, pagingLiteral } from './numbers.mjs';
const dialects = {
  MySQL: () => import('node-sql-parser/build/mysql.js'),
  PostgreSQL: () => import('node-sql-parser/build/postgresql.js'),
  TransactSQL: () => import('node-sql-parser/build/transactsql.js'),
  SQLite: () => import('node-sql-parser/build/sqlite.js'),
};
const dialectNames = { MySQL: 'MySQL', PostgreSQL: 'PostgreSQL', TransactSQL: 'SQL Server', SQLite: 'SQLite' };
const hints = {
  column: 'Add it to the generated code with SelectRaw.',
  where: 'Add it to the generated code with WhereRaw (or HavingRaw in HAVING).',
  literal: 'Use a literal example value; the generated code binds it as a parameter.',
};
// The query being converted, kept only so errors can quote the offending SQL.
let source = null;
// Literal values were swapped for parser-safe markers; restore them for display.
function restore(text) {
  return text.replace(/'QBD-LITERAL-(\d+)'/g, (marker, index) => source.literals.quoted[index] ?? marker)
    .replace(/\b7\d{6}\b/g, slot => source.literals.numbers.get(slot) ?? slot);
}
function excerpt(start, end) {
  const text = restore(source.text.slice(start, end)).replace(/\s+/g, ' ').trim();
  return text.length > 80 ? `${text.slice(0, 79)}…` : text;
}
function unsupported(detail, node, hint) {
  const loc = node?.loc && source ? excerpt(node.loc.start.offset, node.loc.end.offset) : '';
  throw new Error(`The converter does not support ${detail}${loc ? `: “${loc}”` : ''}.${hint ? ` ${hint}` : ''} No code was generated.`);
}
const meaningful = value => value != null && value !== false && value !== '' &&
  (typeof value !== 'object' || Object.values(value).some(meaningful));
const selectParts = {
  with: ['common table expressions (WITH)', 'Use the With method in Delphi.'],
  _next: ['UNION, INTERSECT or EXCEPT', 'Combine the converted queries with Union, Intersect or Except.'],
  set_op: ['UNION, INTERSECT or EXCEPT', 'Combine the converted queries with Union, Intersect or Except.'],
  into: ['SELECT … INTO'], locking_read: ['locking clauses such as FOR UPDATE'],
  options: ['SELECT options such as SQL_CALC_FOUND_ROWS'], window: ['WINDOW clauses'],
};
function check(node, keys, context) {
  for (const [key, value] of Object.entries(node)) {
    if (keys.includes(key) || !meaningful(value)) continue;
    if (context === 'SELECT' && selectParts[key]) unsupported(selectParts[key][0], null, selectParts[key][1]);
    unsupported(`this form of ${context}`, node);
  }
}
export function delphiString(value) {
  // Delphi strings cannot contain physical line breaks. Keep control characters explicit.
  return String(value).split(/([\x00-\x1f\x7f])/).filter(Boolean).map(part =>
    /^[\x00-\x1f\x7f]$/.test(part) ? `#${part.charCodeAt(0)}` : `'${part.replaceAll("'", "''")}'`
  ).join('') || "''";
}
function identifier(value, node) {
  if (typeof value !== 'string' || !/^[A-Za-z_][A-Za-z0-9_$]*$/.test(value)) unsupported('identifiers containing spaces, punctuation or non-ASCII characters', node);
  return value;
}
function column(node, star = false) {
  if (node?.type === 'aggr_func') unsupported('aggregates in this position', node, hints.column);
  if (node?.type !== 'column_ref') unsupported('expressions, functions or subqueries in place of a column', node, hints.column);
  check(node, ['type', 'table', 'column', 'parentheses', 'collate', 'loc'], 'column reference');
  const name = typeof node.column === 'object' ? node.column.expr?.value : node.column;
  return (node.table ? `${identifier(node.table, node)}.` : '') + (star && name === '*' ? '*' : identifier(name, node));
}
function table(node) {
  if (node.expr?.ast || node.expr?.type === 'select') unsupported('derived tables (subqueries in FROM)', node, 'Build the inner query separately and pass it to From.');
  check(node, ['db', 'schema', 'table', 'as', 'join', 'on', 'loc'], 'FROM/JOIN');
  if (!node.table) unsupported('this table source', node);
  return [node.db, node.schema, node.table].filter(Boolean).map(part => identifier(part, node)).join('.') + (node.as ? ` as ${identifier(node.as, node)}` : '');
}
function literal(node, literals, context) {
  if (!node) unsupported('missing values', context);
  if (node.type === 'number' || node.type === 'unary_expr') {
    return numericLiteral(numericText(node, literals, context));
  }
  if (node.type === 'null') unsupported('NULL as a comparison value or in a value list', context, 'Use IS NULL or IS NOT NULL.');
  if (node.type === 'param' || node.type === 'var' || (node.type === 'origin' && node.value === '?')) unsupported('placeholders', context, hints.literal);
  check(node, ['type', 'value', 'loc'], 'value');
  if (['single_quote_string', 'string'].includes(node.type)) {
    if (!literals.strings.has(node.value)) unsupported('this string literal syntax', context);
    return delphiString(literals.strings.get(node.value));
  }
  if (['bool', 'boolean'].includes(node.type)) return node.value ? 'True' : 'False';
  unsupported('non-literal values', context, hints.literal);
}
const comparisons = ['=', '!=', '<>', '<', '>', '<=', '>='];
const aggregates = { COUNT: 'Count', SUM: 'Sum', AVG: 'Avg', MIN: 'Min', MAX: 'Max' };
// Returns the fluent method suffix, the column argument and an equivalent raw SQL expression.
function aggregate(node) {
  check(node, ['type', 'name', 'args', 'over', 'loc'], 'aggregate');
  const name = String(node.name).toUpperCase();
  if (!aggregates[name]) unsupported(`the aggregate ${name}`, node, hints.column);
  check(node.args, ['expr', 'distinct', 'orderby', 'separator', 'parentheses', 'loc'], 'aggregate');
  if (meaningful(node.args.distinct)) unsupported(`${name}(DISTINCT …)`, node, hints.column);
  const star = node.args.expr?.type === 'star';
  if (star && name !== 'COUNT') unsupported(`${name}(*)`, node);
  const target = star ? '*' : column(node.args.expr);
  return { method: aggregates[name], column: target, raw: `${name}(${star ? '*' : target.split('.').map(part => `[${part}]`).join('.')})` };
}
function functionName(node) {
  const name = node?.name;
  return String(typeof name === 'string' ? name : name?.name?.map(part => part.value).join('.') ?? '').toUpperCase();
}
function subquery(node) {
  if (node?.ast) return node.ast;
  if (node?.type === 'select') return node;
  if (node?.type === 'expr_list' && Array.isArray(node.value) && node.value.length === 1) return subquery(node.value[0]);
  return null;
}
function existsQuery(node) {
  if (node?.type !== 'function' || functionName(node) !== 'EXISTS') return null;
  return subquery(node.args) || unsupported('this EXISTS condition', node);
}
const logical = node => node?.type === 'binary_expr' && ['AND', 'OR'].includes(node.operator.toUpperCase()) ? node.operator.toUpperCase() : null;
// Several parser grammars group AND/OR strictly left to right, so A OR B AND C
// arrives as (A OR B) AND C. Rebuild SQL precedence from the source order instead;
// explicitly parenthesized groups stay intact. The result is one flat list per
// operator, so only a change of operator needs a nested callback group.
function logicalTree(node) {
  const sequence = [];
  (function walk(part, outer) {
    if (!logical(part) || (part.parentheses && !outer)) return sequence.push(part);
    check(part, ['type', 'operator', 'left', 'right', 'parentheses', 'loc'], 'condition');
    walk(part.left, false);
    sequence.push(logical(part));
    walk(part.right, false);
  })(node, true);
  if (sequence.length === 1) return null;
  const alternatives = [[sequence[0]]];
  for (let i = 1; i < sequence.length; i += 2) {
    if (sequence[i] === 'OR') alternatives.push([]);
    alternatives.at(-1).push(sequence[i + 1]);
  }
  const and = parts => parts.length === 1 ? parts[0] : { op: 'AND', parts };
  return alternatives.length === 1 ? and(alternatives[0]) : { op: 'OR', parts: alternatives.map(and) };
}
function conditions(node, method, indent, depth, literals) {
  const tree = node.op ? node : logicalTree(node);
  if (!tree) return [term(node, method, indent, depth, literals)];
  return tree.parts.map((part, i) => term(part, i && tree.op === 'OR' ? `Or${method}` : method, indent, depth, literals));
}
function group(node, method, indent, depth, literals) {
  if (depth > 30) unsupported('conditions nested more than 30 levels', node.op ? node.parts[0] : node);
  const base = method.replace(/^Or/, '').replace(/Not$/, '');
  return `${indent}.${method}(\n${indent}  function(Q: IQuery): IQuery\n${indent}  begin\n${indent}    Result := Q\n` +
    conditions(node, base, indent + '      ', depth + 1, literals).join('\n') + `;\n${indent}  end)`;
}
function term(node, method, indent, depth, literals) {
  if (node.op || logical(node)) return group(node, method, indent, depth, literals);
  const exists = existsQuery(node);
  if (exists) return `${indent}.${method}Exists(${chain(exists, indent + '  ', literals, true)})`;
  // Depending on the dialect, NOT (…) arrives as a unary operator or as a NOT() function.
  const inner = node?.type === 'unary_expr' && ['NOT', 'NOT EXISTS'].includes(node.operator.toUpperCase()) ? node.expr :
    node?.type === 'function' && functionName(node) === 'NOT' && node.args?.value?.length === 1 ? node.args.value[0] : null;
  if (inner) {
    const negated = node.operator?.toUpperCase() === 'NOT EXISTS' ? subquery(inner) : existsQuery(inner);
    if (negated) return `${indent}.${method}NotExists(${chain(negated, indent + '  ', literals, true)})`;
    return group(inner, `${method}Not`, indent, depth, literals);
  }
  return predicate(node, method, indent, literals);
}
function predicate(node, method, indent, literals) {
  if (node?.type !== 'binary_expr') unsupported('this condition', node, hints.where);
  check(node, ['type', 'operator', 'left', 'right', 'parentheses', 'loc'], 'condition');
  const op = node.operator.toUpperCase();
  if (node.left?.type === 'aggr_func') {
    if (!comparisons.includes(op)) unsupported(`${op} with an aggregate`, node, hints.where);
    return `${indent}.${method}Raw(${delphiString(`${aggregate(node.left).raw} ${op} ?`)}, [${literal(node.right, literals, node)}])`;
  }
  const col = delphiString(column(node.left));
  if (['IS', 'IS NOT'].includes(op)) {
    if (node.right?.type !== 'null') unsupported(`${op} with a value other than NULL`, node, hints.where);
    return `${indent}.${method}${op === 'IS NOT' ? 'Not' : ''}Null(${col})`;
  }
  const sub = subquery(node.right);
  if (sub && ['IN', 'NOT IN'].includes(op)) return `${indent}.${method}${op === 'NOT IN' ? 'Not' : ''}In(${col}, ${chain(sub, indent + '  ', literals)})`;
  if (sub && comparisons.includes(op)) return `${indent}.${method}(${col}, ${delphiString(op.toLowerCase())}, ${chain(sub, indent + '  ', literals)})`;
  if (['IN', 'NOT IN', 'BETWEEN', 'NOT BETWEEN'].includes(op)) {
    if (node.right?.type !== 'expr_list' || !Array.isArray(node.right.value)) unsupported(`this ${op} condition`, node, hints.where);
    check(node.right, ['type', 'value', 'parentheses', 'loc'], 'value list');
    const values = node.right.value.map(value => literal(value, literals, node));
    const between = op.includes('BETWEEN');
    if ((between && values.length !== 2) || !values.length) unsupported('this value list', node);
    return `${indent}.${method}${op.startsWith('NOT ') ? 'Not' : ''}${between ? 'Between' : 'In'}(${col}, ${between ? values.join(', ') : `[${values.join(', ')}]`})`;
  }
  if (![...comparisons, 'LIKE', 'NOT LIKE'].includes(op)) unsupported(`the ${op} operator`, node, hints.where);
  if (node.right?.type === 'column_ref') {
    if (!comparisons.includes(op)) unsupported('LIKE between two columns', node, hints.where);
    return `${indent}.${method}Columns(${col}, ${delphiString(op)}, ${delphiString(column(node.right))})`;
  }
  if (['LIKE', 'NOT LIKE'].includes(op)) {
    // Validate the scalar before choosing an idiomatic string helper. These
    // helpers add only their boundary wildcards and do not escape the value.
    literal(node.right, literals, node);
    const pattern = literals.strings.get(node.right.value);
    if (typeof pattern !== 'string') unsupported('LIKE with a non-string pattern', node);
    const simple = pattern.match(/^(%?)([^%_\\[\]]+)(%?)$/);
    let suffix = 'Like';
    let value = pattern;
    if (simple && (simple[1] || simple[3])) {
      suffix = simple[1] && simple[3] ? 'Contains' : simple[1] ? 'Ends' : 'Starts';
      value = simple[2];
    }
    return `${indent}.${method}${op === 'NOT LIKE' ? 'Not' : ''}${suffix}(${col}, ${delphiString(value)})`;
  }
  return `${indent}.${method}(${col}, ${delphiString(op.toLowerCase())}, ${literal(node.right, literals, node)})`;
}
function numericText(node, literals, context) {
  if (node?.type === 'unary_expr' && ['+', '-'].includes(node.operator)) {
    check(node, ['type', 'operator', 'expr', 'parentheses', 'loc'], 'signed number');
    const text = numericText(node.expr, literals, context);
    return node.operator === '+' ? text : text.startsWith('-') ? text.slice(1) : '-' + text;
  }
  if (node?.type !== 'number') unsupported('non-literal numeric values', node?.loc ? node : context, hints.literal);
  check(node, ['type', 'value', 'loc'], 'number');
  // The parser only sees small unique integer slots, never the user's numbers.
  const text = literals.numbers.get(String(Math.abs(node.value)));
  if (text == null) unsupported('this numeric syntax', context);
  return (node.value < 0 ? '-' : '') + text;
}
function integer(node, max, literals, context) {
  return pagingLiteral(numericText(node, literals, context), max);
}
// Builds a fluent chain for one SELECT. Subqueries reuse it with a deeper indent;
// inside EXISTS the library emits its own SELECT 1, so literal columns are dropped.
function chain(ast, indent, literals, exists = false) {
  if (ast?.type !== 'select') unsupported('statements other than SELECT', ast, 'Build INSERT, UPDATE and DELETE statements with AsInsert, AsUpdate and AsDelete.');
  check(ast, ['type', 'columns', 'from', 'where', 'distinct', 'groupby', 'having', 'orderby', 'limit', 'top', 'loc', 'parentheses_symbol', '_parentheses', 'parentheses'], 'SELECT');
  if (!Array.isArray(ast.from) || !ast.from.length) unsupported('SELECT without a table', ast);
  const lines = [`TQuery.Create(${delphiString(table(ast.from[0]))})`];
  if (ast.from[0].join || ast.from[0].on) unsupported('this FROM clause', ast.from[0]);
  if (meaningful(ast.distinct)) {
    if (ast.distinct !== 'DISTINCT' && !(ast.distinct.type === 'DISTINCT' && !meaningful(ast.distinct.on))) unsupported('DISTINCT ON', ast);
    lines.push(`${indent}.Distinct`);
  }
  if (ast.columns === '*') lines.push(`${indent}.Select(['*'])`);
  else {
    const plain = [];
    const flush = () => { if (plain.length) lines.push(`${indent}.Select([${plain.splice(0).join(', ')}])`); };
    for (const item of ast.columns) {
      check(item, ['expr', 'as', 'type', 'loc'], 'SELECT item');
      if (item.type && item.type !== 'expr') unsupported('this SELECT item', item, hints.column);
      const alias = item.as ? ` as ${identifier(item.as, item.expr)}` : '';
      if (exists && item.expr?.type === 'number' && !alias) continue;
      if (item.expr?.type === 'aggr_func') {
        flush();
        const { method, column: target } = aggregate(item.expr);
        lines.push(`${indent}.Select${method}(${delphiString(target + alias)})`);
        continue;
      }
      plain.push(delphiString((item.expr?.type === 'star' ? '*' : column(item.expr, true)) + alias));
    }
    flush();
  }
  for (const join of ast.from.slice(1)) {
    const target = delphiString(table(join));
    if (join.join === 'CROSS JOIN' && !join.on) { lines.push(`${indent}.CrossJoin(${target})`); continue; }
    const method = { 'INNER JOIN': 'Join', 'JOIN': 'Join', 'LEFT JOIN': 'LeftJoin', 'RIGHT JOIN': 'RightJoin' }[join.join];
    const on = join.on;
    if (!join.join) unsupported('comma-separated tables in FROM', join, 'Write the join with INNER JOIN … ON.');
    if (!method || on?.type !== 'binary_expr' || !comparisons.includes(on.operator)) unsupported('JOINs other than INNER/LEFT/RIGHT JOIN on a single column comparison, or CROSS JOIN', join, 'Add the extra JOIN conditions with a Join callback in Delphi.');
    check(on, ['type', 'operator', 'left', 'right', 'parentheses', 'loc'], 'JOIN condition');
    lines.push(`${indent}.${method}(${target}, ${delphiString(column(on.left))}, ${delphiString(column(on.right))}, ${delphiString(on.operator)})`);
  }
  if (ast.where) lines.push(...conditions(ast.where, 'Where', indent, 0, literals));
  if (ast.groupby) {
    const groupBy = ast.groupby;
    if (!Array.isArray(groupBy)) check(groupBy, ['columns', 'modifiers'], 'GROUP BY');
    if (meaningful(groupBy.modifiers)) unsupported('GROUP BY modifiers such as WITH ROLLUP', ast);
    lines.push(`${indent}.GroupBy([${(Array.isArray(groupBy) ? groupBy : groupBy.columns).map(c => delphiString(column(c))).join(', ')}])`);
  }
  if (ast.having) lines.push(...conditions(ast.having, 'Having', indent, 0, literals));
  for (const order of ast.orderby || []) {
    check(order, ['expr', 'type', 'loc', 'nulls'], 'ORDER BY');
    if (meaningful(order.nulls)) unsupported('NULLS FIRST/LAST', order.expr);
    if (order.type && !['ASC', 'DESC'].includes(order.type)) unsupported('this sort direction', order.expr);
    if (order.expr?.type === 'aggr_func') {
      lines.push(`${indent}.OrderByRaw(${delphiString(aggregate(order.expr).raw + (order.type === 'DESC' ? ' DESC' : ''))})`);
      continue;
    }
    if (order.expr?.type !== 'column_ref') unsupported('expressions in ORDER BY', order.expr, 'Add them to the generated code with OrderByRaw.');
    lines.push(`${indent}.OrderBy${order.type === 'DESC' ? 'Desc' : ''}(${delphiString(column(order.expr))})`);
  }
  if (ast.top) {
    check(ast.top, ['value', 'percent', 'with_ties'], 'TOP');
    if (ast.top.percent || ast.top.with_ties) unsupported('TOP PERCENT or WITH TIES', ast);
    const count = integer({ type: 'number', value: ast.top.value }, 2147483647n, literals, ast);
    if (count.value === 0n) unsupported('TOP 0, because the library treats Limit(0) as unlimited', ast);
    lines.push(`${indent}.Limit(${count.code})`);
  }
  if (ast.limit?.offset || ast.limit?.fetch) {
    check(ast.limit, ['offset', 'fetch', 'loc'], 'paging');
    if (ast.top) unsupported('TOP combined with OFFSET/FETCH', ast);
    if (ast.limit.fetch) {
      const count = integer(ast.limit.fetch.value, 2147483647n, literals, ast);
      if (count.value === 0n) unsupported('FETCH 0, because the library treats Limit(0) as unlimited', ast);
      lines.push(`${indent}.Limit(${count.code})`);
    }
    if (ast.limit.offset) lines.push(`${indent}.Offset(${integer(ast.limit.offset.value, 9223372036854775807n, literals, ast).code})`);
  } else if (meaningful(ast.limit)) {
    check(ast.limit, ['value', 'seperator', 'loc'], 'paging');
    const values = ast.limit.value;
    if (!Array.isArray(values) || !values.length || values.length > 2 || !['', ',', 'offset'].includes(ast.limit.seperator || '')) unsupported('this paging syntax', ast);
    const offsetFirst = ast.limit.seperator === ',';
    const count = values[offsetFirst ? 1 : 0];
    const offset = values.length === 2 ? values[offsetFirst ? 0 : 1] : null;
    const limit = integer(count, 2147483647n, literals, ast);
    if (limit.value === 0n) unsupported('LIMIT 0, because the library treats Limit(0) as unlimited', ast);
    lines.push(`${indent}.Limit(${limit.code})`);
    if (offset) lines.push(`${indent}.Offset(${integer(offset, 9223372036854775807n, literals, ast).code})`);
  }
  return lines.join('\n');
}
function parseError(error, text, dialect) {
  const offset = error?.location?.start?.offset;
  let near = '';
  if (typeof offset === 'number') {
    // Extend to whole tokens so a literal marker is never cut in half.
    const start = text.lastIndexOf(' ', Math.max(0, offset - 1)) + 1;
    const end = text.slice(offset).search(/\s/);
    near = excerpt(start, end < 0 ? text.length : Math.min(offset + end, start + 60));
  }
  return new Error(`Cannot parse this ${dialectNames[dialect]} query${near ? ` near “${near}”` : ' (it ends unexpectedly)'}. Check the syntax and the selected input dialect.`);
}
export async function convert(sql, dialect = 'MySQL') {
  if (!dialects[dialect]) throw new Error('Choose one of the listed input dialects.');
  if (!sql.trim()) throw new Error('Enter a SELECT query to convert.');
  if (sql.length > 50000) throw new Error('Please use a query shorter than 50,000 characters.');
  const mod = await dialects[dialect]();
  const Parser = mod.Parser || mod.default?.Parser;
  let ast;
  // Preserve SQL literal values ourselves: the parser decodes backslash escapes
  // even in dialects where backslashes are ordinary characters.
  const literals = { strings: new Map(), numbers: new Map(), quoted: [] };
  source = { text: sql, literals };
  try {
    sql = sql.replace(/--[^\r\n]*|#[^\r\n]*|\/\*[\s\S]*?\*\/|"(?:""|[^"])*"|`(?:``|[^`])*`|\[(?:\]\]|[^\]])*\]|'(?:''|[^'])*'|[A-Za-z_][A-Za-z0-9_$]*|(?:\b\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?/g, (token, offset, text) => {
      if (dialect === 'MySQL' && token.startsWith('/*!')) unsupported('MySQL executable comments');
      if (/^(?:\d|\.\d)/.test(token)) {
        const slot = String(7000000 + literals.numbers.size);
        literals.numbers.set(slot, token);
        return slot;
      }
      if (!token.startsWith("'")) return token;
      if (offset > 0 && /[A-Za-z0-9_$]/.test(text[offset - 1])) unsupported(`prefixed string literals such as ${text[offset - 1]}'…'`);
      if (dialect === 'MySQL' && token.includes('\\')) unsupported('MySQL string literals with backslash escapes, because their meaning depends on the SQL mode');
      const marker = `QBD-LITERAL-${literals.strings.size}`;
      literals.strings.set(marker, token.slice(1, -1).replaceAll("''", "'"));
      literals.quoted.push(token);
      return `'${marker}'`;
    });
    // Excerpts use the rewritten text before case folding, which keeps the user's spelling.
    source.text = sql;
    // PostgreSQL folds unquoted identifiers to lowercase. Preserve quoted tokens,
    // strings and comments, while normalizing the unquoted input before parsing.
    if (dialect === 'PostgreSQL') sql = sql.replace(/("(?:""|[^"])*"|'(?:''|[^'])*'|--[^\r\n]*|\/\*[\s\S]*?\*\/)|\b[A-Za-z_][A-Za-z0-9_$]*\b/g,
      (token, quoted) => quoted ? token : token.toLowerCase());
    try { ast = new Parser().astify(sql, { database: dialect, parseOptions: { includeLocations: true } }); }
    catch (error) { throw parseError(error, source.text, dialect); }
    if (Array.isArray(ast)) {
      if (ast.length !== 1) unsupported('multiple statements', null, 'Convert one SELECT at a time.');
      [ast] = ast;
    }
    return `uses\n  QueryBuilder4Delphi.Query.Core,\n  QueryBuilder4Delphi.Query;\n\nfunction BuildQuery: IQuery;\nbegin\n  Result := ${chain(ast, '    ', literals)};\nend;\n`;
  } finally {
    source = null;
  }
}
