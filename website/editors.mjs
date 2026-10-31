import { EditorState } from '@codemirror/state';
import { EditorView, keymap, lineNumbers, highlightActiveLine, drawSelection } from '@codemirror/view';
import { defaultKeymap, history, historyKeymap, indentWithTab } from '@codemirror/commands';
import { StreamLanguage, HighlightStyle, syntaxHighlighting, indentOnInput } from '@codemirror/language';
import { sql, MySQL, PostgreSQL, MSSQL, SQLite } from '@codemirror/lang-sql';
import { Compartment } from '@codemirror/state';
import { tags } from '@lezer/highlight';
import { delphiTokens } from './delphi-tokens.mjs';

const colors = HighlightStyle.define([
  { tag: tags.keyword, color: '#ffab99' },
  { tag: tags.string, color: '#a5d6ff' },
  { tag: tags.number, color: '#91c9ff' },
  { tag: tags.comment, color: '#a0aab5', fontStyle: 'italic' },
  { tag: tags.operator, color: '#ddd4a1' },
  { tag: tags.typeName, color: '#95d9ce' },
  { tag: tags.function(tags.variableName), color: '#d6b5fa' },
]);
const dialects = { MySQL, PostgreSQL, TransactSQL: MSSQL, SQLite };

export function createEditors({ sqlHost, delphiHost, initialSql, dialect, onChange, onConvert }) {
  const language = new Compartment();
  const common = [
    lineNumbers(), drawSelection(), history(),
    syntaxHighlighting(colors),
    EditorView.theme({}, { dark: true }),
    keymap.of([...defaultKeymap, ...historyKeymap]),
  ];
  const input = new EditorView({
    parent: sqlHost,
    state: EditorState.create({ doc: initialSql, extensions: [
      keymap.of([{ key: 'Mod-Enter', run: () => { onConvert(); return true; } }, indentWithTab]),
      ...common, highlightActiveLine(), indentOnInput(),
      language.of(sql({ dialect: dialects[dialect] })),
      EditorView.contentAttributes.of({ 'aria-label': 'SQL input', 'aria-describedby': 'editor-help', spellcheck: 'false' }),
      EditorState.transactionFilter.of(tr => tr.newDoc.length > 50000 ? [] : tr),
      EditorView.updateListener.of(update => { if (update.docChanged) onChange(); }),
    ] }),
  });
  const output = new EditorView({
    parent: delphiHost,
    state: EditorState.create({ extensions: [
      ...common, StreamLanguage.define(delphiTokens),
      EditorState.readOnly.of(true), EditorView.editable.of(false),
      EditorView.contentAttributes.of({ 'aria-label': 'Generated Delphi code', 'aria-readonly': 'true', tabindex: '0', role: 'textbox' }),
    ] }),
  });
  const replace = (view, value) => {
    if (view.state.doc.toString() !== value) view.dispatch({ changes: { from: 0, to: view.state.doc.length, insert: value } });
  };
  return {
    readSql: () => input.state.doc.toString(),
    readOutput: () => output.state.doc.toString(),
    setSql: value => replace(input, value),
    setOutput: value => replace(output, value),
    setDialect: value => input.dispatch({ effects: language.reconfigure(sql({ dialect: dialects[value] })) }),
    selectOutput: () => { output.focus(); output.dispatch({ selection: { anchor: 0, head: output.state.doc.length } }); },
  };
}
