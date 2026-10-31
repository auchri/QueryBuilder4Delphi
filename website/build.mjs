import { readdir, readFile, mkdir, writeFile, cp } from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Marked } from 'marked';
import GithubSlugger from 'github-slugger';
import hljs from 'highlight.js';
import { build } from 'esbuild';

export const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const site = path.join(root, 'website');
export const output = path.join(site, 'dist');
const repo = 'https://github.com/auchri/QueryBuilder4Delphi';
const escape = s => String(s).replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll('"', '&quot;');
export const documents = ['README.md', 'CHANGELOG.md', ...(await readdir(path.join(root, 'docs'))).filter(f => f.endsWith('.md')).map(f => `docs/${f}`)];
const target = source => source === 'README.md' ? 'index.html' : source.replace(/\.md$/, '.html');
export function linkTo(href, source) {
  if (!href || /^(?:[a-z][a-z0-9+.-]*:|\/\/|#)/i.test(href)) return href;
  const match = href.match(/^([^?#]*)(.*)$/);
  const resolved = path.posix.normalize(path.posix.join(path.posix.dirname(source), decodeURI(match[1])));
  if (!documents.includes(resolved)) return `${repo}/blob/main/${resolved}${match[2]}`;
  return path.posix.relative(path.posix.dirname(target(source)), target(resolved)) + match[2];
}
const menu = [
  ['README.md', 'Overview'], ['converter.html', 'SQL → Delphi'],
  ['docs/EXAMPLES.md', 'Examples'], ['docs/API.md', 'API reference'],
  ['docs/OBJECT_MAPPING.md', 'Object mapping'], ['docs/PORTING.md', 'Porting'],
  ['docs/VALIDATION.md', 'Validation'], ['docs/XML_DOCUMENTATION.md', 'XML documentation'],
  ['docs/MAPPING_PERFORMANCE.md', 'Mapping performance'], ['CHANGELOG.md', 'Changelog'],
  ['docs/WEBSITE.md', 'Website maintenance'],
];
function shell(title, body, source, toc = []) {
  const filename = target(source);
  const prefix = path.posix.relative(path.posix.dirname(filename), '.') || '.';
  const relative = to => path.posix.relative(path.posix.dirname(filename), to);
  const navLink = ([file, label]) => `<a ${file === source ? 'aria-current="page"' : ''} href="${relative(target(file))}">${label}</a>`;
  const advanced = menu.slice(5);
  const expanded = advanced.some(([file]) => file === source);
  return `<!doctype html>
<html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)} · QueryBuilder4Delphi</title><meta name="description" content="Fluent, parameterized SQL for Delphi. Documentation and a browser-local SQL to Delphi converter.">
<link rel="stylesheet" href="${prefix}/assets/style.css"><link rel="icon" href="${prefix}/assets/favicon.svg" type="image/svg+xml"></head>
<body id="top"><a class="skip" href="#main">Skip to content</a><header><a class="brand" href="${relative('index.html')}"><span class="logo">Q<span>›</span></span>QueryBuilder<span class="muted">4Delphi</span></a><a href="${repo}">GitHub ↗</a></header>
<div class="layout"><aside class="sidebar"><p class="eyebrow">DEVELOPER GUIDE</p><div class="nav-scroll"><nav aria-label="Documentation">${menu.slice(0, 5).map(navLink).join('')}<details class="advanced-nav"${expanded ? ' open' : ''}><summary aria-expanded="${expanded}">Advanced</summary><div class="advanced-links">${advanced.map(navLink).join('')}</div></details></nav></div><div class="sidebar-note">Delphi 12+<br>Win32 & Win64<br><span>Six SQL dialects. One fluent API.</span></div></aside>
<main id="main" class="${source === 'converter.html' ? 'converter-page' : 'documentation'}">${body}<footer>QueryBuilder4Delphi · <a href="${repo}/blob/main/LICENSE">MIT license</a> · <a href="${prefix}/assets/third-party-licenses.txt">Third-party licenses</a>${source.endsWith('.md') ? ` · <a href="${repo}/blob/main/${source}">View Markdown source ↗</a>` : ''}</footer></main>
${toc.length ? `<aside class="toc"><p class="eyebrow">ON THIS PAGE</p><nav aria-label="On this page">${toc.map(h => `<a href="#${h.id}">${h.text}</a>`).join('')}</nav></aside>` : ''}</div>
<a class="back-to-top" href="#top" aria-label="Back to top" hidden><span aria-hidden="true">↑</span> Back to top</a>
<script type="module" src="${prefix}/assets/navigation.js"></script></body></html>`;
}
await mkdir(path.join(output, 'assets'), { recursive: true });
for (const source of documents) {
  const markdown = await readFile(path.join(root, source), 'utf8');
  const slugger = new GithubSlugger();
  const toc = [];
  const marked = new Marked({ renderer: {
    heading({ tokens, depth }) {
      const text = this.parser.parseInline(tokens);
      const id = slugger.slug(text.replace(/<[^>]+>/g, ''));
      if (depth === 2) toc.push({ id, text });
      return `<h${depth} id="${id}">${text}<a class="anchor" href="#${id}" aria-label="Link to this heading">#</a></h${depth}>`;
    },
    link({ href, title, tokens }) { return `<a href="${escape(linkTo(href, source))}"${title ? ` title="${escape(title)}"` : ''}>${this.parser.parseInline(tokens)}</a>`; },
    code({ text, lang }) {
      const language = (lang || '').split(/\s/)[0];
      const html = hljs.getLanguage(language) ? hljs.highlight(text, { language }).value : escape(text);
      return `<div class="code-block"><span class="code-language">${escape(language || 'text')}</span><pre><code class="hljs">${html}</code></pre></div>`;
    },
  }});
  const body = marked.parse(markdown);
  const title = markdown.match(/^# (.+)/m)?.[1] || source;
  const file = path.join(output, target(source));
  await mkdir(path.dirname(file), { recursive: true });
  await writeFile(file, shell(title, body, source, toc));
}
const converter = await readFile(path.join(site, 'converter.html'), 'utf8');
await writeFile(path.join(output, 'converter.html'), shell('SQL to Delphi', converter, 'converter.html'));
await cp(path.join(site, 'style.css'), path.join(output, 'assets/style.css'));
await cp(path.join(site, 'favicon.svg'), path.join(output, 'assets/favicon.svg'));
await cp(path.join(site, 'node_modules/highlight.js/styles/github-dark.css'), path.join(output, 'assets/highlight.css'));
const licenses = [];
const lock = JSON.parse(await readFile(path.join(site, 'package-lock.json'), 'utf8'));
for (const [location, entry] of Object.entries(lock.packages)) {
  if (!location || entry.dev) continue;
  const dependency = path.join(site, location);
  const pkg = JSON.parse(await readFile(path.join(dependency, 'package.json'), 'utf8'));
  const license = (await readdir(dependency)).find(file => /^license(?:\.(?:txt|md))?$/i.test(file));
  if (!license) throw new Error(`Missing license file: ${pkg.name}`);
  licenses.push(`${pkg.name} ${pkg.version}\n${await readFile(path.join(dependency, license), 'utf8')}`);
}
await writeFile(path.join(output, 'assets/third-party-licenses.txt'), licenses.join('\n\n---\n\n'));
await writeFile(path.join(output, '.nojekyll'), '');
await build({ entryPoints: ['app.mjs', 'navigation.mjs'].map(file => path.join(site, file)), outdir: path.join(output, 'assets'), bundle: true, splitting: true, format: 'esm', minify: true, entryNames: '[name]', chunkNames: '[name]-[hash]', logLevel: 'info' });
console.log(`Built ${documents.length} documentation pages directly from repository Markdown, plus the converter.`);
