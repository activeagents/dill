import { Page, expect } from '@playwright/test';

/**
 * Test helper utilities for Dill E2E tests
 */

/**
 * Test users - matches db/seeds.rb and test/fixtures/users.yml
 * For E2E testing, we use the seeded user from db/seeds.rb
 * For test fixtures, use the fixture users
 */
export const TEST_USERS = {
  // Seeded user (from db/seeds.rb) - use for E2E tests against dev database
  admin: {
    email: 'justin@activeagents.ai',
    password: 'workshop',
    name: 'Justin',
    role: 'administrator'
  },
  // Fixture users (for reference - used in Rails test environment)
  fixtureAdmin: {
    email: 'david@37signals.com',
    password: 'secret123456',
    name: 'David',
    role: 'administrator'
  },
  fixtureEditor: {
    email: 'kevin@37signals.com',
    password: 'secret123456',
    name: 'Kevin',
    role: 'member'
  },
  fixtureReader: {
    email: 'jz@37signals.com',
    password: 'secret123456',
    name: 'JZ',
    role: 'member'
  }
};

export const TEST_ACCOUNT = {
  name: '37signals',
  // Join code from fixtures - may need to be created in dev DB
  joinCode: 'cs3s-enl1-EKC3'
};

/**
 * Login as a specific user
 */
export async function loginAs(page: Page, user: keyof typeof TEST_USERS) {
  const userData = TEST_USERS[user];
  await page.goto('/session/new');
  await page.fill('input[name="email_address"]', userData.email);
  await page.fill('input[name="password"]', userData.password);
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForURL(/\/$|\/reports/);
}

/**
 * Logout current user
 */
export async function logout(page: Page) {
  // Click logout button/link - adjust selector based on actual UI
  const logoutButton = page.locator('a[href="/session"], button:has-text("Sign out"), a:has-text("Sign out")');
  if (await logoutButton.isVisible()) {
    await logoutButton.click();
  } else {
    await page.goto('/session', { waitUntil: 'commit' });
    // If GET doesn't work, try DELETE method
    await page.request.delete('/session');
  }
}

/**
 * Create a new report
 */
export async function createReport(page: Page, options: {
  title: string;
  subtitle?: string;
  author?: string;
}) {
  await page.goto('/reports/new');
  await page.fill('input[name="report[title]"]', options.title);
  if (options.subtitle) {
    await page.fill('input[name="report[subtitle]"]', options.subtitle);
  }
  if (options.author) {
    await page.fill('input[name="report[author]"]', options.author);
  }
  await page.click('input[type="submit"], button[type="submit"]');
  await page.waitForURL(/\/reports\/\d+|\/\d+\//);
}

/**
 * Navigate to a report by title
 */
export async function goToReport(page: Page, title: string) {
  await page.goto('/');
  await page.click(`a:has-text("${title}")`);
}

/**
 * Add a section to current report
 */
export async function addSection(page: Page, type: 'page' | 'text_block' | 'picture' | 'document' | 'finding', options: {
  title?: string;
  content?: string;
}) {
  // Click add section button
  const addButton = page.locator('a[href*="/pages/new"], a[href*="/text_blocks/new"], a[href*="/pictures/new"], a[href*="/documents/new"], a[href*="/findings/new"], button:has-text("Add")');

  if (type === 'page') {
    await page.click(`a[href*="/pages/new"]`);
  } else if (type === 'text_block') {
    await page.click(`a[href*="/text_blocks/new"]`);
  } else if (type === 'finding') {
    await page.click(`a[href*="/findings/new"]`);
  }

  // Fill in section details
  if (options.title) {
    await page.fill('input[name*="[title]"]', options.title);
  }
  if (options.content) {
    const contentField = page.locator('textarea, [contenteditable="true"], trix-editor');
    await contentField.fill(options.content);
  }

  // Submit
  await page.click('input[type="submit"], button[type="submit"]');
}

/**
 * Wait for turbo stream update
 */
export async function waitForTurboStream(page: Page) {
  await page.waitForResponse(response =>
    response.headers()['content-type']?.includes('turbo-stream')
  );
}

/**
 * Generate a unique test identifier
 */
export function uniqueId(prefix = 'test'): string {
  return `${prefix}_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
}

/**
 * Fill in a markdown/rich text editor
 */
export async function fillMarkdownEditor(page: Page, content: string) {
  // Try different editor types
  const trixEditor = page.locator('trix-editor');
  const housemd = page.locator('[data-controller="house-md"]');
  const textarea = page.locator('textarea[name*="body"], textarea[name*="content"]');
  const contentEditable = page.locator('[contenteditable="true"]');

  if (await trixEditor.isVisible()) {
    await trixEditor.fill(content);
  } else if (await housemd.isVisible()) {
    await housemd.locator('textarea, [contenteditable="true"]').fill(content);
  } else if (await textarea.isVisible()) {
    await textarea.fill(content);
  } else if (await contentEditable.isVisible()) {
    await contentEditable.fill(content);
  }
}

/**
 * Click AI action button
 */
export async function clickAIAction(page: Page, action: 'improve' | 'grammar' | 'style' | 'summarize' | 'expand' | 'brainstorm') {
  await page.click(`button[data-action*="${action}"], a[data-action*="${action}"], [data-ai-action="${action}"]`);
}

/**
 * Wait for AI streaming response to complete
 */
export async function waitForAIResponse(page: Page, timeout = 30000) {
  // Wait for streaming to start
  await page.waitForSelector('[data-streaming="true"], .streaming, [data-ai-response]', { timeout: 10000 });

  // Wait for streaming to complete
  await page.waitForFunction(() => {
    const streaming = document.querySelector('[data-streaming="true"], .streaming');
    return !streaming;
  }, { timeout });
}
