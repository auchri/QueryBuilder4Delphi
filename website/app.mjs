import { convert } from './converter.mjs';
const $ = id => document.getElementById(id);
const examples = {
  basic: 'SELECT Id, Title\nFROM Books\nWHERE AuthorId = 42\nORDER BY Title;',
  join: "SELECT b.Id, b.Title, a.Name AS AuthorName\nFROM Books AS b\nLEFT JOIN Authors AS a ON a.Id = b.AuthorId\nWHERE b.Price >= 10\nORDER BY b.Title;",
  group: "SELECT Id, Title\nFROM Books\nWHERE (AuthorId = 42 OR AuthorId = 7)\n  AND Price BETWEEN 10 AND 50\n  AND DeletedAt IS NULL\nORDER BY Title DESC;",
  paging: 'SELECT Id, Title\nFROM Books\nORDER BY Title, Id\nLIMIT 20 OFFSET 40;',
};
let revision = 0;
function invalidate() {
  revision++;
  $('delphi').value = '';
  $('copy').disabled = true;
  $('status').textContent = 'Ready to convert.';
  $('status').className = '';
}
async function run() {
  invalidate();
  const current = revision;
  $('convert').disabled = true;
  $('status').textContent = 'Converting…';
  try {
    const code = await convert($('sql').value, $('dialect').value);
    if (current !== revision) return;
    $('delphi').value = code;
    $('copy').disabled = false;
    $('status').textContent = 'Converted. Values use the library’s parameterized API.';
  } catch (error) {
    if (current !== revision) return;
    $('status').textContent = error.message;
    $('status').className = 'error';
  } finally { $('convert').disabled = false; }
}
$('convert').addEventListener('click', run);
$('sql').addEventListener('input', invalidate);
$('dialect').addEventListener('change', invalidate);
$('load-example').addEventListener('click', () => {
  $('sql').value = $('example').value === 'paging' && $('dialect').value === 'TransactSQL'
    ? 'SELECT TOP 20 Id, Title\nFROM Books\nORDER BY Title, Id;' : examples[$('example').value];
  invalidate();
});
$('copy').addEventListener('click', async () => {
  try { await navigator.clipboard.writeText($('delphi').value); $('status').textContent = 'Delphi code copied.'; }
  catch { $('delphi').focus(); $('delphi').select(); $('status').textContent = 'Select the output and copy it with Ctrl+C (or ⌘C).'; }
});
$('sql').addEventListener('keydown', event => {
  if ((event.ctrlKey || event.metaKey) && event.key === 'Enter') { event.preventDefault(); run(); }
});
run();
