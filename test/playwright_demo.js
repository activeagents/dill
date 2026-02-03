/**
 * Playwright Demo Script for Agent PDF Referencing Tests
 *
 * This script demonstrates the E2E test flow for PDF referencing with context fragments.
 * Run with: npx playwright test test/playwright_demo.js
 *
 * Note: This requires the Rails server to be running on localhost:3000
 */

const { test, expect } = require('@playwright/test');

// Base URL for the Rails app (adjust if needed)
const BASE_URL = process.env.BASE_URL || 'http://localhost:3000';

test.describe('Agent PDF Referencing E2E Tests', () => {

  test.beforeEach(async ({ page }) => {
    // Take screenshot of initial state
    await page.goto(BASE_URL);
    await page.screenshot({ path: '/tmp/playwright-mcp-output/01_initial_page.png' });
  });

  test('should sign in and navigate to page editor', async ({ page }) => {
    // Go to sign in page
    await page.goto(`${BASE_URL}/session/new`);
    await page.screenshot({ path: '/tmp/playwright-mcp-output/02_sign_in_page.png' });

    // Fill in credentials
    await page.fill('input[name="email_address"]', 'kevin@37signals.com');
    await page.fill('input[name="password"]', 'secret123456');
    await page.screenshot({ path: '/tmp/playwright-mcp-output/03_credentials_filled.png' });

    // Submit login form
    await page.click('button[type="submit"], input[type="submit"], #log_in');
    await page.waitForNavigation({ waitUntil: 'networkidle' });
    await page.screenshot({ path: '/tmp/playwright-mcp-output/04_logged_in.png' });

    // Navigate to reports
    await expect(page.locator('h2')).toContainText('Handbook');
  });

  test('should open AI assistant and trigger research with PDF URL', async ({ page }) => {
    // Sign in first
    await page.goto(`${BASE_URL}/session/new`);
    await page.fill('input[name="email_address"]', 'kevin@37signals.com');
    await page.fill('input[name="password"]', 'secret123456');
    await page.click('button[type="submit"], input[type="submit"], #log_in');
    await page.waitForNavigation({ waitUntil: 'networkidle' });

    // Navigate to a page editor (adjust URL based on your routes)
    // This assumes /reports/1/pages/1/edit exists
    await page.goto(`${BASE_URL}/reports/1/pages/1/edit`);
    await page.screenshot({ path: '/tmp/playwright-mcp-output/05_page_editor.png' });

    // Look for AI assistant button (Research button)
    const researchButton = page.locator('button:has-text("Research")');
    if (await researchButton.isVisible()) {
      await researchButton.click();
      await page.screenshot({ path: '/tmp/playwright-mcp-output/06_ai_modal_open.png' });

      // Fill in research topic with PDF URL
      const topicInput = page.locator('input[type="text"], textarea').first();
      await topicInput.fill('Summarize findings from https://example.com/research-paper.pdf');
      await page.screenshot({ path: '/tmp/playwright-mcp-output/07_research_topic_filled.png' });
    }
  });

  test('should upload PDF document', async ({ page }) => {
    // Sign in
    await page.goto(`${BASE_URL}/session/new`);
    await page.fill('input[name="email_address"]', 'kevin@37signals.com');
    await page.fill('input[name="password"]', 'secret123456');
    await page.click('button[type="submit"], input[type="submit"], #log_in');
    await page.waitForNavigation({ waitUntil: 'networkidle' });

    // Navigate to new document page (adjust URL based on your routes)
    await page.goto(`${BASE_URL}/reports/1/documents/new`);
    await page.screenshot({ path: '/tmp/playwright-mcp-output/08_new_document_page.png' });

    // Look for file input
    const fileInput = page.locator('input[type="file"]');
    if (await fileInput.isVisible()) {
      // Note: In real test, you'd upload an actual file
      await page.screenshot({ path: '/tmp/playwright-mcp-output/09_file_upload_ready.png' });
    }
  });

  test('should show AI modal with content improvement', async ({ page }) => {
    // Sign in
    await page.goto(`${BASE_URL}/session/new`);
    await page.fill('input[name="email_address"]', 'kevin@37signals.com');
    await page.fill('input[name="password"]', 'secret123456');
    await page.click('button[type="submit"], input[type="submit"], #log_in');
    await page.waitForNavigation({ waitUntil: 'networkidle' });

    // Navigate to page editor
    await page.goto(`${BASE_URL}/reports/1/pages/1/edit`);
    await page.screenshot({ path: '/tmp/playwright-mcp-output/10_editor_for_improve.png' });

    // Look for Improve button
    const improveButton = page.locator('button:has-text("Improve")');
    if (await improveButton.isVisible()) {
      await improveButton.click();
      await page.waitForSelector('.ai-modal', { state: 'visible', timeout: 5000 });
      await page.screenshot({ path: '/tmp/playwright-mcp-output/11_improve_modal.png' });
    }
  });

  test('should display references panel', async ({ page }) => {
    // Sign in
    await page.goto(`${BASE_URL}/session/new`);
    await page.fill('input[name="email_address"]', 'kevin@37signals.com');
    await page.fill('input[name="password"]', 'secret123456');
    await page.click('button[type="submit"], input[type="submit"], #log_in');
    await page.waitForNavigation({ waitUntil: 'networkidle' });

    // Navigate to page editor
    await page.goto(`${BASE_URL}/reports/1/pages/1/edit`);

    // Look for references panel toggle
    const referencesButton = page.locator('[data-action*="references"], button:has-text("References")');
    if (await referencesButton.isVisible()) {
      await referencesButton.click();
      await page.waitForSelector('.references-panel', { state: 'visible', timeout: 5000 });
      await page.screenshot({ path: '/tmp/playwright-mcp-output/12_references_panel.png' });
    }
  });
});
