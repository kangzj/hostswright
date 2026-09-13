# HostsMaster — Design Spec

Date: 2026-09-14
Status: Implemented from this design; see §12 for notes recorded during the build. Renamed to Hostswright afterwards.

## 1. Goal

A native macOS menu bar app that switches groups of `/etc/hosts` entries on and off.
Groups are independent, so any combination can be active at once.
Every change lands in `/etc/hosts` and takes effect in browsers and apps immediately, with no password prompt after a one-time setup.
It must feel like part of macOS: SwiftUI, a native dropdown in the menu bar, light and dark mode, and nothing to learn.

## 2. Platform facts

- `/etc/hosts` is `root:wheel 0644`, so reading is unprivileged and writing needs root.
- The DNS cache is cleared with `dscacheutil -flushcache` followed by `killall -HUP mDNSResponder`; both need root to affect the system resolver.
- Apple's `SMAppService.daemon(plistName:)` registers a launchd daemon embedded in the app bundle.
  The user approves it once in System Settings › Login Items; afterwards launchd starts it on demand with no further prompts.
  launchd refuses a privileged daemon with an ad-hoc signature, so builds are signed with the Apple Development identity found on this Mac (team 76LYQMZ2YM, read from the certificate OU).
- Toolchain on this machine: Xcode 26.6, Swift 6.3, XcodeGen 2.46, macOS 26.6.
- The current `/etc/hosts` on this Mac is managed by SwitchHosts and holds three logical groups after a `SWITCHHOSTS_CONTENT_START` marker.
  HostsMaster must be able to adopt those lines.

## 3. Architecture

Three units, mirroring the Fanwright layout that already works for a privileged helper.

```
┌──────────────────────────────┐      XPC (Mach service)       ┌────────────────────────────┐
│ HostsMaster.app (SwiftUI)    │ ────────────────────────────▶ │ HostsMasterHelper (root)   │
│  • owns groups + persistence │  applyManagedSection(text)    │  • rewrites only the       │
│  • renders the managed block │  removeUnmanagedLines(text)   │    HostsMaster section     │
│  • reads /etc/hosts, watches │  flushDNSCache()              │  • atomic write, 0644      │
│    it, shows sync state      │  version()                    │  • flushes the DNS cache   │
└──────────────┬───────────────┘                               └─────────────┬──────────────┘
               │ uses                                                        │ uses
        ┌──────▼──────────────────────────────────────────────────────────────▼──────┐
        │ HostsCore (SwiftPM, pure Swift): models, hosts syntax, managed section merge │
        └─────────────────────────────────────────────────────────────────────────────┘
```

### 3.1 HostsCore (SwiftPM target, no UI, no privileges)

- `HostsGroup`: `id`, `name`, `content` (raw hosts text), `isEnabled`.
  Raw text keeps the editor trivial and lets users paste anything a hosts file accepts, including comments.
- `HostsSyntax`: parses hosts text into lines (`blank`, `comment`, `entry(address, hostnames, comment)`, `invalid(reason)`) and reports issues per line.
  Addresses are validated with `inet_pton`; hostnames are checked leniently (letters, digits, `-`, `_`, `.`).
- `ManagedSection`: the single source of truth for HostsMaster's footprint in the file.
  - `render(groups:)` produces the text between the markers: one `# Group: <name>` header per enabled group followed by its content.
    Returns `nil` when no group is enabled so the file carries no empty section.
    Lines that would collide with a marker are dropped.
  - `HostsFile` splits a file into `before`, `managed` (optional), and `after`, and renders back.
    Replacing or removing the section never touches the other parts.
    A missing end marker is treated as "section runs to end of file" so a damaged file is repaired, not duplicated.
  - `customLines(in:)` lists non-blank lines outside the section that are not part of the stock macOS hosts file.
    This drives the SwitchHosts adoption flow.
  - `removingCustomLines(_:from:)` deletes exact matches outside the section.
- `AppConfiguration` + `ConfigurationStore`: JSON at `~/Library/Application Support/HostsMaster/configuration.json`, atomic writes, tolerant decoding.

### 3.2 HostsMasterHelper (root launchd daemon)

- Registered with `SMAppService.daemon(plistName:)`; the plist is embedded at `Contents/Library/LaunchDaemons`.
- Accepts XPC connections only from a client whose code signature matches the app's identifier and team.
- Four calls: `version`, `applyManagedSection(text?)`, `removeUnmanagedLines(text)`, `flushDNSCache`.
- Every write reads the live file, merges with `HostsCore`, writes to a temporary file next to it with mode `0644`, renames it over `/etc/hosts`, and flushes the DNS cache.
  Reading at write time means an edit made by hand outside the section is never lost to a stale copy in the app.
- Calls are serialised inside the helper so two overlapping applies cannot interleave.
- No watchdog is needed: a hosts file is a static state, not a live control loop.

### 3.3 HostsMaster.app

- SwiftUI, Swift 6 strict concurrency, minimum macOS 15.
- `AppModel` (`@MainActor @Observable`): owns `AppConfiguration`, debounced save, and the `HostsSync` state machine.
- `HostsSync`: derives the desired section from the configuration, coalesces changes with a 400 ms debounce, applies through `HelperClient`, then re-reads the file.
  State is `synced`, `pending`, `applying`, `outOfSync`, or `failed(message)`.
- `HostsFileMonitor`: a `DispatchSource` on `/etc/hosts` that re-reads after external edits.
  Because writes replace the inode, the watcher reopens the path after delete or rename events.
- `HelperClient`: `SMAppService` status, register/unregister, XPC calls with a 3 s timeout, and a short poll while approval is pending so the UI advances the moment the user approves.
- The app is a menu bar app: `LSUIElement` is true, the Dock icon appears while a window is open and disappears when the last window closes.
  On first launch (no configuration file) or while the helper is not approved, the main window opens automatically so the one-time setup is visible.

## 4. Data flow

1. The user toggles a group in the menu or edits it in the window.
2. `AppModel.configuration` changes; the save is debounced and the sync is scheduled.
3. `HostsSync` renders the section and calls `applyManagedSection`.
4. The helper merges into the live file, writes atomically, flushes DNS, replies.
5. The watcher fires; the app re-reads `/etc/hosts` and compares the section with the desired one.
   Equal means `synced`; different means `outOfSync` with a "Re-apply" action.

Errors from the helper surface in a banner and in the menu; the configuration is never rolled back, so a retry is a single click.

## 5. UI

### Menu bar

A native `.menu` style `MenuBarExtra` so it looks and behaves like every other status item.

```
[network icon]
  ✓ Dev MC
    Jurassic Tube
    Ngrok
  ─────────────
  Turn All Off
  ─────────────
  Flush DNS Cache
  Open HostsMaster…
  Settings…            ⌘,
  ─────────────
  Quit HostsMaster     ⌘Q
```

- The icon is filled while any group is active and outlined when none is, so a glance shows whether overrides are live.
- When the helper is not set up, the toggles are replaced by a single "Set Up HostsMaster…" item.
- When the file is out of sync or the last apply failed, a "Re-apply Hosts" item appears above the toggles.

### Main window

`NavigationSplitView` with a sidebar of groups and a detail editor.

- Sidebar rows: a switch, the group name, and the entry count.
  Drag to reorder, context menu or ⌫ to delete, a "+" at the bottom to add.
  A "System" row shows the read-only part of `/etc/hosts`.
  A footer shows the sync state ("In sync", "Applying…", "Out of sync — Re-apply", or the error).
- Detail: name field, enabled toggle, monospaced editor, and a footer with entry count plus any syntax issues.
- A banner above the detail handles setup (install helper, approve in Login Items), drift, and errors.
- Empty state offers "New Group" and, when custom lines exist outside the section, "Import from /etc/hosts".
  Import creates one group per detected block (blocks are separated by blank lines, named from a leading comment when present), enables them, and asks the helper to remove the adopted lines so nothing is applied twice.

### Settings

General (launch at login), Helper (status, install, reinstall, remove), About.

## 6. Persistence

- `~/Library/Application Support/HostsMaster/configuration.json`: groups in order, each with content and enabled flag.
- No other state; the hosts file itself is the applied state.

## 7. Error handling

- Helper not installed or awaiting approval: toggles are disabled with an inline explanation and an install button.
- XPC transport failure or helper error: sync state becomes `failed(message)`; the banner and menu offer retry.
- Unsigned (ad-hoc) build: the helper cannot run; the UI says so and links to the README signing section.
- Hosts file edited by hand inside the section: `outOfSync` with a one-click re-apply; edits outside the section are always preserved.
- Group content with syntax problems is still written (the resolver ignores bad lines), and the editor lists the issues so they get fixed.

## 8. Security

- The helper is the only privileged code and it only ever rewrites the region between HostsMaster's markers, plus exact-match removal of lines the user chose to adopt.
- The XPC listener sets a code signing requirement: same bundle identifier and, when a team identity is present, same team.
- The temporary file is created with `0644` by root, so the replacement never has looser permissions than the original.

## 9. Project layout and tooling

```
HostsMaster/
  project.yml                       # XcodeGen → HostsMaster.xcodeproj (never edited by hand)
  scripts/build.sh                  # Debug/Release build; auto-detects the Apple Development identity
  scripts/release.sh                # Release build, DMG, optional notarization
  scripts/render-icon.swift         # draws the app icon into the asset catalog
  Packages/HostsMasterKit/          # SwiftPM: HostsCore + tests
  Shared/                           # HelperProtocol, CodeSigningInfo (compiled into app and helper)
  Helper/                           # daemon sources + launchd plist
  App/                              # SwiftUI app
  docs/superpowers/specs/           # this spec
```

- Bundle identifiers: app `com.jasperkang.hostsmaster`, helper and Mach service `com.jasperkang.hostsmaster.helper`.
- Tests: Swift Testing in `Packages/HostsMasterKit/Tests`, run with `swift test --package-path Packages/HostsMasterKit`.
  They cover hosts syntax, section rendering and merge (insert, replace, remove, missing end marker, marker collision), custom line detection and removal, import block splitting, and configuration round trips.
- Manual E2E: install the helper, toggle a group, confirm `/etc/hosts` and `dscacheutil -q host -a name <host>`, edit the file by hand and confirm the drift banner.

## 10. Out of scope for v1

- Remote hosts sources (URLs), scheduling, profiles of groups, per-entry toggles.
- Syntax highlighting in the editor.
- Auto-update, localisation, Intel-specific testing.

## 11. Decisions made without Jasper (review these first)

1. Groups are raw text, not structured rows, because pasting is the dominant workflow and the parser still validates every line.
2. Content edits apply automatically after a short debounce rather than through an explicit Apply button, matching SwitchHosts behaviour.
3. The helper only edits its own section; the SwitchHosts leftovers are handled through the explicit Import action, which removes exactly the adopted lines.
4. The app hides from the Dock when no window is open.
5. `build.sh` signs with the Apple Development identity automatically when one exists, since an ad-hoc daemon cannot run.

## 12. Implementation notes

- `SMAppService.status` reports `notFound` for a daemon that was never registered on macOS 26, so the app treats it as "not set up" rather than as a broken registration.
- `SMAppService.register()` throws "Operation not permitted" while the registration is only waiting for Login Items approval.
  The app keeps that error only when the status is still `notRegistered` afterwards.
- The Apple Development certificate's team ID is its OU (`76LYQMZ2YM`), not the ID in parentheses in the certificate name; `scripts/signing.sh` reads the OU.
- The helper's status can flicker while Background Task Management re-registers the job right after approval.
  `HostsSync.reconcile` therefore always follows the file instead of guarding on a pending state, otherwise a change made during the flicker stayed "Applying" until the next status refresh.
- The System Events accessibility tree does not list windows of an accessory-policy app, but the windows exist and render; window-server queries were used to verify them.
- Verified on this Mac: setup, approval, toggle on and off from the menu bar with the resolver reflecting each change within a second, re-apply, window and Settings reopening from the menu bar.
  Not exercised on a real file: the Import flow, because SwitchHosts still owns those lines here; it is covered by unit tests.
- The project was renamed from HostsMaster to Hostswright on 2026-09-14; identifiers in this document keep the original name.
  The rename changed the bundle identifiers, the managed-section markers, and the Application Support folder, so it needs a fresh helper approval and a copied configuration file.
