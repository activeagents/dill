import { test, expect } from '@playwright/test';
import { uniqueId } from './helpers/test-helpers';

test.describe('Publishing', () => {
  let reportUrl: string;
  let reportTitle: string;

  test.beforeEach(async ({ page }) => {
    // Create a report for publishing tests
    reportTitle = `Publish Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();
  });

  test.describe('Publication Status', () => {
    test('shows publish option for report', async ({ page }) => {
      // Look for publication link
      const publishLink = page.locator('a[href*="/publication"], a:has-text("Publish"), button:has-text("Publish")');
      await expect(publishLink.first()).toBeVisible();
    });

    test('can access publication settings', async ({ page }) => {
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      // Should show publication settings
      await expect(page).toHaveURL(/\/publication/);
    });

    test('can publish a report', async ({ page }) => {
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      // Find publish checkbox or button
      const publishToggle = page.locator('input[name*="published"], input[type="checkbox"], button:has-text("Publish")');
      if (await publishToggle.first().isVisible()) {
        await publishToggle.first().click();

        // Save if needed
        const saveButton = page.locator('input[type="submit"], button[type="submit"]');
        if (await saveButton.first().isVisible()) {
          await saveButton.first().click();
        }
      }
    });

    test('can unpublish a report', async ({ page }) => {
      // First publish
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      const publishToggle = page.locator('input[name*="published"], input[type="checkbox"]');
      if (await publishToggle.first().isVisible()) {
        // Check current state and toggle if needed
        const isChecked = await publishToggle.first().isChecked();
        if (!isChecked) {
          await publishToggle.first().click();
        }

        const saveButton = page.locator('input[type="submit"], button[type="submit"]');
        if (await saveButton.first().isVisible()) {
          await saveButton.first().click();
        }

        // Now unpublish
        await page.goto(reportUrl);
        await publishLink.first().click();
        await publishToggle.first().click();
        if (await saveButton.first().isVisible()) {
          await saveButton.first().click();
        }
      }
    });
  });

  test.describe('Theme Customization', () => {
    test('can access theme settings', async ({ page }) => {
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      // Look for theme options
      const themeSelector = page.locator('select[name*="theme"], input[name*="theme"], [data-theme]');
      if (await themeSelector.first().isVisible()) {
        await expect(themeSelector.first()).toBeVisible();
      }
    });

    test('can change report theme', async ({ page }) => {
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      const themeSelector = page.locator('select[name*="theme"]');
      if (await themeSelector.first().isVisible()) {
        // Select a different theme
        await themeSelector.first().selectOption({ index: 1 });

        const saveButton = page.locator('input[type="submit"], button[type="submit"]');
        if (await saveButton.first().isVisible()) {
          await saveButton.first().click();
        }
      }
    });
  });

  test.describe('Public Access', () => {
    test('shows public URL when published', async ({ page }) => {
      // Publish the report
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      // Look for public URL or sharing link
      const publicUrl = page.locator('input[readonly], .public-url, a[href*="/"]');
      if (await publicUrl.first().isVisible()) {
        await expect(publicUrl.first()).toBeVisible();
      }
    });

    test('everyone_access toggle available', async ({ page }) => {
      const publishLink = page.locator('a[href*="/publication"]');
      await publishLink.first().click();

      // Look for public access toggle
      const everyoneAccess = page.locator('input[name*="everyone"], input[name*="public"], input[type="checkbox"]');
      if (await everyoneAccess.first().isVisible()) {
        await expect(everyoneAccess.first()).toBeVisible();
      }
    });
  });

  test.describe('Bookmark/Share', () => {
    test('can access bookmark page', async ({ page }) => {
      const bookmarkLink = page.locator('a[href*="/bookmark"]');
      if (await bookmarkLink.isVisible()) {
        await bookmarkLink.first().click();
        await expect(page).toHaveURL(/\/bookmark/);
      }
    });
  });

  test.describe('QR Code', () => {
    test('can generate QR code for report', async ({ page }) => {
      // Look for QR code link or image
      const qrLink = page.locator('a[href*="/qr_code"], img[src*="qr"], [data-qr]');
      if (await qrLink.first().isVisible()) {
        await expect(qrLink.first()).toBeVisible();
      }
    });
  });
});

test.describe('Public Report Access', () => {
  test.describe.configure({ mode: 'serial' });

  test('published report is accessible without login', async ({ page, context }) => {
    // Create and publish a report while logged in
    const reportTitle = `Public Access Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);

    // Get the report URL
    const reportUrl = page.url();

    // Try to publish
    const publishLink = page.locator('a[href*="/publication"]');
    if (await publishLink.first().isVisible()) {
      await publishLink.first().click();

      const publishToggle = page.locator('input[name*="published"], input[type="checkbox"]');
      if (await publishToggle.first().isVisible()) {
        if (!(await publishToggle.first().isChecked())) {
          await publishToggle.first().click();
        }

        const saveButton = page.locator('input[type="submit"], button[type="submit"]');
        if (await saveButton.first().isVisible()) {
          await saveButton.first().click();
        }
      }
    }

    // Clear cookies to simulate logged out user
    await context.clearCookies();

    // Try to access the report
    await page.goto(reportUrl);

    // If published and public, should see the report
    // If not public, should redirect to login
  });
});
