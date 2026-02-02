import { test, expect } from '@playwright/test';
import { TEST_USERS, logout } from './helpers/test-helpers';

test.describe('Authentication', () => {
  test.describe('Login', () => {
    test.use({ storageState: { cookies: [], origins: [] } }); // Clear auth for these tests

    test('shows login page with email and password fields', async ({ page }) => {
      await page.goto('/session/new');

      await expect(page.locator('input[name="email_address"]')).toBeVisible();
      await expect(page.locator('input[name="password"]')).toBeVisible();
      await expect(page.locator('input[type="submit"], button[type="submit"]')).toBeVisible();
    });

    test('successfully logs in with valid credentials', async ({ page }) => {
      await page.goto('/session/new');

      await page.fill('input[name="email_address"]', TEST_USERS.admin.email);
      await page.fill('input[name="password"]', TEST_USERS.admin.password);
      await page.click('input[type="submit"], button[type="submit"]');

      // Should redirect to dashboard
      await expect(page).not.toHaveURL(/session\/new/);
      await expect(page).toHaveURL(/\/$|\/reports/);
    });

    test('shows error with invalid credentials', async ({ page }) => {
      await page.goto('/session/new');

      await page.fill('input[name="email_address"]', 'invalid@example.com');
      await page.fill('input[name="password"]', 'wrongpassword');
      await page.click('input[type="submit"], button[type="submit"]');

      // Should stay on login page or show error
      await expect(page.locator('text=/invalid|incorrect|error/i')).toBeVisible();
    });

    test('shows error with empty credentials', async ({ page }) => {
      await page.goto('/session/new');

      await page.click('input[type="submit"], button[type="submit"]');

      // Should show validation error or stay on page
      await expect(page).toHaveURL(/session/);
    });

    test('redirects to login when accessing protected page', async ({ page }) => {
      await page.goto('/reports/new');

      // Should redirect to login
      await expect(page).toHaveURL(/session\/new/);
    });
  });

  test.describe('Logout', () => {
    test('successfully logs out', async ({ page }) => {
      // Start logged in
      await page.goto('/');
      await expect(page).not.toHaveURL(/session\/new/);

      // Find and click logout
      const logoutLink = page.locator('a[href="/session"], form[action="/session"] button, a:has-text("Sign out"), button:has-text("Sign out")');
      await logoutLink.first().click();

      // Verify we're logged out - try to access protected page
      await page.goto('/reports/new');
      await expect(page).toHaveURL(/session\/new/);
    });
  });

  test.describe('Session persistence', () => {
    test('maintains session across page navigations', async ({ page }) => {
      await page.goto('/');
      await page.goto('/reports/new');
      await page.goto('/');

      // Should still be on protected pages (not redirected to login)
      await expect(page).not.toHaveURL(/session\/new/);
    });
  });
});
