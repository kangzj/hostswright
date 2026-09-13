# Hostswright Local DNS Mode — Design Spec

Date: 2026-09-14
Status: Approved scope (upstream servers, cache TTL bounds, per-domain forwarding rules, query log); implemented from this design.

## 1. Goal

One click turns Hostswright into the Mac's DNS resolver.
It answers every name from `/etc/hosts` authoritatively, forwards everything else to the network's own DNS servers or a custom list, and caches the answers so repeat lookups are local.
Apps that resolve outside the classic hosts lookup, Safari included, then see the same overrides as everything else.
The mode survives quitting the app and rebooting, and turning it off restores the previous DNS settings exactly.

## 2. Platform facts (probed on this Mac, macOS 26.6)

- Port 53 is free. Binding it needs root, so the server lives in the existing root helper.
- The DHCP-provided servers stay in the dynamic store under `State:/Network/Service/<id>/DNS` (here two public resolvers and the router); a manual override goes to `Setup:/Network/Service/<id>/DNS` and only the merged `State:/Network/Global/DNS` changes.
  Automatic upstream therefore reads the per-service `State:` keys and ignores 127.0.0.1.
- `SCPreferences` lets root set `ServerAddresses` on each service's DNS protocol and apply it without spawning `networksetup`.
- iCloud Private Relay makes Safari resolve through Apple's relay; no local resolver can override that, and the README says so.

## 3. Architecture

```
Hostswright.app                      XPC                 HostswrightHelper (root, KeepAlive)
  DNSSettings in configuration  ───────────────▶  DNSMode: persists settings + saved DNS config
  status polling, query log     ◀───────────────  DNSServer 127.0.0.1:53 (UDP + TCP, Network.framework)
                                                  HostsResolverTable from /etc/hosts (re-read on change)
                                                  DNSCache (TTL bounded, cleared on hosts change)
                                                  Forwarder → rule servers / upstreams (timeout, fallback)
                                                  UpstreamMonitor (SCDynamicStore) / DNSConfigurator (SCPreferences)
```

### 3.1 DNSCore (new SwiftPM target, pure Swift, unit tested)

- `DNSName`, `DNSRecordType`, `DNSQuestion`, `DNSMessage.parse` (header, questions, records with compression-pointer walking; each record keeps the byte offset of its TTL).
- `DNSWire`: rewrite the ID and subtract elapsed time from every TTL in place, so cached upstream responses are served byte-for-byte without re-encoding.
- `DNSAnswerBuilder`: builds authoritative A / AAAA responses from hosts addresses, NODATA when the name is known but has no record of that type, and error responses (SERVFAIL, REFUSED, NOTIMP).
- `HostsResolverTable`: name → IPv4 / IPv6 addresses parsed from the whole hosts file, case-insensitive.
- `DNSCache`: bounded by capacity and by minimum / maximum TTL, negative caching from the SOA minimum, hit and miss counters.
- Models shared over XPC as JSON: `DNSSettings` (enabled, upstream automatic or custom, TTL bounds, rules, query log switch), `ForwardingRule`, `DNSStatus` (running, listen error, active upstreams, cache size, counters, recent log), `QueryLogEntry`.

### 3.2 Helper

- `DNSMode` owns the lifecycle: start server, configure DNS, watch hosts and network, persist `/Library/Application Support/Hostswright/dns-state.json` (settings plus the per-service DNS configuration saved before the override).
  On helper launch it restores the mode from that file, which is what makes it survive reboots.
- `DNSServer`: `NWListener` on UDP and TCP 127.0.0.1:53.
  Resolution order per question: hosts table → forwarding rule whose domain suffix matches → cache → upstream.
  Hosts answers carry a 5 second TTL.
- `Forwarder`: sends the raw query to the first server, falls through to the next after a 2 second timeout, UDP for UDP clients and TCP for TCP clients.
- `DNSConfigurator`: sets `ServerAddresses = ["127.0.0.1"]` on every enabled network service in the current set and restores the saved configuration on disable, removing the override where there was none.
- `UpstreamMonitor`: reads the per-service DHCP servers and re-reads on dynamic store change notifications.
- Every hosts write already flushes the system cache; it now also reloads the resolver table and clears the DNS cache.
- The launchd plist gains `KeepAlive` so the daemon is up after a reboot without waiting for the app.
- Removing the helper from the app turns the mode off first so DNS settings are never left pointing at a dead resolver.

### 3.3 App

- `LocalDNSController` owns `DNSSettings` (stored in `dns.json` next to the groups file); any change is pushed to the helper (debounced) through `applyDNSSettings`.
- Menu bar: a "Local DNS" toggle above the Flush item.
- Sidebar: a "Local DNS" page with the main switch, a status card (listening, upstreams, cache size, hit rate), upstream picker with a custom server list, TTL bounds, forwarding rules table, Clear Cache, and the query log.
- Status is polled every two seconds while the page is open or the mode is on.

## 4. Error handling

- Port 53 taken or bind refused: status shows the error, DNS settings are not touched, the switch stays off.
- All upstreams time out: SERVFAIL to the client, logged as failed.
- Helper unavailable: the page explains the mode needs the helper and the switch is disabled.
- Loop protection: 127.0.0.1 and ::1 are never used as upstreams.

## 5. Testing

- Unit: wire parsing incl. compression, TTL rewrite, hosts answers and NODATA, cache bounds / expiry / negative caching, settings JSON round trip, rule matching, server address parsing.
- E2E on this Mac: enable, `dig @127.0.0.1` a hosts name and an internet name, repeat and see the cache hit in the log, `scutil --dns` shows 127.0.0.1, Safari-level check through `dscacheutil`, disable and confirm the original servers return.

## 6. Implementation notes

- Forwarding rules are a plain suffix match on the domain; no wildcard syntax anywhere, per Jasper.
- DNS settings live in `~/Library/Application Support/Hostswright/dns.json`, separate from the groups file, so HostsCore stays unaware of DNSCore.
- `HelperService` is `@unchecked Sendable` (immutable Sendable members) so async XPC handlers can run in Tasks.
- Cached upstream answers are served from the original bytes with the ID and TTLs patched in place; only hosts answers are built from scratch.
- Verified on this Mac: enable pointed both resolvers at 127.0.0.1, `dig @127.0.0.1` returned the hosts address, an internet name took 151 ms then 1 ms from cache with the TTL counting down, AAAA for a hosts name gave NODATA, TCP and NXDOMAIN forwarding worked, `dscacheutil` saw the override, and disable restored the original servers and closed the port.
  Reboot persistence relies on the state file plus `KeepAlive` and was not rebooted to verify.
