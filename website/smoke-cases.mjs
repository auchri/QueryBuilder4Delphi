// Every fixture is regenerated through the production converter, for each dialect.
export const smokeDialects = {
  MySQL: 'MySql', PostgreSQL: 'PostgreSql', TransactSQL: 'MSSql', SQLite: 'Sqlite',
};
export const smokeCases = [
  { name: 'Basic', sql: 'SELECT Id, Title FROM Books WHERE AuthorId = 42', bindings: 1 },
  { name: 'Joins', sql: 'SELECT b.Id, b.Title, a.Name AS AuthorName FROM Books b LEFT JOIN Authors a ON a.Id = b.AuthorId WHERE b.Price >= 10', bindings: 1 },
  { name: 'Nested', sql: 'SELECT Id FROM Books WHERE (Id = 1 OR Id = 2) AND (AuthorId = 7 OR Price > 10)', bindings: 4 },
  { name: 'Predicates', sql: "SELECT Id FROM Books WHERE Id IN (1, 2) AND Price BETWEEN 10 AND 50 AND Title LIKE 'Delphi%' AND DeletedAt IS NULL", bindings: 5 },
  { name: 'Having', sql: 'SELECT AuthorId FROM Books WHERE Price > 10 GROUP BY AuthorId HAVING AuthorId IN (7, 8) AND AuthorId BETWEEN 1 AND 9', bindings: 5 },
  { name: 'Paging', sql: dialect => dialect === 'TransactSQL' ? 'SELECT Id FROM Books ORDER BY Title DESC, Id OFFSET 40 ROWS FETCH NEXT 20 ROWS ONLY' : 'SELECT Id FROM Books ORDER BY Title DESC, Id LIMIT 20 OFFSET 40', bindings: 2 },
  { name: 'IntegerBounds', sql: 'SELECT Id FROM Books WHERE Id IN (2147483647, -2147483648, 2147483648, -2147483649, 9007199254740993, 9223372036854775807, -9223372036854775808)', bindings: 7, integerValues: ['2147483647', '-2147483648', '2147483648', '-2147483649', '9007199254740993', '9223372036854775807', '-9223372036854775808'] },
  { name: 'Decimals', sql: 'SELECT Id FROM Books WHERE Price IN (0.1, 19.99, 1.2300, .125, 1., -0.000000000000000001)', bindings: 6, decimalValues: ['0.1', '19.99', '1.2300', '0.125', '1.0', '-0.000000000000000001'] },
  { name: 'Variants', sql: dialect => `SELECT b.Id FROM Books b INNER JOIN Authors a ON a.Id = b.AuthorId ${dialect === 'SQLite' ? 'LEFT JOIN Publishers p ON p.Id = b.PublisherId INNER JOIN Languages l ON l.Id = b.LanguageId' : 'RIGHT JOIN Publishers p ON p.Id = b.PublisherId CROSS JOIN Languages l'} WHERE b.Title NOT LIKE '%draft%' OR b.Title LIKE 'A_B%' GROUP BY b.Id HAVING b.Id NOT BETWEEN 1 AND 2 OR b.Id IS NOT NULL`, bindings: 4 },
];
