import { test as setup, expect } from '@playwright/test';
import { TEST_USERS } from './helpers/test-helpers';

const authFile = 'playwright/.auth/user.json';

setup('authenticate', async ({ page }) => {
  // Navigate to login page
  await page.goto('/session/new');

  // Fill in credentials (from db/seeds.rb)
  await page.fill('input[name="email_address"]', TEST_USERS.admin.email);
  await page.fill('input[name="password"]', TEST_USERS.admin.password);

  // Submit login form
  await page.click('#log_in, button[type="submit"]');

  // Wait for redirect to dashboard/reports
  await page.waitForURL(/\/$|\/reports/, { timeout: 10000 });

  // Verify we're logged in
  await expect(page).not.toHaveURL(/session\/new/);

  // Save the authentication state
  await page.context().storageState({ path: authFile });
});
