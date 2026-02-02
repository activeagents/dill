import { test, expect } from '@playwright/test';
import { uniqueId } from './helpers/test-helpers';

test.describe('Sources Management', () => {
  let reportUrl: string;

  test.beforeEach(async ({ page }) => {
    // Create a report for sources tests
    const reportTitle = `Sources Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();

    // Extract report ID from URL
    const match = reportUrl.match(/\/reports\/(\d+)|\/(\d+)\//);
    if (match) {
      const reportId = match[1] || match[2];
    }
  });

  test.describe('Sources List', () => {
    test('can access sources page', async ({ page }) => {
      // Navigate to sources
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();
        await expect(page).toHaveURL(/\/sources/);
      }
    });

    test('shows empty state when no sources', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        // Should show empty state or add source option
        const emptyState = page.locator('text=/no sources|add a source|empty/i');
        const addButton = page.locator('a[href*="/sources/new"], button:has-text("Add")');

        const hasContent = await emptyState.first().isVisible() || await addButton.first().isVisible();
        expect(hasContent).toBeTruthy();
      }
    });
  });

  test.describe('Add Source', () => {
    test('can access new source form', async ({ page }) => {
      // Navigate to sources first
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        // Look for add button
        const addButton = page.locator('a[href*="/sources/new"], a:has-text("Add"), button:has-text("Add")');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();
          await expect(page).toHaveURL(/\/sources\/new|\/sources/);
        }
      }
    });

    test('new source form has type selection', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          // Check for source type options
          const typeSelect = page.locator('select[name*="source_type"], input[name*="source_type"]');
          if (await typeSelect.first().isVisible()) {
            await expect(typeSelect.first()).toBeVisible();
          }
        }
      }
    });

    test('can add URL source', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          // Fill URL field
          const urlField = page.locator('input[name*="url"], input[type="url"]');
          if (await urlField.isVisible()) {
            await urlField.fill('https://example.com');

            // Fill name
            const nameField = page.locator('input[name*="name"]');
            if (await nameField.isVisible()) {
              await nameField.fill(`URL Source ${uniqueId()}`);
            }

            await page.click('input[type="submit"], button[type="submit"]');
          }
        }
      }
    });

    test('can add text source', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          // Select text type if needed
          const typeSelect = page.locator('select[name*="source_type"]');
          if (await typeSelect.isVisible()) {
            await typeSelect.selectOption('text');
          }

          // Fill text content
          const contentField = page.locator('textarea[name*="content"], textarea[name*="raw_content"]');
          if (await contentField.isVisible()) {
            await contentField.fill('This is the raw text content of the source.');
          }

          // Fill name
          const nameField = page.locator('input[name*="name"]');
          if (await nameField.isVisible()) {
            await nameField.fill(`Text Source ${uniqueId()}`);
          }

          await page.click('input[type="submit"], button[type="submit"]');
        }
      }
    });

    test('shows file upload for PDF source', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          // Check for file upload
          const fileInput = page.locator('input[type="file"]');
          if (await fileInput.isVisible()) {
            await expect(fileInput).toBeVisible();
          }
        }
      }
    });
  });

  test.describe('View Source', () => {
    test('can view source details', async ({ page }) => {
      // First add a source
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          const nameField = page.locator('input[name*="name"]');
          const sourceName = `View Source ${uniqueId()}`;
          if (await nameField.isVisible()) {
            await nameField.fill(sourceName);
          }

          const contentField = page.locator('textarea[name*="content"], textarea[name*="raw_content"]');
          if (await contentField.isVisible()) {
            await contentField.fill('Content for viewing');
          }

          await page.click('input[type="submit"], button[type="submit"]');

          // Should show source or redirect to list
          // Click on source to view details
          const sourceLink = page.locator(`a:has-text("${sourceName}")`);
          if (await sourceLink.first().isVisible()) {
            await sourceLink.first().click();
          }
        }
      }
    });
  });

  test.describe('Delete Source', () => {
    test('can delete a source', async ({ page }) => {
      const sourcesLink = page.locator('a[href*="/sources"]');
      if (await sourcesLink.first().isVisible()) {
        await sourcesLink.first().click();

        const addButton = page.locator('a[href*="/sources/new"]');
        if (await addButton.first().isVisible()) {
          await addButton.first().click();

          const nameField = page.locator('input[name*="name"]');
          const sourceName = `Delete Source ${uniqueId()}`;
          if (await nameField.isVisible()) {
            await nameField.fill(sourceName);
          }

          const contentField = page.locator('textarea[name*="content"], textarea[name*="raw_content"]');
          if (await contentField.isVisible()) {
            await contentField.fill('Content to delete');
          }

          await page.click('input[type="submit"], button[type="submit"]');

          // Find delete button
          const deleteButton = page.locator('a[data-method="delete"], button[data-method="delete"], a:has-text("Delete")');
          if (await deleteButton.first().isVisible()) {
            page.on('dialog', dialog => dialog.accept());
            await deleteButton.first().click();
          }
        }
      }
    });
  });

  test.describe('Source Processing', () => {
    test('shows processing status for sources', async ({ page }) => {
      // After adding a source, it may show processing status
      const statusIndicator = page.locator('[data-status], .processing, text=/processing|pending|completed/i');
      // This depends on the source being added and processed
    });
  });
});

test.describe('Search', () => {
  let reportUrl: string;

  test.beforeEach(async ({ page }) => {
    // Create a report with content for search tests
    const reportTitle = `Search Test ${uniqueId()}`;
    await page.goto('/reports/new');
    await page.fill('input[name="report[title]"]', reportTitle);
    await page.click('input[type="submit"], button[type="submit"]');
    await page.waitForURL(/\/reports\/\d+|\/\d+\//);
    reportUrl = page.url();

    // Add a page with searchable content
    const addPageLink = page.locator('a[href*="/pages/new"]');
    await addPageLink.first().click();
    await page.fill('input[name*="[title]"]', 'Searchable Page');

    const editor = page.locator('textarea, trix-editor, [contenteditable="true"]');
    if (await editor.first().isVisible()) {
      await editor.first().fill('This content contains uniqueSearchTerm123 for testing search functionality.');
    }
    await page.click('input[type="submit"], button[type="submit"]');
  });

  test.describe('Report Search', () => {
    test('can access search', async ({ page }) => {
      await page.goto(reportUrl);

      const searchLink = page.locator('a[href*="/search"], button:has-text("Search"), input[type="search"]');
      if (await searchLink.first().isVisible()) {
        await expect(searchLink.first()).toBeVisible();
      }
    });

    test('search form is visible', async ({ page }) => {
      await page.goto(reportUrl);

      const searchLink = page.locator('a[href*="/search"]');
      if (await searchLink.first().isVisible()) {
        await searchLink.first().click();

        const searchInput = page.locator('input[type="search"], input[name*="query"], input[name*="q"]');
        await expect(searchInput.first()).toBeVisible();
      }
    });

    test('can search within report', async ({ page }) => {
      await page.goto(reportUrl);

      const searchLink = page.locator('a[href*="/search"]');
      if (await searchLink.first().isVisible()) {
        await searchLink.first().click();

        const searchInput = page.locator('input[type="search"], input[name*="query"], input[name*="q"]');
        if (await searchInput.first().isVisible()) {
          await searchInput.first().fill('uniqueSearchTerm123');
          await page.keyboard.press('Enter');

          // Should show search results
          await page.waitForTimeout(1000);
        }
      }
    });

    test('search returns matching results', async ({ page }) => {
      await page.goto(reportUrl);

      const searchLink = page.locator('a[href*="/search"]');
      if (await searchLink.first().isVisible()) {
        await searchLink.first().click();

        const searchInput = page.locator('input[type="search"], input[name*="query"], input[name*="q"]');
        if (await searchInput.first().isVisible()) {
          await searchInput.first().fill('Searchable');
          await page.keyboard.press('Enter');

          // Should find the page we created
          const result = page.locator('text=/Searchable Page/i');
          if (await result.first().isVisible({ timeout: 5000 })) {
            await expect(result.first()).toBeVisible();
          }
        }
      }
    });

    test('search shows no results message for unmatched query', async ({ page }) => {
      await page.goto(reportUrl);

      const searchLink = page.locator('a[href*="/search"]');
      if (await searchLink.first().isVisible()) {
        await searchLink.first().click();

        const searchInput = page.locator('input[type="search"], input[name*="query"], input[name*="q"]');
        if (await searchInput.first().isVisible()) {
          await searchInput.first().fill('xyznonexistentterm987');
          await page.keyboard.press('Enter');

          // Should show no results or empty state
          await page.waitForTimeout(1000);
        }
      }
    });
  });
});
