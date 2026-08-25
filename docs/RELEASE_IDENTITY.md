# AVORA Permanent Release Identity

This file is the durable cross-chat/release contract. Future AVORA builds must preserve these identities so users update in place instead of uninstalling.

## Android
- Package/applicationId: `com.officialavora.app`
- Signing certificate SHA-256: `c79aa1892a2c6b753049c814c55163a228475ba60431876ed97c776348b894ae`
- Release signing secrets: existing `AVORA_KEYSTORE_*` GitHub Actions secrets; never rotate for the same Android package unless a platform-supported signing-key upgrade/migration is performed.
- Every release must have a strictly higher `versionCode` than every prior public/private install. Canonical workflow derives a monotonic build number and verifies it in the produced APK.
- Updates must be installed over the existing app. Uninstall is not part of the normal update path.
- AAB uses the same package/signing identity for Google Play/App Bundle distribution.

## User data
- App schema/data migrations must be forward-compatible and non-destructive.
- Never require uninstall to clear local state for a normal release.
- Server-side user/profile/room/wallet/chat data must remain keyed by stable account IDs, not by installation instance.

## iOS
- iOS updates require one permanent Bundle ID and the same Apple Developer Team/distribution identity.
- When iOS is enabled, store the Bundle ID here and use TestFlight/App Store (or an authorized enterprise/MDM channel) for update-in-place delivery.
- Ad-hoc IPA installs cannot be promised as permanent lifetime installs because Apple provisioning profiles/certificates can expire.

## Release channel
- Canonical Android update release tag: `avora-latest-update`
- Canonical assets: `AVORA-latest.apk` and `AVORA-latest.aab`

Do not change package ID, signing identity, bundle identity, or downgrade version/build numbers just because work continues in a new ChatGPT conversation or branch.
