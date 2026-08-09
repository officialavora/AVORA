# AVORA

Mobile-first starter for **AVORA** — a future Android + iOS social voice/video/live platform.

## Locked starter identity
- App name: AVORA
- Flutter project name: `avora`
- Android application ID / iOS bundle base: `com.officialavora.avora`

> Keep the package/bundle ID stable once it is registered in Firebase / stores.

## What v0.1 contains
- Splash screen
- Welcome / login / signup UI
- No paid OTP dependency
- Signup fields: name, gender, country, invite code, DOB and bio
- Home tabs: Home, Rooms, Messages, Profile
- Basic Create Room flow
- Profile social counters
- Android GitHub Actions build workflow

## Android build
The GitHub Actions workflow can create the missing Android platform files and build a debug APK automatically.

## Firebase
Firebase is intentionally not wired yet. First register the Android app using:
`com.officialavora.avora`

Then add Authentication / Firestore carefully in the next version.

## Important
This is a starter UI/build foundation, not the full AVORA production backend.
Economy, rewards, salary, seller wallets, ledgers, moderation, voice/video RTC and admin automation must be added in controlled modules with audit/recovery safeguards.
