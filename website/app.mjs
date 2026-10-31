import { convert } from './converter.mjs';
import { createConversionController } from './conversion-state.mjs';
import { createEditors } from './editors.mjs';
const $ = id => document.getElementById(id);
const examples = {
  basic: 'SELECT Id, Title\nFROM Books\nWHERE AuthorId = 42\nORDER BY Title;',
  join: "SELECT b.Id, b.Title, a.Name AS AuthorName\nFROM Books AS b\nLEFT JOIN Authors AS a ON a.Id = b.AuthorId\nWHERE b.Price >= 10\nORDER BY b.Title;",
  group: "SELECT Id, Title\nFROM Books\nWHERE (AuthorId = 42 OR AuthorId = 7)\n  AND Price BETWEEN 10 AND 50\n  AND DeletedAt IS NULL\nORDER BY Title DESC;",
  paging: 'SELECT Id, Title\nFROM Books\nORDER BY Title, Id\nLIMIT 20 OFFSET 40;',
};
const editors = createEditors({
  sqlHost: $('sql'), delphiHost: $('delphi'), initialSql: $('initial-sql').textContent,
  dialect: $('dialect').value, onChange: () => invalidate(), onConvert: () => run(),
});
const { invalidate, run } = createConversionController({
  convert,
  readInput: () => ({ sql: editors.readSql(), dialect: $('dialect').value }),
  render: ({ busy, code, message, error }) => {
    $('convert').disabled = busy;
    editors.setOutput(code);
    $('copy').disabled = busy || !code;
    $('status').textContent = message;
    $('status').className = error ? 'error' : '';
  },
});
$('convert').addEventListener('click', run);
$('dialect').addEventListener('change', () => { editors.setDialect($('dialect').value); invalidate(); });
$('load-example').addEventListener('click', () => {
  editors.setSql($('example').value === 'paging' && $('dialect').value === 'TransactSQL'
    ? 'SELECT TOP 20 Id, Title\nFROM Books\nORDER BY Title, Id;' : examples[$('example').value]);
  invalidate();
});
$('copy').addEventListener('click', async () => {
  const code = editors.readOutput();
  if (!code || $('copy').disabled) return;
  const stillCurrent = () => editors.readOutput() === code && !$('copy').disabled;
  try {
    await navigator.clipboard.writeText(code);
    if (stillCurrent()) $('status').textContent = 'Delphi code copied.';
  } catch {
    if (!stillCurrent()) return;
    editors.selectOutput();
    $('status').textContent = 'Select the output and copy it with Ctrl+C (or ⌘C).';
  }
});
run();
