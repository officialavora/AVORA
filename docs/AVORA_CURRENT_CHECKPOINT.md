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
- Current app version: 0.1.0+11

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

- Active batch: 11
- Latest repair commit: fdff31b863ad5d837829289329c5566f65deb79e
- APK workflow run #46: SUCCESS
  https://github.com/officialavora/AVORA/actions/runs/31880462867
- AAB workflow run #22: SUCCESS
  https://github.com/officialavora/AVORA/actions/runs/31880462864
- Build 9 device evidence passed cinematic Welcome, Google login, and same permanent ID 10000003.
- Build 10 added password visibility, autofill/keyboard UX, automated tests, and parallel APK/AAB release verification.
- Build 11 adds functional room-card navigation, validated room creation, a cinematic room surface, 10-seat UI, and testable mic/speaker states.
- Build 11 tests, analyze, APK, and AAB passed. Real-device verification remains required.

## AUTH-001 remaining PASS gates

1. Download/install version +11.
2. Verify login/signup password visibility.
3. Google login on the signed build.
4. Same Google account returns the same permanent AVORA ID.
5. Firestore profile persists.
6. Logout/login again passes.
7. No raw technical error reaches the user.
8. Verify room card opens, room creation validates a name, and the new room screen renders/operates without a crash.

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

## Exact Next Action

Inspect GitHub Actions run #38. If it fails, read the exact failed job logs and safely fix the same branch. If it succeeds, provide the APK artifact/internal-test action and request only the real-device verification gates above.
