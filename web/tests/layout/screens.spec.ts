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
      await expect(page.getByRole('tab', { name: 'H-E-B 2' })).toBeVisible();
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

    test('store picker (AC19)', async ({ page }) => {
      await useFixtures(page);
      await page.goto('/settings');
      await page.getByRole('button', { name: 'Change stores' }).click();
      const dialog = page.getByTestId('store-picker');
      await expect(dialog.getByRole('heading', { name: 'Where do you shop?' })).toBeVisible();
      await expect(dialog.getByRole('checkbox', { name: /H-E-B/ })).toHaveAttribute('aria-checked', 'true');
      await expect(dialog.getByRole('checkbox', { name: /Target/ })).toHaveAttribute('aria-checked', 'false');
      await expect(page).toHaveScreenshot(`StorePicker_${size.name}.png`);
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

  test('owner picks stores; confirming saves them to Settings (AC19)', async ({ page }) => {
    await useFixtures(page, { noStores: true });
    await page.goto('/settings');
    await expect(page.getByText('No stores saved yet.', { exact: false })).toBeVisible();
    await page.getByRole('button', { name: 'Choose stores' }).click();
    const dialog = page.getByTestId('store-picker');
    await dialog.getByRole('textbox', { name: 'Home address' }).fill('2100 Elm St, Austin, TX');
    await dialog.getByRole('button', { name: 'Find stores' }).click();
    const confirm = dialog.getByRole('button', { name: 'Confirm stores' });
    await expect(confirm).toBeDisabled();
    await dialog.getByRole('searchbox').fill('co');
    await expect(dialog.getByRole('checkbox')).toHaveCount(1);
    await dialog.getByRole('checkbox', { name: /Costco/ }).click();
    await dialog.getByRole('searchbox').fill('');
    await dialog.getByRole('checkbox', { name: /H-E-B/ }).click();
    await confirm.click();
    await expect(dialog).toHaveCount(0);
    const saved = page.getByRole('list', { name: 'Your stores' });
    await expect(saved.getByRole('listitem')).toHaveCount(2);
    await expect(saved).toContainText('H-E-B');
    await expect(saved).toContainText('Costco Wholesale');
  });

  test('old bare store IDs are not counted as selected (AC19)', async ({ page }) => {
    await useFixtures(page, { legacyStoreIds: true });
    await page.goto('/settings');
    await expect(page.getByText('No stores saved yet.', { exact: false })).toBeVisible();
    await page.getByRole('button', { name: 'Choose stores' }).click();
    const dialog = page.getByTestId('store-picker');
    await expect(dialog.getByRole('checkbox', { checked: true })).toHaveCount(0);
    await expect(dialog.getByText('0 selected')).toBeVisible();
    await expect(dialog.getByRole('button', { name: 'Confirm stores' })).toBeDisabled();
  });

  test('teen sees stores without the picker (AC19)', async ({ page }) => {
    await useFixtures(page, { uid: 'teen-1' });
    await page.goto('/settings');
    await expect(page.getByRole('list', { name: 'Your stores' }).getByText('Costco Wholesale')).toBeVisible();
    await expect(page.getByRole('button', { name: /stores/ })).toHaveCount(0);
  });

  test('each store has its own list; rows move between lists (AC20, REQ-024)', async ({ page }) => {
    await useFixtures(page);
    await page.goto('/shopping');
    await heading(page, 'Shopping List');
    const tabs = page.getByRole('tablist', { name: 'Store' });
    await expect(tabs.getByRole('tab')).toHaveText(['All stores 4', 'Costco Wholesale 1', 'H-E-B 2', 'Any store 1']);
    await tabs.getByRole('tab', { name: /Costco/ }).click();
    await expect(page.getByTestId('shopping-row')).toHaveCount(1);
    await expect(page.getByTestId('shopping-row')).toContainText('Paper Towels');
    await expect(page.getByRole('combobox', { name: 'Store', exact: true })).toHaveValue('place-costco');
    await expect(page).toHaveScreenshot('ShoppingListCostco_1280.png', { fullPage: true });

    await tabs.getByRole('tab', { name: /H-E-B/ }).click();
    const moved = page.waitForRequest((r) => r.method() === 'PATCH' && r.url().endsWith('/shopping-list/sh-4'));
    await page.getByRole('combobox', { name: 'Store for Bananas' }).selectOption('place-costco');
    expect((await moved).postDataJSON()).toEqual({ store_id: 'place-costco' });
    await expect(tabs.getByRole('tab', { name: /Costco/ })).toHaveText('Costco Wholesale 2');
    await expect(page.getByTestId('shopping-row')).toHaveCount(1);

    const added = page.waitForRequest((r) => r.method() === 'POST' && r.url().endsWith('/shopping-list'));
    await page.getByPlaceholder('e.g. Whole milk').fill('Tortillas');
    await page.getByRole('button', { name: 'Add Item' }).click();
    expect((await added).postDataJSON()).toMatchObject({ name: 'Tortillas', store_id: 'place-heb' });
  });

  test('without saved stores the list is single and points owners to Settings (AC20)', async ({ page }) => {
    await useFixtures(page, { noStores: true });
    await page.goto('/shopping');
    await heading(page, 'Shopping List');
    await expect(page.getByRole('tablist', { name: 'Store' })).toHaveCount(0);
    await expect(page.getByTestId('stores-hint')).toBeVisible();
    await expect(page.getByTestId('shopping-row')).toHaveCount(4);
  });

  test('empty household shows guidance instead of blank panels', async ({ page }) => {
    await useFixtures(page, { empty: true });
    await page.goto('/inventory');
    await expect(page.getByText('Nothing in the house yet')).toBeVisible();
  });

  test('a failed load shows an error with Retry (AC4)', async ({ page }) => {
    await useFixtures(page, { failMembers: true });
    await page.goto('/members');
    await expect(page.getByText('Couldn’t load your household members.')).toBeVisible();
    await expect(page.getByRole('button', { name: 'Try again' })).toBeVisible();
    await expect(page.getByTestId('members-table')).toHaveCount(0);
  });
});
