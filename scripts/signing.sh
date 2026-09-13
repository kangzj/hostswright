# Sourced by build.sh and release.sh. launchd only runs the privileged helper when app and helper carry an
# Apple-issued signature, so pick up the Apple Development identity on this Mac unless the caller chose one.
#   HOSTSMASTER_SIGNING_IDENTITY="Developer ID Application" HOSTSMASTER_SIGNING_TEAM=TEAMID scripts/build.sh
#   HOSTSMASTER_SIGNING_IDENTITY=- scripts/build.sh     # force an ad-hoc build
resolve_signing() {
  identity="${HOSTSMASTER_SIGNING_IDENTITY:-}"
  team="${HOSTSMASTER_SIGNING_TEAM:-}"
  if [[ -z "$identity" ]]; then
    # The team ID is the certificate's OU; the ID in parentheses in its name is a different value for personal teams.
    local ou
    ou=$(security find-certificate -c "Apple Development" -p 2>/dev/null \
      | openssl x509 -noout -subject -nameopt sep_multiline 2>/dev/null | sed -nE 's/^ *OU=(.*)$/\1/p' | head -1)
    if [[ -n "$ou" ]]; then
      identity="Apple Development"
      team="$ou"
    else
      identity="-"
    fi
  fi
  if [[ "$identity" != "-" && -z "$team" ]]; then
    echo "HOSTSMASTER_SIGNING_TEAM is required with HOSTSMASTER_SIGNING_IDENTITY=$identity" >&2
    exit 1
  fi
}
