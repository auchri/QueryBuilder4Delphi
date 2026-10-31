// Each run owns its result and loading state until input invalidates it.
export function createConversionController({ convert, readInput, render }) {
  let revision = 0;
  let busy = false;
  function show(state) { busy = state.busy; render(state); }
  function invalidate() {
    revision++;
    show({ busy: false, code: '', message: 'Ready to convert.', error: false });
  }
  async function run() {
    // The keyboard shortcut follows the same rule as the disabled button.
    if (busy) return;
    const current = ++revision;
    const { sql, dialect } = readInput();
    show({ busy: true, code: '', message: 'Converting…', error: false });
    try {
      const code = await convert(sql, dialect);
      if (current !== revision) return;
      show({ busy: false, code, message: 'Converted. Values use the library’s parameterized API.', error: false });
    } catch (error) {
      if (current !== revision) return;
      const message = typeof error?.message === 'string' && error.message ? error.message :
        typeof error === 'string' && error ? error : 'Unexpected conversion error. Please check your SQL and try again.';
      show({ busy: false, code: '', message, error: true });
    }
  }
  return { invalidate, run };
}
