import test from 'node:test';
import assert from 'node:assert/strict';
import { access, readFile, readdir } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../dist');
test('built documentation links and anchors resolve under a project subpath', async () => {
  const files = ['index.html', 'CHANGELOG.html', 'converter.html', ...(await readdir(path.join(root, 'docs'))).filter(f => f.endsWith('.html')).map(f => `docs/${f}`)];
  for (const file of files) {
    const html = await readFile(path.join(root, file), 'utf8');
    assert.match(html, /<main id="main"/);
    for (const [, href] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
      if (/^(?:[a-z]+:|\/\/)/i.test(href)) continue;
      assert.ok(!href.startsWith('/'), `${file}: root-absolute URL breaks project Pages: ${href}`);
      const [relative, fragment] = href.split('#');
      const destination = relative ? path.resolve(root, path.dirname(file), decodeURI(relative)) : path.join(root, file);
      await assert.doesNotReject(access(destination), `${file}: missing ${href}`);
      if (fragment && destination.endsWith('.html')) {
        const target = await readFile(destination, 'utf8');
        assert.ok(target.includes(`id="${decodeURIComponent(fragment)}"`), `${file}: missing anchor ${href}`);
      }
    }
  }
  assert.match(await readFile(path.join(root, 'docs/EXAMPLES.html'), 'utf8'), /View Markdown source/);
});
