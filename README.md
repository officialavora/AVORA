# AVORA

Mobile-first **AVORA** Android + iOS social voice/video/live platform.

## Locked identity
- App name: AVORA
- Flutter project name: `avora`
- Android application ID: `com.officialavora.app`
- iOS bundle ID: `com.officialavora.avora`

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
The GitHub Actions workflows build AVORA APK and AAB artifacts with the locked Android identity.

## Firebase
Firebase Authentication and Firestore are connected to the locked Android app identity:
`com.officialavora.app`

## Important
This repository contains the current AVORA application foundation; production services remain controlled integrations.
Economy, rewards, salary, seller wallets, ledgers, moderation, voice/video RTC and admin automation must be added in controlled modules with audit/recovery safeguards.
