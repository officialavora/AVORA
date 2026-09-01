# AVORA Executable Scope Lock

Status values: `NOT_STARTED`, `IN_PROGRESS`, `BLOCKED`, `AUTOMATED_TESTED`, `DEVICE_TESTED`, `DONE`.

No item reaches `DONE` until it satisfies the definition in `START_HERE.md` and is present in a device-tested release APK.

| ID | Deliverable | Required backend proof | Status |
|---|---|---|---|
| AV-001 | Persistent command and project-state system | Repository bootstrap and state validation | IN_PROGRESS |
| AV-002 | Safe CI, branch and APK/AAB release gates | Non-publishing PR checks; manual signed release lanes | IN_PROGRESS |
| AV-010 | Authentication and account security | Firebase Auth, session/error handling, protected account lifecycle | IN_PROGRESS |
| AV-011 | Immutable numeric AVORA ID starting at 10000000 | Trusted atomic allocation; client cannot edit | NOT_STARTED |
| AV-012 | Unique username | Server-enforced normalized uniqueness and rename policy | NOT_STARTED |
| AV-013 | Complete profile and profile photo | Persistent media, validation, ownership rules, reload/sync | NOT_STARTED |
| AV-020 | Real rooms excluding Voice/RTC | Persistent create/edit/join/leave/member state and permissions | NOT_STARTED |
| AV-021 | Real direct and room messages | Authorized persistence, pagination, sync and moderation | NOT_STARTED |
| AV-022 | Notifications | Persistent events, read state and delivery strategy | NOT_STARTED |
| AV-023 | Follow, block and report | Server-enforced relationship and safety rules | NOT_STARTED |
| AV-030 | Moderation system | Report queue, actions, reasons, reversal and audit | NOT_STARTED |
| AV-031 | Activity and security audit | Append-only actor/action/target/timestamp records | NOT_STARTED |
| AV-032 | Owner/Admin dashboard | Server-authorized controlled management operations | NOT_STARTED |
| AV-040 | Original production games | Original gameplay, server-validated sessions/results, anti-tamper | IN_PROGRESS |
| AV-050 | Production security | Versioned Firestore/Storage rules and backend deployment tests | NOT_STARTED |
| AV-060 | Release verification | Analyze, tests, signed APK identity, artifact and device runtime | NOT_STARTED |

## Explicit exclusions

- Voice/RTC
- Money/Recharge

Exclusions do not imply completion of any included deliverable.
