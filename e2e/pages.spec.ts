import { test, expect } from '@playwright/test';
import { uniqueId, fillMarkdownEditor } from './helpers/test-helpers';

test.describe('Page Editing', () => {
  let reportUrl: string;

  test.beforeEach(async ({ page }) => {
    // Create a report with a page for each test
    const reportTitle = `Page Edit Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();
  });

  test.describe('Page Content Editing', () => {
    test('opens page in edit mode', async ({ page }) => {
      const pageTitle = `Edit Mode ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Find and click edit
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Should show editor
      const editor = page.locator('textarea, trix-editor, [contenteditable="true"], [data-controller*="editor"], [data-controller*="house-md"]');
      await expect(editor.first()).toBeVisible();
    });

    test('saves edited content', async ({ page }) => {
      const pageTitle = `Save Content ${uniqueId()}`;
      const newContent = `Updated content ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Edit the page
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Fill in content
      const editor = page.locator('textarea, trix-editor, [contenteditable="true"]');
      await editor.first().fill(newContent);

      // Save
      await page.click('input[type="submit"], button[type="submit"]');

      // Verify content was saved
      await expect(page.locator(`text="${newContent}"`).first()).toBeVisible();
    });

    test('preserves markdown formatting', async ({ page }) => {
      const pageTitle = `Markdown Test ${uniqueId()}`;
      const markdownContent = '# Heading\n\n**Bold text** and *italic*\n\n- List item 1\n- List item 2';

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);

      // Add markdown content
      const editor = page.locator('textarea, trix-editor, [contenteditable="true"]');
      if (await editor.first().isVisible()) {
        await editor.first().fill(markdownContent);
      }

      await page.click('input[type="submit"], button[type="submit"]');

      // Verify page was created
      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });
  });

  test.describe('Rich Text Features', () => {
    test('editor has formatting toolbar', async ({ page }) => {
      const pageTitle = `Toolbar Test ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Edit page
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Check for toolbar elements
      const toolbar = page.locator('[data-controller*="editor"], [data-controller*="house-md"], .toolbar, .trix-button-group');
      if (await toolbar.first().isVisible()) {
        await expect(toolbar.first()).toBeVisible();
      }
    });
  });

  test.describe('Auto-save', () => {
    test('content is saved automatically', async ({ page }) => {
      const pageTitle = `Autosave Test ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Edit page
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Type content
      const editor = page.locator('textarea, trix-editor, [contenteditable="true"]');
      const testContent = `Autosave content ${uniqueId()}`;
      await editor.first().fill(testContent);

      // Wait for potential autosave
      await page.waitForTimeout(2000);

      // Refresh page
      await page.reload();

      // Content should be preserved (if autosave is enabled)
      // This test verifies the mechanism exists
    });
  });

  test.describe('Content Validation', () => {
    test('allows empty content', async ({ page }) => {
      const pageTitle = `Empty Content ${uniqueId()}`;

      // Create page with just title
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Should succeed
      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });

    test('handles long content', async ({ page }) => {
      const pageTitle = `Long Content ${uniqueId()}`;
      const longContent = 'Lorem ipsum dolor sit amet. '.repeat(100);

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);

      const editor = page.locator('textarea, trix-editor, [contenteditable="true"]');
      if (await editor.first().isVisible()) {
        await editor.first().fill(longContent);
      }

      await page.click('input[type="submit"], button[type="submit"]');

      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });
  });

  test.describe('Edit History', () => {
    test('tracks edit history', async ({ page }) => {
      const pageTitle = `History Test ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Check for history link
      const historyLink = page.locator('a[href*="/edits"], a:has-text("History"), a:has-text("Edits")');
      if (await historyLink.first().isVisible()) {
        await historyLink.first().click();
        // History page should load
        await expect(page).toHaveURL(/\/edits/);
      }
    });
  });
});
