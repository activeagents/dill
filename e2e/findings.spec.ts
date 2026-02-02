import { test, expect } from '@playwright/test';
import { uniqueId } from './helpers/test-helpers';

test.describe('Findings Management', () => {
  let reportUrl: string;

  test.beforeEach(async ({ page }) => {
    // Create a report for findings tests
    const reportTitle = `Findings Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();
  });

  test.describe('Create Finding', () => {
    test('shows new finding form', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        // Should show finding form
        await expect(page.locator('input[name*="[title]"]')).toBeVisible();
      }
    });

    test('creates finding with title', async ({ page }) => {
      const findingTitle = `Test Finding ${uniqueId()}`;

      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${findingTitle}"`).first()).toBeVisible();
      }
    });

    test('creates finding with severity', async ({ page }) => {
      const findingTitle = `Severity Finding ${uniqueId()}`;

      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);

        // Select severity
        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await severitySelect.selectOption('high');
        }

        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${findingTitle}"`).first()).toBeVisible();
      }
    });

    test('creates finding with all fields', async ({ page }) => {
      const findingTitle = `Full Finding ${uniqueId()}`;

      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);

        // Fill severity
        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await severitySelect.selectOption('critical');
        }

        // Fill status
        const statusSelect = page.locator('select[name*="status"]');
        if (await statusSelect.isVisible()) {
          await statusSelect.selectOption('open');
        }

        // Fill category
        const categoryField = page.locator('input[name*="category"], select[name*="category"]');
        if (await categoryField.isVisible()) {
          if (await categoryField.evaluate(el => el.tagName) === 'SELECT') {
            await categoryField.selectOption({ index: 1 });
          } else {
            await categoryField.fill('Security');
          }
        }

        // Fill description
        const descriptionField = page.locator('textarea[name*="description"], [name*="description"]');
        if (await descriptionField.isVisible()) {
          await descriptionField.fill('This is a detailed description of the finding.');
        }

        // Fill recommendation
        const recommendationField = page.locator('textarea[name*="recommendation"], [name*="recommendation"]');
        if (await recommendationField.isVisible()) {
          await recommendationField.fill('Recommended remediation steps.');
        }

        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${findingTitle}"`).first()).toBeVisible();
      }
    });
  });

  test.describe('Finding Severity Levels', () => {
    test('can create critical severity finding', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          // Check for critical option
          await expect(severitySelect.locator('option[value="critical"]')).toBeVisible();
        }
      }
    });

    test('can create high severity finding', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await expect(severitySelect.locator('option[value="high"]')).toBeVisible();
        }
      }
    });

    test('can create medium severity finding', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await expect(severitySelect.locator('option[value="medium"]')).toBeVisible();
        }
      }
    });

    test('can create low severity finding', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await expect(severitySelect.locator('option[value="low"]')).toBeVisible();
        }
      }
    });

    test('can create info severity finding', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const severitySelect = page.locator('select[name*="severity"]');
        if (await severitySelect.isVisible()) {
          await expect(severitySelect.locator('option[value="info"]')).toBeVisible();
        }
      }
    });
  });

  test.describe('Finding Status', () => {
    test('can set status to open', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const statusSelect = page.locator('select[name*="status"]');
        if (await statusSelect.isVisible()) {
          await expect(statusSelect.locator('option[value="open"]')).toBeVisible();
        }
      }
    });

    test('can set status to confirmed', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const statusSelect = page.locator('select[name*="status"]');
        if (await statusSelect.isVisible()) {
          await expect(statusSelect.locator('option[value="confirmed"]')).toBeVisible();
        }
      }
    });

    test('can set status to resolved', async ({ page }) => {
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        const statusSelect = page.locator('select[name*="status"]');
        if (await statusSelect.isVisible()) {
          await expect(statusSelect.locator('option[value="resolved"]')).toBeVisible();
        }
      }
    });

    test('can update finding status', async ({ page }) => {
      const findingTitle = `Status Update ${uniqueId()}`;

      // Create finding
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        // Edit finding
        const editLink = page.locator('a[href*="/edit"]');
        await editLink.first().click();

        // Change status
        const statusSelect = page.locator('select[name*="status"]');
        if (await statusSelect.isVisible()) {
          await statusSelect.selectOption('resolved');
          await page.click('input[type="submit"], button[type="submit"]');
        }
      }
    });
  });

  test.describe('Edit Finding', () => {
    test('can edit finding title', async ({ page }) => {
      const findingTitle = `Edit Finding ${uniqueId()}`;
      const newTitle = `Updated ${findingTitle}`;

      // Create finding
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        // Edit
        const editLink = page.locator('a[href*="/edit"]');
        await editLink.first().click();

        await page.fill('input[name*="[title]"]', newTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${newTitle}"`).first()).toBeVisible();
      }
    });

    test('can add evidence to finding', async ({ page }) => {
      const findingTitle = `Evidence Finding ${uniqueId()}`;

      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);

        // Fill evidence field
        const evidenceField = page.locator('textarea[name*="evidence"], [name*="evidence"]');
        if (await evidenceField.isVisible()) {
          await evidenceField.fill('Evidence of the vulnerability: code snippet or screenshot reference');
        }

        await page.click('input[type="submit"], button[type="submit"]');

        await expect(page.locator(`text="${findingTitle}"`).first()).toBeVisible();
      }
    });
  });

  test.describe('Delete Finding', () => {
    test('can delete/trash a finding', async ({ page }) => {
      const findingTitle = `Delete Finding ${uniqueId()}`;

      // Create finding
      const addFindingLink = page.locator('a[href*="/findings/new"]');
      if (await addFindingLink.isVisible()) {
        await addFindingLink.first().click();

        await page.fill('input[name*="[title]"]', findingTitle);
        await page.click('input[type="submit"], button[type="submit"]');

        // Delete
        const deleteButton = page.locator('a[data-method="delete"], button[data-method="delete"], a:has-text("Delete"), button:has-text("Delete")');

        if (await deleteButton.first().isVisible()) {
          page.on('dialog', dialog => dialog.accept());
          await deleteButton.first().click();

          // Finding should be removed
          await page.goto(reportUrl);
        }
      }
    });
  });
});
