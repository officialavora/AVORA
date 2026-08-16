# AVORA Current Checkpoint

Last updated: 2026-08-15 (Asia/Riyadh)

This file is the canonical handoff for continuing AVORA work in any new Work chat.
Read this file, the open AUTH PR, and the referenced source before changing roadmap status.
Do not ask the owner to repeat project history already recorded here.

## Repository

- Repository: officialavora/AVORA
- Android package: com.officialavora.app
- Strategy: repair and selective rebuild of the existing Flutter application
- Android first; architecture must remain iOS-compatible
- Active branch: work/auth-001-google-signin
- Active pull request: #1
- Current app version: 0.1.0+17

## Permanent delivery rules

- Result first, then Current Roadmap, then Exact Next Action.
- Code alone is not DONE.
- DONE requires analyze, tests, build, APK/AAB, real-device functional verification, and relevant error/edge-state checks.
- Preserve useful foundations. Replace poor UI/UX with an original premium cinematic AVORA experience.
- Never show raw Firebase/provider/backend errors.
- Dev/test and production data/economies stay isolated.
- Owner is global highest authority across every module. Sensitive actions remain audited and recoverable.
- Prefer free/built-in/open-source solutions first.
- Keep the application simple, low-data, low-battery, weak-network friendly, and performant on low-end phones.
- Do not copy third-party application names, copyrighted artwork, or sounds. Use references only for interaction/product inspiration.

## AUTH-001 configuration verified

- Firebase project: avora-4ac0c
- Firebase Google provider: enabled
- Play App Signing SHA-1: C7:7F:39:93:06:32:06:DF:36:50:07:84:65:59:21:7F:FC:3D:01:B1
- Play App Signing SHA-256: 2A:0B:C6:A7:52:74:96:DE:7B:39:B1:5E:72:28:34:9A:F9:5B:37:92:C6:75:1B:09:E2:99:7D:F5:6A:1B:E5:22
- android/app/google-services.json contains the matching app-signing SHA-1 client.
- Existing Google Sign-In v6 and Firebase credential bridge are retained.

## AUTH-001 verified device evidence

- Google account authentication reached AVORA.
- Permanent sequential IDs were created and displayed:
  - Friend DEEWANA: 10000002
  - Owner/test account: 10000003
- Logout returned to login.
- The tested APK was the old starter build, not version +9.

## Implemented on active branch

- Typed Google/provider failure handling.
- Human-readable auth errors.
- Visible Google/account/AVORA-ID/profile progress.
- Atomic permanent AVORA ID creation through the existing Firestore transaction.
- Email signup profile persistence.
- Original cinematic Welcome foundation.
- Removed the old developer-facing social-auth placeholder.
- Automatic APK workflow trigger for active AUTH branch updates.
- Build bumped to 0.1.0+9.
- Analyzer missing-import failure from run #37 fixed in commit c793f35a3ff0b26b54d391a2b8fa060785cc00b5.

## Current build status

- Active batch: 17
- Build 16 commit: 3e91707e67d7d704a2c710431a82c7e56e740ef5
- APK workflow run #56: SUCCESS
  https://github.com/officialavora/AVORA/actions/runs/31890131368
- AAB workflow run #32: SUCCESS
  https://github.com/officialavora/AVORA/actions/runs/31890131343
- Build 9 device evidence passed cinematic Welcome, Google login, and same permanent ID 10000003.
- Build 10 added password visibility, autofill/keyboard UX, automated tests, and parallel APK/AAB release verification.
- Build 11 adds functional room-card navigation, validated room creation, a cinematic room surface, 10-seat UI, and testable mic/speaker states.
- Build 11 tests, analyze, APK, and AAB passed. Real-device verification remains required.
- Build 12 replaces free-text country entry with a device-region suggestion and user-selectable ISO country, and replaces the Inbox placeholder with Notifications/System/Support/Chats sections plus a support request form.
- Build 12 tests, analyze, APK, and AAB passed. Real-device verification remains required.
- Build 13 adds the roadmap five-tab shell (Home/Discover/Create/Inbox/Me), functional Home actions, a Create hub, and removes starter/developer-facing Home text.
- Build 13 tests, analyze, APK, and AAB passed. Real-device verification remains required.
- Build 16 adds permanent AVORA ID copy, exact numeric user search, USER/OFFICIAL identity surfaces, and public profile levels. Tests, analyze, APK, and AAB passed; real-device verification remains required.
- Build 17 commit: 341f1f94cf32c6772e6fc717ddfa329d296c6b93
- Build 17 adds direct Google signup, reconciled email re-login, explicit auth progress, account-route links, confirmed logout, and Google provider cleanup.
- Build 17 tests, analyze, APK, and AAB passed.
  - APK run #62: https://github.com/officialavora/AVORA/actions/runs/31894788502
  - AAB run #38: https://github.com/officialavora/AVORA/actions/runs/31894788503
- Build 17 real-device verification remains required; AUTH-001 is not DONE.
- Device recording confirms Firestore permission failures currently block user search, profile save, and persistent cross-device rooms. UI-only success must not be treated as backend PASS.

## AUTH-001 remaining PASS gates

1. Build and install version +17.
2. Verify login/signup password visibility.
3. Google login on the signed build.
4. Same Google account returns the same permanent AVORA ID.
5. Firestore profile persists.
6. Logout/login again passes.
7. No raw technical error reaches the user.
8. Deploy secure Firestore rules and verify user search, profile save, and room persistence.
9. Verify country suggestion/change and all four Inbox sections.
10. Verify Home/Discover/Create/Inbox/Me navigation and Create hub.

AUTH-001 must not be marked DONE before every gate passes.


## Roadmap status protocol

Every work report and checkpoint update must classify roadmap items using exactly:

- DONE: code + relevant tests + analyze + build + real-device verification passed.
- IN PROGRESS: actively being implemented, built, or verified now.
- PENDING: accepted scope whose prerequisite has not passed yet.
- BLOCKED: cannot proceed until a named external/configuration/user gate is resolved.

Each release report must include:
- DONE count
- IN PROGRESS count
- PENDING count
- BLOCKED count
- active batch/version
- exact verification checklist
- exact next engineering action

Never remove a completed item silently. Move it to completed history with its version/commit/evidence.
Never mark placeholder/local-demo behavior as DONE.

## Current Roadmap

1. AUTH-001 Google Sign-In and identity verification — NOW
2. Permanent AVORA ID and first-time profile setup
3. Cinematic Splash/Auth/Home
4. RTC and real voice room
5. Seats, room controls, moderation, and room chat
6. Test Coins, gifts, combo gifting, ledger, and balances
7. Rich/Charm levels, VIP/SVIP, PK, and rankings
8. Social, messaging, CP, and Family
9. Host, Agency, BD, roles, and configurable policies
10. In-app Owner Power Center
11. Web Owner/Admin panel
12. Account/device/IP-risk enforcement and audited reset
13. Lucky Pocket, Lucky Gift, safe games, events, banners, and cinematic effects
14. Demo/test isolation and Owner reset controls
15. Tester-ready APK/AAB and 2–50 genuine testers
16. Performance, security, weak-network, low-data, and low-battery hardening
17. Play Internal/Closed testing and current console requirement
18. Production reset/isolation and controlled Android release
19. iOS configuration, TestFlight, and App Store later

## Locked product distinctions

- Lucky Pocket (LP) and Lucky Gift are separate systems.
- Emoji reactions, GIF/stickers, room entries, and economic gifts are separate engines.
- Test currency is non-real and non-withdrawable.
- Test reset preserves permanent AVORA ID, login account, name, DP, and approved profile while isolating/resetting test economy and progression as configured.
- Owner has full global operational access through both an in-app Power Center and a web panel.
- Verified badge is separately granted/revoked; it is not automatic with Merchant/Seller role.

## Active Build 23 — test economy and room experience

- Added a fixed, non-withdrawable 100,000 Test Coin wallet created once per tester.
- Added room-member recipient selection and a four-item original AVORA gift catalog.
- Added ×1/×5/×10/×20/×50 combo sending without reopening the gift picker.
- Added atomic sender debit, receiver credit, sent/received totals, and an immutable gift ledger.
- Added Firestore rules that reject arbitrary wallet edits, duplicate rewrites, and ledger deletion.
- Compacted 15-seat layouts to preserve visible space for chat, entries, gifts, and effects.
- Added a visible TEST wallet card so demo currency can never be confused with real money.

## Exact Next Action

Build and install version 0.1.0+23 on two devices. Confirm account persistence, both wallets,
same-room presence, recipient selection, one gift and one combo, both balance changes, and
ledger immutability. AUTH-001 and Build 23 remain IN PROGRESS until this device evidence passes.
