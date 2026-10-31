import { convert } from './converter.mjs';
import { createConversionController } from './conversion-state.mjs';
const $ = id => document.getElementById(id);
const examples = {
  basic: 'SELECT Id, Title\nFROM Books\nWHERE AuthorId = 42\nORDER BY Title;',
  join: "SELECT b.Id, b.Title, a.Name AS AuthorName\nFROM Books AS b\nLEFT JOIN Authors AS a ON a.Id = b.AuthorId\nWHERE b.Price >= 10\nORDER BY b.Title;",
  group: "SELECT Id, Title\nFROM Books\nWHERE (AuthorId = 42 OR AuthorId = 7)\n  AND Price BETWEEN 10 AND 50\n  AND DeletedAt IS NULL\nORDER BY Title DESC;",
  paging: 'SELECT Id, Title\nFROM Books\nORDER BY Title, Id\nLIMIT 20 OFFSET 40;',
};
const { invalidate, run } = createConversionController({
  convert,
  readInput: () => ({ sql: $('sql').value, dialect: $('dialect').value }),
  render: ({ busy, code, message, error }) => {
    $('convert').disabled = busy;
    $('delphi').value = code;
    $('copy').disabled = busy || !code;
    $('status').textContent = message;
    $('status').className = error ? 'error' : '';
  },
});
$('convert').addEventListener('click', run);
$('sql').addEventListener('input', invalidate);
$('dialect').addEventListener('change', invalidate);
$('load-example').addEventListener('click', () => {
  $('sql').value = $('example').value === 'paging' && $('dialect').value === 'TransactSQL'
    ? 'SELECT TOP 20 Id, Title\nFROM Books\nORDER BY Title, Id;' : examples[$('example').value];
  invalidate();
});
$('copy').addEventListener('click', async () => {
  const code = $('delphi').value;
  if (!code || $('copy').disabled) return;
  const stillCurrent = () => $('delphi').value === code && !$('copy').disabled;
  try {
    await navigator.clipboard.writeText(code);
    if (stillCurrent()) $('status').textContent = 'Delphi code copied.';
  } catch {
    if (!stillCurrent()) return;
    $('delphi').focus(); $('delphi').select();
    $('status').textContent = 'Select the output and copy it with Ctrl+C (or ⌘C).';
  }
});
$('sql').addEventListener('keydown', event => {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); run(); }
});
run();
