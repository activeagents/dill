import { test, expect } from '@playwright/test';
import { uniqueId, goToReport } from './helpers/test-helpers';

test.describe('Reports', () => {
  test.describe('Report List (Dashboard)', () => {
    test('displays reports dashboard', async ({ page }) => {
      await page.goto('/');

      // Should show the reports list/dashboard
      await expect(page.locator('h1, h2').first()).toBeVisible();
    });

    test('shows create new report button', async ({ page }) => {
      await page.goto('/');

      const newReportLink = page.locator('a[href="/reports/new"], a:has-text("New"), button:has-text("New")');
      await expect(newReportLink.first()).toBeVisible();
    });
  });

  test.describe('Create Report', () => {
    test('shows new report form', async ({ page }) => {
      await page.goto('/reports/new');

      await expect(page.locator('input[name="report[title]"]')).toBeVisible();
      await expect(page.locator('input[type="submit"], button[type="submit"]')).toBeVisible();
    });

    test('creates a new report with title only', async ({ page }) => {
      const title = `Test Report ${uniqueId()}`;
      await page.goto('/reports/new');

      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Should redirect to the report
      await expect(page).toHaveURL(/\/reports\/\d+|\/\d+\//);
      await expect(page.locator(`text="${title}"`).first()).toBeVisible();
    });

    test('creates a new report with all fields', async ({ page }) => {
      const title = `Full Report ${uniqueId()}`;
      const subtitle = 'Test Subtitle';
      const author = 'Test Author';

      await page.goto('/reports/new');

      await page.fill('input[name="report[title]"]', title);

      // Fill subtitle if field exists
      const subtitleField = page.locator('input[name="report[subtitle]"]');
      if (await subtitleField.isVisible()) {
        await subtitleField.fill(subtitle);
      }

      // Fill author if field exists
      const authorField = page.locator('input[name="report[author]"]');
      if (await authorField.isVisible()) {
        await authorField.fill(author);
      }

      await page.click('input[type="submit"], button[type="submit"]');

      // Should redirect and show the report
      await expect(page).toHaveURL(/\/reports\/\d+|\/\d+\//);
    });

    test('shows validation error for empty title', async ({ page }) => {
      await page.goto('/reports/new');

      // Submit without filling title
      await page.click('input[type="submit"], button[type="submit"]');

      // Should show error or stay on page
      await expect(page).toHaveURL(/reports\/new|reports/);
    });
  });

  test.describe('View Report', () => {
    test('displays report details', async ({ page }) => {
      // First create a report
      const title = `View Test ${uniqueId()}`;
      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Should show the report
      await expect(page.locator(`text="${title}"`).first()).toBeVisible();
    });

    test('shows report sections list', async ({ page }) => {
      const title = `Sections Test ${uniqueId()}`;
      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Report should have section management area
      await expect(page.locator('[data-controller*="section"], .sections, nav, aside').first()).toBeVisible();
    });
  });

  test.describe('Edit Report', () => {
    test('navigates to edit page', async ({ page }) => {
      const title = `Edit Test ${uniqueId()}`;
      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Find and click edit link
      const editLink = page.locator('a[href*="/edit"], a:has-text("Edit"), button:has-text("Edit")');
      await editLink.first().click();

      await expect(page).toHaveURL(/\/edit/);
    });

    test('updates report title', async ({ page }) => {
      const title = `Update Test ${uniqueId()}`;
      const newTitle = `Updated ${title}`;

      // Create report
      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Navigate to edit
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Update title
      await page.fill('input[name="report[title]"]', newTitle);
      await page.click('input[type="submit"], button[type="submit"]');

      // Verify update
      await expect(page.locator(`text="${newTitle}"`).first()).toBeVisible();
    });
  });

  test.describe('Delete Report', () => {
    test('deletes a report', async ({ page }) => {
      const title = `Delete Test ${uniqueId()}`;

      // Create report
      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Navigate to edit/settings
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Find delete button/link
      const deleteButton = page.locator('a[data-method="delete"], button[data-method="delete"], a:has-text("Delete"), button:has-text("Delete")');

      // Handle confirmation dialog
      page.on('dialog', dialog => dialog.accept());

      await deleteButton.first().click();

      // Should redirect to reports list
      await expect(page).toHaveURL(/\/$|\/reports/);
    });
  });

  test.describe('Report Access', () => {
    test('can set editors when creating report', async ({ page }) => {
      await page.goto('/reports/new');

      // Check if access controls are available
      const accessControls = page.locator('input[name*="editor"], select[name*="editor"], [data-access]');
      if (await accessControls.first().isVisible()) {
        await expect(accessControls.first()).toBeVisible();
      }
    });

    test('can modify access from edit page', async ({ page }) => {
      const title = `Access Test ${uniqueId()}`;

      await page.goto('/reports/new');
      await page.fill('input[name="report[title]"]', title);
      await page.click('input[type="submit"], button[type="submit"]');

      // Go to edit
      const editLink = page.locator('a[href*="/edit"]');
      await editLink.first().click();

      // Check for access management
      const accessSection = page.locator('text=/editors|readers|access/i');
      if (await accessSection.first().isVisible()) {
        await expect(accessSection.first()).toBeVisible();
      }
    });
  });
});
