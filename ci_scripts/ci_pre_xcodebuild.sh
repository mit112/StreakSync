#!/bin/sh
#
#  ci_pre_xcodebuild.sh
#  StreakSync
#
#  Xcode Cloud never modifies the project's build number, so without this the
#  archive would ship the static CURRENT_PROJECT_VERSION baked into
#  project.pbxproj every run — and App Store Connect rejects a second upload that
#  reuses a (CFBundleShortVersionString, CFBundleVersion) pair. Stamp every
#  target with Xcode Cloud's monotonic CI_BUILD_NUMBER so each automated upload
#  is unique. Both app and Share Extension get the same number, which App Store
#  Connect also requires (the extension's build must match the app's).
#

set -e

if [ -z "$CI_BUILD_NUMBER" ]; then
    echo "CI_BUILD_NUMBER not set; leaving build number unchanged."
    exit 0
fi

cd "$CI_PRIMARY_REPOSITORY_PATH"
xcrun agvtool new-version -all "$CI_BUILD_NUMBER"
echo "Set build number to $CI_BUILD_NUMBER for all targets."
