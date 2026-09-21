#!/bin/sh
#
#  ci_post_xcodebuild.sh
#  StreakSync
#
#  Uploads Crashlytics dSYMs after an Xcode Cloud archive.
#
#  Linking FirebaseCrashlytics only gets crashes *collected*. Without the debug
#  symbols, every report in the console is a list of raw addresses instead of a
#  stack trace — technically crash reporting, practically unreadable. The local
#  Run Script build phase does this for local archives; Xcode Cloud never runs
#  that phase against the archive's dSYMs, so it needs this.
#
#  Deliberately exits 0 on failure. By the time this runs the archive is already
#  built and on its way to TestFlight; aborting here would throw away a good
#  build over a step that can be redone by hand:
#
#      upload-symbols -gsp <plist> -p ios <path-to-dSYMs>
#

set -u

# Only archive actions produce dSYMs worth uploading.
if [ -z "${CI_ARCHIVE_PATH:-}" ]; then
    echo "No CI_ARCHIVE_PATH — not an archive action, skipping dSYM upload."
    exit 0
fi

DSYM_DIR="$CI_ARCHIVE_PATH/dSYMs"
PLIST="$CI_PRIMARY_REPOSITORY_PATH/StreakSync/GoogleService-Info.plist"

# ci_post_clone.sh materializes this from FIREBASE_PLIST_B64; if that step was
# skipped the upload would silently target the wrong project.
if [ ! -f "$PLIST" ]; then
    echo "error: $PLIST missing — did ci_post_clone.sh run? Skipping dSYM upload." >&2
    exit 0
fi

# The binary ships inside the resolved package checkout, so its path depends on
# where Xcode Cloud put DerivedData. Search rather than hardcode.
UPLOAD_SYMBOLS=$(find "${CI_DERIVED_DATA_PATH:-$HOME/Library/Developer/Xcode/DerivedData}" \
    -path '*/firebase-ios-sdk/Crashlytics/upload-symbols' -type f 2>/dev/null | head -1)

if [ -z "$UPLOAD_SYMBOLS" ]; then
    echo "error: could not find Crashlytics upload-symbols in DerivedData." >&2
    echo "error: Is FirebaseCrashlytics still a package product of the app target?" >&2
    exit 0
fi

if [ ! -d "$DSYM_DIR" ]; then
    echo "error: no dSYMs at $DSYM_DIR — check DEBUG_INFORMATION_FORMAT is dwarf-with-dsym." >&2
    exit 0
fi

echo "Uploading dSYMs from $DSYM_DIR"
"$UPLOAD_SYMBOLS" -gsp "$PLIST" -p ios "$DSYM_DIR" || {
    echo "error: dSYM upload failed; crashes will arrive unsymbolicated." >&2
    exit 0
}

echo "Crashlytics dSYM upload complete."
