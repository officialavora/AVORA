# AVORA MASTER RULE

## Product identity

AVORA is an original, independent application with its own code, design, data, backend, database, security, users, features, Owner system and releases.

Funny Room is read-only workflow reference only. No Funny Room application code, data, schema, storage, branding, users, credentials, assets or feature implementation may be copied, shared, mixed or modified.

## Authority

The Owner controls application-wide add, edit, remove, approve, reject, suspend, ban, unban, stop, manage and audit operations. Every privileged action must be server-authorized, least-privilege, scoped, attributable and recorded in an append-only audit trail. Client UI visibility never grants authority.

## Engineering truth

- Repository source and deployed backend configuration are the source of truth.
- Client-controlled counters, roles, balances, moderation decisions or game outcomes are forbidden.
- Immutable numeric AVORA IDs and unique usernames must be allocated atomically by trusted backend code.
- Security rules default to deny and explicitly allow only required operations.
- Demo/local/static behavior must be labelled NOT DONE and replaced, not presented as production functionality.
- Do not claim runtime PASS from analysis, unit tests, compilation, export or APK creation alone.
- Preserve package ID `com.officialavora.app` and permanent signing identity.

## Branch and release safety

- Develop on `feature/*` or `fix/*` branches.
- Pull requests run non-publishing validation.
- `main` must not automatically publish an APK/AAB merely because code was pushed.
- APK and AAB releases are manual, separately authorized actions.
- Production publishing always requires explicit Owner approval.
- Never expose secrets in source, chat, logs or artifacts.

## Completion report

For every release report changed files, real working features, tests and runtime evidence, APK link, commit, backend deployment state and unavoidable Owner actions. Anything unverified must say NOT TESTED or NOT VERIFIED.
