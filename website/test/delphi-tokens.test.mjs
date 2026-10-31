import test from 'node:test';
import assert from 'node:assert/strict';
import { StringStream } from '@codemirror/language';
import { delphiTokens } from '../delphi-tokens.mjs';

function tokenize(source) {
  const state = delphiTokens.startState(), tokens = [];
  for (const line of source.split('\n')) {
    const stream = new StringStream(line, 2, 2);
    while (!stream.eol()) {
      stream.start = stream.pos;
      const type = delphiTokens.token(stream, state);
      assert.ok(stream.pos > stream.start);
      if (type) tokens.push([stream.current(), type]);
    }
  }
  return tokens;
}

test('Delphi highlighting recognizes generated syntax, types and generic calls', () => {
  const tokens = tokenize("function BuildQuery: IQuery;\nbegin\n  Result := TValue.From<Int64>(42);\nend;");
  for (const token of [['function', 'keyword'], ['IQuery', 'typeName'], ['TValue', 'typeName'], ['From', 'variableName.function'], ['Int64', 'typeName'], [':=', 'operator'], ['42', 'number']]) assert.ok(tokens.some(t => t[0] === token[0] && t[1] === token[1]), token.join(':'));
});
test('Delphi strings include doubled quotes and character codes', () => {
  const tokens = tokenize("'O''Reilly'#10#$0D");
  assert.deepEqual(tokens, [["'O''Reilly'", 'string'], ['#10', 'string'], ['#$0D', 'string']]);
});
test('Delphi comments retain state across lines and end correctly', () => {
  const tokens = tokenize('// line\n{ brace\n comment } begin (* block\n comment *) end');
  assert.ok(tokens.filter(t => t[1] === 'comment').length >= 5);
  assert.deepEqual(tokens.filter(t => t[1] === 'keyword'), [['begin', 'keyword'], ['end', 'keyword']]);
});
