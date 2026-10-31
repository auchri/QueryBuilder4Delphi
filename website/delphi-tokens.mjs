// A small lexical highlighter, not a Delphi parser or semantic validator.
// The legacy Pascal mode does not distinguish Delphi types/calls and treats
// line-leading # character codes as preprocessor text. Handle these explicitly.
const keywords = new Set(('and array as asm begin case class const constructor destructor div do downto else end except exports file finalization finally for function goto helper if implementation in inherited initialization inline interface is label library mod nil not object of on operator or out packed private procedure program property protected public published raise record repeat resourcestring self set shl shr strict string then threadvar to try type unit until uses var virtual while with xor').split(' '));
const types = new Set('boolean byte cardinal char currency double extended integer int64 nativeint nativeuint pointer real shortint single smallint string tvalue tbcd uint64 variant widechar word'.split(' '));

export const delphiTokens = {
  startState: () => ({ comment: null }),
  token(stream, state) {
    if (state.comment) {
      while (!stream.eol()) {
        if (stream.match(state.comment)) { state.comment = null; break; }
        stream.next();
      }
      return 'comment';
    }
    if (stream.eatSpace()) return null;
    if (stream.match('//')) { stream.skipToEnd(); return 'comment'; }
    if (stream.match('(*')) { state.comment = '*)'; return 'comment'; }
    if (stream.match('{')) { state.comment = '}'; return 'comment'; }
    if (stream.match(/'(?:[^']|'')*'/)) return 'string';
    if (stream.match(/#(?:\$[\da-f]+|\d+)/i)) return 'string';
    if (stream.match(/(?:\$[\da-f]+|\d+(?:\.\d+)?(?:e[+-]?\d+)?)/i)) return 'number';
    const word = stream.match(/[a-z_][\w]*/i);
    if (word) {
      const name = word[0].toLowerCase();
      if (types.has(name) || /^[IT][A-Z]\w*$/.test(word[0])) return 'typeName';
      if (keywords.has(name)) return 'keyword';
      if (stream.match(/^\s*(?:<[^<>;\r\n]+>)?\s*\(/, false)) return 'variableName.function';
      return 'variableName';
    }
    if (stream.match(/[:=+*/<>@^\-]+/)) return 'operator';
    stream.next();
    return null;
  },
};
