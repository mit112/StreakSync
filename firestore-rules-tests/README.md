# Firestore Rules Tests

This folder contains emulator-based Firestore security-rules tests for authenticated access scenarios.

## Run

From repo root:

```bash
firebase emulators:exec --only firestore "npm --prefix firestore-rules-tests test"
```

## What is covered

- Friend/non-friend read access for user documents
- `scores` read gating via `allowedReaders`
- Authenticated score create validation for required data and optional field types
- Friendship transition permissions (`pending` -> `accepted`)
- Immutable friendship identity enforcement on update
