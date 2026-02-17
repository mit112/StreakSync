# Firestore Backfill Before Strict Rules

The repository now uses strict read rules for:
- `users/{userId}` via `friends` membership checks
- `scores/{scoreId}` via `allowedReaders`

Before deploying strict rules to production, run this one-time backfill in your Firebase environment.

## Backfill Targets

1. Ensure every `users/{userId}` document has a `friends` array (empty when no friends).
2. Ensure every `scores/{scoreId}` document has an `allowedReaders` array that includes at least the score owner.

## Verification Queries (Firebase Console)

- Users missing `friends`:
  - filter where `friends` does not exist
- Scores missing `allowedReaders`:
  - filter where `allowedReaders` does not exist

## Suggested Backfill Logic

For each user:
- set `friends` to `[]` if missing.

For each score:
- read `userId`
- set `allowedReaders` to `[userId]` if missing.

## Deployment Sequence

1. Run backfill in staging.
2. Deploy `firestore.rules` to staging and run smoke tests.
3. Run backfill in production.
4. Deploy `firestore.rules` to production.
