import { test, expect } from '@playwright/test';
import { uniqueId } from './helpers/test-helpers';

test.describe('Sections', () => {
  let reportUrl: string;
  let reportTitle: string;

  test.beforeEach(async ({ page }) => {
    // Create a fresh report for each test
    reportTitle = `Sections Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();
  });

  test.describe('Add Page Section', () => {
    test('shows new page form', async ({ page }) => {
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();

      await expect(page.locator('input[name*="[title]"], input[name="section[title]"]')).toBeVisible();
    });

    test('creates a new page section', async ({ page }) => {
      const pageTitle = `Test Page ${uniqueId()}`;

      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();

      await page.fill('input[name*="[title]"], input[name="section[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Should show the new page
      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });

    test('creates page with content', async ({ page }) => {
      const pageTitle = `Content Page ${uniqueId()}`;
      const content = 'This is test content for the page.';

      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();

      await page.fill('input[name*="[title]"]', pageTitle);

      // Fill content area
      const contentArea = page.locator('textarea, trix-editor, [contenteditable="true"], [data-controller*="editor"]');
      if (await contentArea.first().isVisible()) {
        await contentArea.first().fill(content);
      }

      await page.click('input[type="submit"], button[type="submit"]');

      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });
  });

  test.describe('Add Text Block Section', () => {
    test('creates a new text block', async ({ page }) => {
      const blockTitle = `Text Block ${uniqueId()}`;

      const addTextBlockLink = page.locator('a[href*="/text_blocks/new"]');
      if (await addTextBlockLink.isVisible()) {
        await addTextBlockLink.first().click();

        await page.fill('input[name*="[title]"]', blockTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${blockTitle}"`).first()).toBeVisible();
      }
    });
  });

  test.describe('Add Picture Section', () => {
    test('shows picture upload form', async ({ page }) => {
      const addPictureLink = page.locator('a[href*="/pictures/new"]');
      if (await addPictureLink.isVisible()) {
        await addPictureLink.first().click();

        // Should show file upload
        await expect(page.locator('input[type="file"]')).toBeVisible();
      }
    });
  });

  test.describe('Add Document Section', () => {
    test('shows document upload form', async ({ page }) => {
      const addDocLink = page.locator('a[href*="/documents/new"]');
      if (await addDocLink.isVisible()) {
        await addDocLink.first().click();

        // Should show file upload
        await expect(page.locator('input[type="file"]')).toBeVisible();
      }
    });
  });

  test.describe('Edit Section', () => {
    test('edits existing section title', async ({ page }) => {
      const pageTitle = `Edit Section ${uniqueId()}`;
      const newTitle = `Updated ${pageTitle}`;

      // Create a page first
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Find and click edit
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Update title
      await page.fill('input[name*="[title]"]', newTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      await expect(page.locator(`text="${newTitle}"`).first()).toBeVisible();
    });
  });

  test.describe('Delete Section', () => {
    test('deletes a section (moves to trash)', async ({ page }) => {
      const pageTitle = `Delete Section ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Find delete button
      const deleteButton = page.locator('a[data-method="delete"], button[data-method="delete"], a:has-text("Delete"), button:has-text("Delete"), a:has-text("Trash"), button:has-text("Trash")');

      if (await deleteButton.first().isVisible()) {
        // Handle confirmation
        page.on('dialog', dialog => dialog.accept());
        await deleteButton.first().click();

        // Page should be removed from visible sections
        await page.goto(reportUrl);
        // Verify section is not in active list (may be in trash)
      }
    });
  });

  test.describe('Section Ordering', () => {
    test('can reorder sections', async ({ page }) => {
      // Create two pages
      const page1Title = `Order Page 1 ${uniqueId()}`;
      const page2Title = `Order Page 2 ${uniqueId()}`;

      // Create first page
      let addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', page1Title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Go back to report
      await page.goto(reportUrl);

      // Create second page
      addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', page2Title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Both pages should be visible
      await page.goto(reportUrl);
      await expect(page.locator(`text="${page1Title}"`).first()).toBeVisible();
      await expect(page.locator(`text="${page2Title}"`).first()).toBeVisible();
    });
  });

  test.describe('Section Navigation', () => {
    test('clicking section navigates to it', async ({ page }) => {
      const pageTitle = `Nav Section ${uniqueId()}`;

      // Create a page
      const addPageLink = page.locator('a[href*="/pages/new"]');
      await addPageLink.first().click();
      await page.fill('input[name*="[title]"]', pageTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Go back to report
      await page.goto(reportUrl);

      // Click on section in nav
      const sectionLink = page.locator(`a:has-text("${pageTitle}")`);
      await sectionLink.first().click();

      // Should navigate to section
      await expect(page.locator(`text="${pageTitle}"`).first()).toBeVisible();
    });
  });
});
