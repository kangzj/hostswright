#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/signing.sh
configuration="${1:-Debug}"
resolve_signing
# launchd refuses an ad-hoc signed daemon that has the hardened runtime flag (Launch Constraint Violation).
hardened_runtime=$([[ "$identity" == "-" ]] && echo NO || echo YES)
xcodegen generate --quiet
xcodebuild -project HostsMaster.xcodeproj -scheme HostsMaster -configuration "$configuration" -derivedDataPath build \
  CODE_SIGN_IDENTITY="$identity" DEVELOPMENT_TEAM="$team" ENABLE_HARDENED_RUNTIME="$hardened_runtime" build 2>&1 \
  | grep -E "error:|warning:|BUILD (SUCCEEDED|FAILED)" || true
echo "Built: build/Build/Products/$configuration/HostsMaster.app (signed with: $identity${team:+, team $team})"
