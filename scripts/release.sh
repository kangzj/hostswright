#!/bin/zsh
# Builds a Release HostsMaster.app, signs it, packages a DMG, and optionally notarizes it.
#
#   scripts/release.sh                                             # Apple Development identity if present, else ad-hoc
#   scripts/release.sh --identity "Developer ID Application" --team TEAMID
#   scripts/release.sh --identity "..." --team TEAMID --notarize-profile hostsmaster
#
# The notarization profile is created once with:
#   xcrun notarytool store-credentials hostsmaster --apple-id you@example.com --team-id TEAMID --password app-specific-password
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh

notarize_profile=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --identity) export HOSTSMASTER_SIGNING_IDENTITY="$2"; shift 2 ;;
    --team) export HOSTSMASTER_SIGNING_TEAM="$2"; shift 2 ;;
    --notarize-profile) notarize_profile="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done
resolve_signing
hardened_runtime=$([[ "$identity" == "-" ]] && echo NO || echo YES)

xcodegen generate --quiet
rm -rf build/Release dist
xcodebuild -project HostsMaster.xcodeproj -scheme HostsMaster -configuration Release -derivedDataPath build/Release \
  CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$team" OTHER_CODE_SIGN_FLAGS="--timestamp" \
  ENABLE_HARDENED_RUNTIME="$hardened_runtime" ARCHS=arm64 build 2>&1 \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true

app="build/Release/Build/Products/Release/HostsMaster.app"
[[ -d "$app" ]] || { echo "Build failed" >&2; exit 1; }
version=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$app/Contents/Info.plist")
codesign --verify --deep --strict --verbose=2 "$app"

mkdir -p dist/stage
cp -R "$app" dist/stage/
ln -s /Applications dist/stage/Applications
dmg="dist/HostsMaster-$version.dmg"
hdiutil create -volname "HostsMaster" -srcfolder dist/stage -ov -format UDZO "$dmg" >/dev/null
rm -rf dist/stage

if [[ -n "$notarize_profile" ]]; then
  xcrun notarytool submit "$dmg" --keychain-profile "$notarize_profile" --wait
  xcrun stapler staple "$dmg"
  spctl --assess --type open --context context:primary-signature -v "$dmg"
fi

echo "Release: $dmg (signed with: $identity${team:+, team $team})"
if [[ "$identity" == "-" ]]; then
  echo "Ad-hoc signed: the helper cannot run and other Macs need the Open Anyway steps from the README."
fi
