import { test, expect } from '@playwright/test';

test('editors highlight, edit, invalidate, convert, remain read-only and copy', async ({ page, context }) => {
  const errors = [];
  const externalRequests = [];
  page.on('pageerror', error => errors.push(error.message));
  page.on('request', request => { if (!request.url().startsWith('http://127.0.0.1:4174/')) externalRequests.push(request.url()); });
  await context.grantPermissions(['clipboard-read', 'clipboard-write']);
  await page.goto('converter.html');
  const input = page.getByRole('textbox', { name: 'SQL input', exact: true });
  const output = page.getByRole('textbox', { name: 'Generated Delphi code' });
  const copy = page.getByRole('button', { name: 'Copy code' });
  await expect(output).toContainText('function BuildQuery');
  await expect(input.locator('span').first()).toBeVisible();
  await expect(output.locator('span').first()).toBeVisible();
  await expect(output).toHaveAttribute('contenteditable', 'false');
  await expect(output).toHaveAttribute('aria-readonly', 'true');
  const generated = await output.innerText();
  await output.focus();
  await page.keyboard.type('must not edit');
  expect(await output.innerText()).toBe(generated);
  await copy.click();
  await expect(page.getByRole('status')).toHaveText('Delphi code copied.');
  expect(await page.evaluate(() => navigator.clipboard.readText())).toContain('function BuildQuery');
  await input.fill("SELECT *\nFROM test\nWHERE a LIKE 'foo%'");
  await expect(output).toHaveText('');
  await expect(copy).toBeDisabled();
  await input.press('Control+Enter');
  await expect(output).toContainText("WhereStarts('a', 'foo')");
  await page.getByLabel('Input dialect').selectOption('PostgreSQL');
  await expect(output).toHaveText('');
  await page.getByRole('button', { name: 'Convert to Delphi' }).click();
  await expect(output).toContainText('BuildQuery');
  await input.fill('DELETE FROM test');
  await input.press('Control+Enter');
  await expect(page.getByRole('status')).toHaveClass('error');
  await expect(copy).toBeDisabled();
  await page.getByRole('button', { name: 'Load example' }).click();
  await expect(input).toContainText('SELECT');
  await input.press('Control+End');
  await input.press('Enter');
  await input.press('Tab');
  await expect(input).toBeFocused();
  await input.press('Escape');
  await input.press('Tab');
  await expect(input).not.toBeFocused();
  expect(errors).toEqual([]);
  expect(externalRequests).toEqual([]);
});

test('copy fallback selects the read-only output', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(navigator, 'clipboard', { value: { writeText: () => Promise.reject(new Error('denied')) } }));
  await page.goto('converter.html');
  await page.getByRole('button', { name: 'Copy code' }).click();
  await expect(page.getByRole('status')).toContainText('Ctrl+C');
  await expect(page.getByRole('textbox', { name: 'Generated Delphi code' })).toBeFocused();
  expect(await page.evaluate(() => getSelection().toString())).toContain('function BuildQuery');
});

test('navigation has one active page and a keyboard-accessible Advanced group', async ({ page }) => {
  await page.goto('index.html');
  const nav = page.getByRole('navigation', { name: 'Documentation', exact: true });
  await expect(nav.locator('[aria-current="page"]')).toHaveText('Overview');
  await expect(nav.locator('details')).not.toHaveAttribute('open');
  const summary = nav.locator('summary');
  await summary.focus();
  await summary.press('Enter');
  await expect(summary).toHaveAttribute('aria-expanded', 'true');
  await nav.getByRole('link', { name: 'Porting', exact: true }).click();
  await expect(nav.locator('details')).toHaveAttribute('open', '');
  await expect(nav.locator('[aria-current="page"]')).toHaveText('Porting');
  await expect(nav.locator('summary')).toHaveAttribute('aria-expanded', 'true');
});

for (const width of [1920, 1366, 768, 320, 375, 390]) {
  test(`layout and navigation at ${width}px under the Pages subpath`, async ({ page }) => {
    await page.setViewportSize({ width, height: 900 });
    await page.goto('docs/WEBSITE.html');
    const nav = page.getByRole('navigation', { name: 'Documentation', exact: true });
    const active = nav.locator('[aria-current="page"]');
    await expect(active).toHaveText('Website maintenance');
    await expect(nav.locator('details')).toHaveAttribute('open', '');
    const overflow = await page.evaluate(() => [...document.querySelectorAll('header,main,main p, main code')].filter(el => el.getBoundingClientRect().right > innerWidth).map(el => `${el.tagName}: ${el.textContent.slice(0,80)}`));
    expect(overflow).toEqual([]);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    if (width <= 680) {
      const bounds = await active.boundingBox();
      expect(bounds.x).toBeGreaterThanOrEqual(0);
      expect(bounds.x + bounds.width).toBeLessThanOrEqual(width);
      await nav.evaluate(node => { node.scrollLeft = 0; });
      await expect(page.locator('.nav-scroll')).toHaveClass(/has-more/);
      await nav.evaluate(node => { node.scrollLeft = node.scrollWidth; });
      await expect(page.locator('.nav-scroll')).not.toHaveClass(/has-more/);
      const sidebar = await page.locator('.sidebar').boundingBox();
      const main = await page.locator('main').boundingBox();
      expect(main.y).toBeGreaterThanOrEqual(sidebar.y + sidebar.height);
    }
    await page.goto('converter.html');
    await expect(page.getByRole('textbox', { name: 'Generated Delphi code' })).toContainText('BuildQuery');
    const panels = await page.locator('.editor-panel').all();
    const first = await panels[0].boundingBox(), second = await panels[1].boundingBox();
    if (width > 1150) expect(second.x).toBeGreaterThan(first.x + first.width);
    else expect(second.y).toBeGreaterThan(first.y + first.height);
    expect(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth)).toBe(true);
    if (width <= 680) {
      const before = await nav.boundingBox();
      const summary = nav.locator('summary');
      await summary.focus();
      await summary.press('Enter');
      await expect(summary).toHaveAttribute('aria-expanded', 'true');
      expect((await nav.boundingBox()).height).toBe(before.height);
      await nav.evaluate(node => { node.scrollLeft = node.scrollWidth; });
      const lastLink = nav.getByRole('link', { name: 'Website maintenance' });
      const lastBounds = await lastLink.boundingBox();
      expect(lastBounds.x).toBeGreaterThanOrEqual(0);
      expect(lastBounds.x + lastBounds.width).toBeLessThanOrEqual(width);
    }
    await page.locator('main').evaluate(el => Promise.all(el.getAnimations().map(animation => animation.finished)));
    await page.screenshot({ path: `test-results/converter-${width}.png`, fullPage: true });
  });
}

test('reduced motion and editor keyboard focus', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.goto('converter.html');
  expect(await page.locator('html').evaluate(el => getComputedStyle(el).scrollBehavior)).toBe('auto');
  expect(await page.locator('main').evaluate(el => getComputedStyle(el).animationName)).toBe('none');
  await page.getByRole('textbox', { name: 'SQL input', exact: true }).focus();
  expect(await page.locator('.editor-panel').first().evaluate(el => getComputedStyle(el).outlineStyle)).toBe('solid');
});
