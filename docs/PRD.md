# MEKASA — Product Requirements Document (v1.0 MVP)

## 1. Overview
Mekasa is a household inventory management app that helps families
track what they own, what they're running low on, and what they need
to buy — with minimal manual data entry. The name plays on "mi casa"
(my house), reflecting the app's core purpose: knowing what's in your
home. Data syncs in real time across native mobile apps for all
household members.

## 2. Problem Statement
Households struggle to track inventory across groceries, household
supplies, toiletries, tools, and seasonal items. This leads to
duplicate purchases, running out of essentials unexpectedly, and no
visibility into spending patterns. When family members go to the
store, they don't know what to buy or what they already have at home.

## 3. Target User
A single household with one or two adults (Owners) and zero or more
children (Members). v1.0 supports exactly one household per account.

## 4. Goals (v1.0 MVP)
- Minimize friction in logging inventory (scan-first, not type-first)
- Automatically maintain a shared shopping list
- Track spending by category with reasonable price estimation
- Support real-time multi-user sync across native mobile apps
- Provide role-appropriate permissions for adults vs. children

## 5. Out of Scope (v1.0)
- Recipe suggestions based on pantry contents
- Multi-household support
- Budget caps and spending alerts
- Teen purchasing permissions (data model must allow for this later)
- Desktop clients (architecture must allow for future Windows support)
- Offline-first full sync (offline queue supported, not full offline)

## 6. Core User Roles
- Owner (Adult): full permissions — add/edit/remove inventory,
  approve or reject requests, manage household members, view all
  spending data, mark items purchased
- Member (Child): can view inventory, submit item requests to the
  shopping list, cannot approve requests, mark items purchased,
  or edit others' entries

## 7. Core Features

### 7.1 Inventory Input Methods
- Barcode scanning: auto-lookup via third-party barcode database API
- Receipt scanning: backend OCR for bulk item entry
- Manual entry
- Voice input
- Trash station mode: dedicated device (e.g., repurposed old phone)
  mounted near garbage, scans barcode before discarding to auto-
  decrement inventory

### 7.2 Low Stock Detection
- User-defined minimum threshold per item
- System-learned consumption pattern, suggests threshold adjustments
  over time (user must approve changes)
- When stock hits threshold, item auto-adds to shared shopping list

### 7.3 Shopping List & Requests
- Shared list visible to all household members
- Members (children) submit requests tagged with their name
- Owners approve, reject, or request more info on pending requests
- Only Owners can mark items purchased in v1.0

### 7.4 Spending Tracking
- Primary source: receipt scan OCR (price-paid per purchase event)
- Fallback: historical price for that item → online lookup →
  brand/category average estimate (marked as estimated)
- Spending tracked and reportable by category
- v1.0: reporting only, no budget caps or alerts

### 7.5 Household Setup & Onboarding Flow
1. First adult signs up via Apple, Google, or email/password
2. Optionally name the household and add a photo of the home
   (used as home screen backdrop)
3. GPS detects current location, reverse geocodes to suggested
   home address — user confirms or edits manually
4. Using confirmed address, system queries for grocery and
   retail stores within 15-mile radius (Walmart, Costco, Publix,
   and local stores) — user selects their regular stores
5. Free-form initial inventory scan (barcode, receipt, manual,
   voice) in any order
6. Prompt: "Scan a recent receipt to bulk-add items"
7. When user indicates done scanning: "Would you like to add
   anyone else to the household?"
8. Invite spouse as second Owner, invite children as Members
   (name, email, phone) — they receive download invite
9. Setup complete → home dashboard

## 8. Notifications
- Push notifications + shared dashboard for: low stock alerts,
  pending child requests, request approvals/rejections,
  household activity

## 9. Technical Approach
- Android: Jetpack Compose, programmatic UI, Material Design 3
- iOS: SwiftUI, programmatic UI, Apple HIG
- Backend: GCP-based custom REST API (Cloud Run)
- Real-time sync: Firestore
- Barcode lookup: third-party barcode database API (e.g., Open
  Food Facts or UPC ItemDB)
- Receipt OCR: server-side processing (Google Cloud Vision)
- Store lookup: Google Places API within 15-mile radius
- Location: device GPS + reverse geocoding for home address
- Secrets: GCP Secret Manager

## 10. Success Criteria (v1.0)
- Full onboarding (signup through first invite) under 10 minutes
- Barcode scan to inventory entry under 5 seconds per item
- Shopping list updates visible across all devices within 5 seconds
- Spending categorized and viewable historically without manual entry
