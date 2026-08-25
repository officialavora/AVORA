# AVORA A2Z Reference Reconstruction

Reference inputs currently audited:
- com.ayome.sg 4.1.6 APK
- com.bofu.chat.layam 1.6.7 APKS

Implementation target: reconstruct useful behavior in AVORA-owned Flutter/Firebase code, not ship third-party branding/source.

Required functional domains: auth/login by email or AVORA ID, Google sign-in, country picker/flag, permanent ID, one user/one room, profile/avatar, labels/frames/badges/medals, rooms/seats/presence, room chat/private inbox, gifts/send-receive, wallet/recharge/coins/diamonds, VIP/SVIP/Noble, entry effects, emoji/emotion/bubbles, CP/family/agency, levels/rankings, PK, games, banners, music/sound/effects, moderation/admin hierarchy. Voice RTC intentionally excluded until later.

Release gate: real actions must be wired; flutter analyze; universal signed APK; apksigner verify; zip integrity; 16K zipalign; publish APK to GitHub Release only after gates pass.
