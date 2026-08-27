#!/bin/sh
#
#  ci_post_clone.sh
#  StreakSync
#
#  Xcode Cloud clones the repository without GoogleService-Info.plist, which is
#  gitignored so the real Firebase credentials stay out of version control. The
#  Firebase-backed services AppContainer builds call Firestore/Auth at launch and
#  trap when no FirebaseApp exists, so the archive needs the real file — a
#  placeholder like the one GitHub Actions writes would ship a broken build.
#
#  Provide it as a base64-encoded Xcode Cloud secret environment variable named
#  FIREBASE_PLIST_B64:
#
#      base64 -i StreakSync/GoogleService-Info.plist | pbcopy
#

set -e

PLIST="$CI_PRIMARY_REPOSITORY_PATH/StreakSync/GoogleService-Info.plist"
EXPECTED_PROJECT_ID="streaksync-55ca0"

if [ -z "$FIREBASE_PLIST_B64" ]; then
    echo "error: FIREBASE_PLIST_B64 is not set. Add it as a secret" >&2
    echo "error: environment variable on the Xcode Cloud workflow." >&2
    exit 1
fi

printf '%s' "$FIREBASE_PLIST_B64" | base64 --decode > "$PLIST"

# Fail loudly here rather than letting a truncated or mis-pasted secret burn a
# full archive and upload only to crash on a tester's device.
ACTUAL_PROJECT_ID=$(/usr/libexec/PlistBuddy -c "Print :PROJECT_ID" "$PLIST" 2>/dev/null || echo "")
if [ "$ACTUAL_PROJECT_ID" != "$EXPECTED_PROJECT_ID" ]; then
    echo "error: decoded plist has PROJECT_ID '$ACTUAL_PROJECT_ID', expected '$EXPECTED_PROJECT_ID'." >&2
    echo "error: The secret is probably truncated or holds the wrong project's config." >&2
    exit 1
fi

echo "Wrote $PLIST (PROJECT_ID $ACTUAL_PROJECT_ID)"
