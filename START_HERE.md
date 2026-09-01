# AVORA — START HERE

This file is the mandatory bootstrap entrypoint for every AVORA development session.

AVORA and Funny Room are independent applications. Funny Room may be inspected only as a read-only workflow reference. Never copy or mix its code, branding, users, database, buckets, tables, features, credentials, or releases into AVORA, and never mutate its repository.

## Continuation command

When the Owner says **AVORA Continue**, first read this file and continue from repository evidence without asking the Owner to repeat project history.

For a newly authorized ChatGPT session:

**AVORA Continue — read officialavora/AVORA/START_HERE.md first and follow it.**

## Mandatory read order

1. `AVORA_MASTER_RULE.md`
2. `project-state.json`
3. `docs/EXECUTABLE_SCOPE.md`
4. Current branch, recent commits, open pull requests and workflow results
5. Relevant source, backend rules/migrations, tests and release metadata

Live repository and connected-service evidence overrides stale prose. Update `project-state.json` whenever verified state changes.

## Definition of done

A feature is not done because a screen, model, contract, local list, placeholder, fake record, navigation route or build exists. It is done only when its UI works, real backend persistence and reload work, authorized cross-device sync works, security and Owner/Admin controls work, loading/error/empty states exist, automated tests pass, manual runtime testing passes, and the feature is present in the tested release APK.

## Protected boundaries

- Voice/RTC and Money/Recharge are out of scope until the Owner explicitly changes scope.
- Prefer reliable free tiers. Do not activate a paid plan without explicit Owner approval after documenting reason, price, free limit and alternatives.
- Never request passwords, private keys, API keys or payment details in chat. Use secure connectors, authorization popups and repository secret stores.
- Do not build, publish, merge to `main`, modify production data or release to Play without the required gate and Owner authorization.
- Normal flow: working branch -> validation -> reviewed merge -> Owner-requested APK -> device test -> Owner-approved AAB/Play testing.

## Startup report

Briefly state repository, branch, verified commit, active task, blockers and what is tested versus not tested. Then continue the authorized work without repeatedly asking the Owner to write “Done”.
