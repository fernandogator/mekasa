/**
 * Layout tests for every desktop screen (UI-007; guardrail rule 9).
 *
 * Satisfies: UI-007 (Desktop Web App)
 * Acceptance criteria: AC1–AC10, AC13, AC14
 * Designs: design/exports/superdesign/desktop/01–08
 *
 * Each test asserts the structure through roles first, then compares a
 * screenshot with design/baselines/web/ at 15% tolerance.
 */

import { expect, type Page, test } from '@playwright/test';

import { useFixtures } from './fixtures';

const SIZES = [
  { name: '1280', width: 1280, height: 800 },
  { name: '1920', width: 1920, height: 1080 },
] as const;

async function heading(page: Page, title: string) {
  await expect(page.getByRole('heading', { level: 1, name: title })).toBeVisible();
  await expect(page.getByRole('complementary', { name: 'Main' })).toBeVisible();
}

for (const size of SIZES) {
  test.describe(`${size.width}x${size.height}`, () => {
    test.use({ viewport: { width: size.width, height: size.height } });

    test('sign in (AC1, AC4)', async ({ page }) => {
      await useFixtures(page, { signedOut: true });
      await page.goto('/');
      await expect(page.getByRole('heading', { name: 'Welcome back' })).toBeVisible();
      await expect(page.getByRole('button', { name: /google/i })).toBeVisible();
      await expect(page.getByRole('textbox', { name: /email/i })).toHaveValue('leo@example.com');
      await expect(page).toHaveScreenshot(`SignIn_${size.name}.png`);
    });

    test('dashboard (AC5)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/');
      await heading(page, 'Dashboard');
      await expect(page.getByRole('heading', { name: 'The Rodriguez Home' })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Add Item' })).toBeVisible();
      await expect(page.getByRole('button', { name: 'Scan hauls' })).toBeVisible();
      await expect(page.getByText('Ice Cream').first()).toBeVisible();
      await expect(page).toHaveScreenshot(`Dashboard_${size.name}.png`, { fullPage: true });
    });

    test('inventory (AC6)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/inventory');
      await heading(page, 'Inventory');
      await expect(page.getByRole('group', { name: 'Categories' })).toBeVisible();
      await expect(page.getByText('Honeycrisp Apples')).toBeVisible();
      await expect(page).toHaveScreenshot(`Inventory_${size.name}.png`, { fullPage: true });
    });

    test('item detail (AC6)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/inventory/inv-1');
      await expect(page.getByRole('textbox', { name: 'Product name' })).toHaveValue('Whole Milk');
      await expect(page.getByText('041303001486')).toBeVisible();
      await expect(page).toHaveScreenshot(`ItemDetail_${size.name}.png`);
    });

    test('shopping list (AC7)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/shopping');
      await heading(page, 'Shopping List');
      await expect(page.getByRole('form', { name: 'Add to the list' })).toBeVisible();
      await expect(page.getByRole('heading', { level: 2, name: 'Dairy' })).toBeVisible();
      await expect(page).toHaveScreenshot(`ShoppingList_${size.name}.png`, { fullPage: true });
    });

    test('spending (AC8)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/spending');
      await heading(page, 'Spending');
      await expect(page.getByRole('tablist', { name: 'Period' })).toBeVisible();
      await expect(page.getByRole('img', { name: 'Spending trend' })).toBeVisible();
      await expect(page).toHaveScreenshot(`Spending_${size.name}.png`, { fullPage: true });
    });

    test('members (AC9)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/members');
      await heading(page, 'Family Members');
      await expect(page.getByText('Maya Rodriguez').first()).toBeVisible();
      await expect(page.getByText('Grandma Rosa')).toBeVisible();
      await expect(page).toHaveScreenshot(`Members_${size.name}.png`, { fullPage: true });
    });

    test('settings (AC13, AC14, AC18)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/settings');
      await heading(page, 'Settings');
      await expect(page.getByRole('radiogroup', { name: 'Theme' })).toBeVisible();
      await expect(page).toHaveScreenshot(`Settings_${size.name}.png`, { fullPage: true });
    });

    test('receipt review (AC10)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/');
      await page.getByRole('button', { name: 'Scan hauls' }).click();
      const dialog = page.getByTestId('receipt-dialog');
      await dialog.getByRole('tab', { name: 'Paste text' }).click();
      await dialog.getByRole('textbox').fill('H-E-B\nHEB WHL MILK GAL 4.29');
      await dialog.getByRole('button', { name: 'Read receipt' }).click();
      await expect(dialog.getByText('H-E-B · 3 lines · 2 matched · 1 need review')).toBeVisible();
      await expect(dialog.getByRole('button', { name: 'Save 3 items to inventory' })).toBeVisible();
      await expect(page).toHaveScreenshot(`ReceiptReview_${size.name}.png`);
    });
  });
}

test.describe('roles and themes', () => {
  test.use({ viewport: { width: 1280, height: 800 } });

  test('teen sees requests instead of purchase controls (AC2, AC7)', async ({ page }) => {
    await useFixtures(page, { uid: 'teen-1' });
    await page.goto('/shopping');
    await heading(page, 'Shopping List');
    await expect(page.getByText('Only household owners can mark items purchased.')).toBeVisible();
    await expect(page.getByRole('button', { name: /approve/i })).toHaveCount(0);
    await expect(page).toHaveScreenshot('ShoppingListTeen_1280.png', { fullPage: true });
  });

  test('switching theme changes the computed colors (AC13)', async ({ page }) => {
    await useFixtures(page);
    await page.goto('/settings');
    await heading(page, 'Settings');
    const background = () => page.evaluate(() => getComputedStyle(document.body).backgroundColor);
    const light = await background();
    await page.getByRole('radio', { name: /dark/i }).click();
    await expect(page.locator('html')).toHaveAttribute('data-theme', 'grounded-dark');
    expect(await background()).not.toBe(light);
    await expect(page).toHaveScreenshot('SettingsDark_1280.png', { fullPage: true });
  });

  test('empty household shows guidance instead of blank panels', async ({ page }) => {
    await useFixtures(page, { empty: true });
    await page.goto('/inventory');
    await expect(page.getByText('Nothing in the house yet')).toBeVisible();
  });
});
