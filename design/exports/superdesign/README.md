# Superdesign HTML exports

Rendered Superdesign drafts (full HTML + Tailwind) from the Mekasa project canvas,
for implementing or comparing native screens and the web app against the designs.

Canvas: https://superdesign.dev/teams/97f327bd-7027-43ef-8186-e2aafd35b597/projects/747347d9-34d0-43dd-a1c8-e170f34a7b5c

Browse: [`index.html`](index.html) — on GitHub Pages at
https://fernandogator.github.io/mekasa/design/exports/superdesign/

Checked against the canvas on 2026-10-13: 46 drafts, every one exported at its latest version.

## Refreshing

Each file is the public preview of its draft, so no login is needed:

```bash
curl -sL https://p.superdesign.dev/draft/<draft-id> -o <file>.html
```

The preview wraps the draft HTML from `npx @superdesign/cli get-design --draft-id <id>`
with Superdesign's renderer and an image-load fallback; the design markup is identical.
Only the `preview-timestamp` meta tag changes between downloads, so a refresh with no
other diff means nothing changed on the canvas. List every draft with
`npx @superdesign/cli fetch-design-nodes --project-id 747347d9-34d0-43dd-a1c8-e170f34a7b5c`
and keep the tables below in step with it.

## Mobile — primary screens

| File | Screen | Draft ID |
|------|--------|----------|
| [`mobile/01-dashboard.html`](mobile/01-dashboard.html) | Dashboard - Rich & Grounded | `69d15b18-61b1-45ec-92f6-5f89e59a7ee9` |
| [`mobile/02-store-selection.html`](mobile/02-store-selection.html) | Store Selection | `afdeeaad-6431-495e-9674-5231b3993dca` |
| [`mobile/03-shopping-list.html`](mobile/03-shopping-list.html) | Shopping List | `b234a6ab-1837-48a9-84d1-a2ed870ae61c` |
| [`mobile/04-add-items.html`](mobile/04-add-items.html) | Add Items | `eee7d5dd-5cc6-4c4a-8c91-2717e1973660` |
| [`mobile/05-trash-station.html`](mobile/05-trash-station.html) | Trash Station | `a8a15416-6c7a-4f32-b1b0-c233c57f0cd1` |
| [`mobile/06-onboarding-household.html`](mobile/06-onboarding-household.html) | Onboarding Household | `cf8659c3-ef2d-4f9c-b097-f7774783a2f3` |
| [`mobile/07-spending-report.html`](mobile/07-spending-report.html) | Spending Report | `a45a3eab-e709-415e-8a81-19f333a3c88b` |
| [`mobile/08-family-members.html`](mobile/08-family-members.html) | Family Members | `248f70a0-c51e-430f-9a3c-ed7d25f68606` |
| [`mobile/09-home-photo-editor.html`](mobile/09-home-photo-editor.html) | Home Photo Editor | `e448050c-2741-4aef-91b8-d6bfda65120a` |
| [`mobile/10-product-image-editor.html`](mobile/10-product-image-editor.html) | Product Image Editor | `f269d503-5c81-4ff0-95bc-6cd58207720b` |
| [`mobile/11-home-photo-editor-empty.html`](mobile/11-home-photo-editor-empty.html) | Home Photo Editor - Empty | `bac1d515-01e9-4f59-b62a-8625770dc4f0` |
| [`mobile/12-product-image-editor-empty.html`](mobile/12-product-image-editor-empty.html) | Product Image Editor - Empty | `d9f24200-19fd-4f03-a2ae-ae8bb26e0240` |
| [`mobile/13-receipt-results.html`](mobile/13-receipt-results.html) | Receipt Results | `1d90831d-41f0-4e79-91b7-72c030031852` |
| [`mobile/14-guided-barcode-scan.html`](mobile/14-guided-barcode-scan.html) | Guided Barcode Scan | `45b357eb-abf1-4cca-932c-a87ff9a15b81` |
| [`mobile/15-picture-step.html`](mobile/15-picture-step.html) | Picture Step | `f60e440a-5add-4eae-98f3-0846b4f84bfe` |
| [`mobile/16-plu-scan.html`](mobile/16-plu-scan.html) | PLU Scan | `98e8c894-bdb9-4d7b-a94c-c7ff13372925` |
| [`mobile/17-unidentified-item.html`](mobile/17-unidentified-item.html) | Unidentified Item | `0c582d18-c7ed-46a8-a6f6-bdcf75fc709b` |
| [`mobile/18-scan-completion.html`](mobile/18-scan-completion.html) | Scan Completion | `9f1d6d79-4aa3-4e9d-9956-66a4b10f672b` |
| [`mobile/19-component-sheet.html`](mobile/19-component-sheet.html) | Component Sheet | `7ec3a85a-f317-4f25-b3b7-708907056fb0` |
| [`mobile/31-inventory-duplicates-review.html`](mobile/31-inventory-duplicates-review.html) | Inventory Duplicates Review | `1f5ffe03-8291-45da-afbe-c80bacd1846a` |
| [`mobile/32-item-scan-workflow.html`](mobile/32-item-scan-workflow.html) | Item Scan Workflow | `1330518d-7dfc-4033-b09f-202264d24ac3` |

## Mobile — dashboard variants

| File | Screen | Draft ID |
|------|--------|----------|
| [`mobile/variants/20-dashboard-soft-dreamy.html`](mobile/variants/20-dashboard-soft-dreamy.html) | Dashboard variant - Soft & Dreamy | `9174ce35-92ee-4d8e-8e4d-b029824aaa15` |
| [`mobile/variants/21-dashboard-cool-fresh-pastel.html`](mobile/variants/21-dashboard-cool-fresh-pastel.html) | Dashboard variant - Cool & Fresh Pastel | `786a8625-edb6-4592-8810-625d6d85c1a2` |
| [`mobile/variants/22-dashboard-warm-bottom-launcher.html`](mobile/variants/22-dashboard-warm-bottom-launcher.html) | Dashboard variant - Warm with Bottom Launcher | `907e2ec9-2402-4e39-b4ca-cdbf842560c4` |
| [`mobile/variants/23-dashboard-green-olive-pastel.html`](mobile/variants/23-dashboard-green-olive-pastel.html) | Dashboard variant - Green Olive Pastel | `df6bd27d-193f-4e87-8851-df851e84a4ce` |
| [`mobile/variants/24-dashboard-warm-cream.html`](mobile/variants/24-dashboard-warm-cream.html) | Dashboard variant - Warm Cream | `2c41c588-ecb7-42d7-8edc-b50ac9f3a7bb` |
| [`mobile/variants/24b-dashboard-rich-grounded.html`](mobile/variants/24b-dashboard-rich-grounded.html) | Dashboard variant - Rich & Grounded | `f3fe52d4-0b26-4fc2-9434-27ce554a455b` |
| [`mobile/variants/25-dashboard-soft-cozy.html`](mobile/variants/25-dashboard-soft-cozy.html) | Dashboard variant - Soft & Cozy | `0d605f15-16ae-4676-9e3b-12dcd6ab2e31` |
| [`mobile/variants/26-dashboard-dark.html`](mobile/variants/26-dashboard-dark.html) | Dashboard variant - Dark Mode | `4cae47c9-b8f1-439f-879e-eb3d8af1cac6` |

## Mobile — dark mode

| File | Screen | Draft ID |
|------|--------|----------|
| [`mobile/dark/27-barcode-scan-dark.html`](mobile/dark/27-barcode-scan-dark.html) | Barcode Scan - Dark | `4b5561d4-5bf7-4598-bdd1-f7cb69b5771c` |
| [`mobile/dark/27b-barcode-scan-step-dark.html`](mobile/dark/27b-barcode-scan-step-dark.html) | Barcode Scan Step - Dark Mode (draft) | `b019f02d-634a-4260-ad86-49afb8edc2a8` |
| [`mobile/dark/28-new-product-card-dark.html`](mobile/dark/28-new-product-card-dark.html) | New Product Card - Dark | `64b9880d-3515-410d-b9ed-e199e2ab06fa` |
| [`mobile/dark/28b-new-product-card-dark.html`](mobile/dark/28b-new-product-card-dark.html) | New Product Card - Dark Mode (draft) | `b8b3a093-8fea-47e0-bb8e-0e397553fd01` |
| [`mobile/dark/29-haul-summary-dark.html`](mobile/dark/29-haul-summary-dark.html) | Haul Summary - Dark | `fc918c2b-60ff-4209-bdc2-4275d85e4ab3` |
| [`mobile/dark/29b-scan-completion-dark.html`](mobile/dark/29b-scan-completion-dark.html) | Scan Completion Summary - Dark Mode (draft) | `fb208fef-3b90-4cf8-baa1-8160916ffcb8` |
| [`mobile/dark/30-item-detail-pager.html`](mobile/dark/30-item-detail-pager.html) | Item Detail Pager | `999ef27d-3a78-4932-97a3-dd668d7a0f1c` |

## Desktop web app

| File | Screen | Draft ID |
|------|--------|----------|
| [`desktop/01-dashboard.html`](desktop/01-dashboard.html) | Desktop Dashboard | `64c43b6c-53b3-40d3-ac58-d6b54a4832c2` |
| [`desktop/02-shopping-list.html`](desktop/02-shopping-list.html) | Desktop Shopping List | `e2f353ac-4065-4a39-af5d-8d5784761809` |
| [`desktop/03-spending-analytics.html`](desktop/03-spending-analytics.html) | Desktop Spending Analytics | `5f669691-b723-4a86-bb50-d6d7ef4f1ca0` |
| [`desktop/04-family-members.html`](desktop/04-family-members.html) | Desktop Family Members | `35546fc3-efa9-4da5-a502-2570c2d6e706` |
| [`desktop/05-sign-in.html`](desktop/05-sign-in.html) | Desktop Sign In | `34307113-e2a3-4c58-8482-b8143fba9261` |
| [`desktop/06-receipt-upload-review.html`](desktop/06-receipt-upload-review.html) | Desktop Receipt Upload and Review | `01ac8495-9de5-4d41-bacb-6e7796318643` |
| [`desktop/07-item-detail.html`](desktop/07-item-detail.html) | Desktop Item Detail | `b95daad0-b60f-424a-af0a-77187d265de8` |
| [`desktop/08-settings.html`](desktop/08-settings.html) | Desktop Settings | `63cb673b-f7d6-4b37-8446-50cd1dfb302c` |

## App Store screenshots

| File | Screen | Draft ID |
|------|--------|----------|
| [`app-store-screenshots/01-know-whats-in-your-home.html`](app-store-screenshots/01-know-whats-in-your-home.html) | App Store - Know What's in Your Home | `9c1383f3-688f-4124-a0a2-b59db0c6b1ac` |
| [`app-store-screenshots/02-collaboration.html`](app-store-screenshots/02-collaboration.html) | App Store - Collaboration | `8d5f0c2b-b812-4f96-936f-230859a30eee` |
| [`app-store-screenshots/03-add-items-hub.html`](app-store-screenshots/03-add-items-hub.html) | App Store - Add Items Hub | `55caf9ff-038e-4ede-af78-adf0ba78fce4` |
| [`app-store-screenshots/04-spending-report.html`](app-store-screenshots/04-spending-report.html) | App Store - Spending Report | `905eebbf-86af-40ae-8a64-bbdf79dc2b4b` |
| [`app-store-screenshots/05-family.html`](app-store-screenshots/05-family.html) | App Store - Family | `1a4335a9-c7c2-477c-8fef-c3ac13ec6f0e` |
| [`app-store-screenshots/06-trash-station.html`](app-store-screenshots/06-trash-station.html) | App Store - Trash Station | `b86f48df-cffe-40e5-b22f-f93038c60cd3` |

## Image assets

From the project's image generations (`npx @superdesign/cli list-generations`).

| File | Image |
|------|-------|
| [`assets/images/mekasa-app-icon-v2.png`](assets/images/mekasa-app-icon-v2.png) | App icon v2 — green house, barcode, red scan line (current brand asset) |
| [`assets/images/mekasa-app-icon-v1.png`](assets/images/mekasa-app-icon-v1.png) | App icon v1 — green house with barcode |
| [`assets/images/home-interior.jpg`](assets/images/home-interior.jpg) | Home interior (generated) |

The house exterior photo (full and thumbnail crops) is not copied here: it is a real,
identifiable house and this repository is public. It stays on the Superdesign canvas.
