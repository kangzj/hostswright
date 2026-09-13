<p align="center">
  <img src="App/Assets.xcassets/AppIcon.appiconset/icon_256x256.png" width="128" alt="HostsMaster icon">
</p>

<h1 align="center">HostsMaster</h1>

<p align="center">
  <strong>Switch groups of <code>/etc/hosts</code> entries on and off from the menu bar.</strong><br>
  One approval when you first launch it, then every change lands instantly, with no password prompts.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-15%2B-000?logo=apple" alt="macOS 15 or later">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="Swift 6">
  <img src="https://img.shields.io/badge/SwiftUI-native-0A84FF" alt="SwiftUI">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-green" alt="MIT license"></a>
</p>

## Why HostsMaster

Pointing a hostname at a different machine is still the fastest way to test a staging server, a local build, or a tunnel.
Doing it by hand means `sudo`, a text editor, remembering to flush the DNS cache, and undoing it all afterwards.

HostsMaster keeps those entries in named groups and turns them into checkboxes in your menu bar.

- **Groups, not files.** Each group is a few lines of hosts entries with a name. Turn on one, several, or none.
- **Instant.** The moment you tick a group, `/etc/hosts` is rewritten and the DNS cache is flushed, so browsers and command line tools see it right away.
- **One-time permission.** A tiny root helper, approved once in System Settings, does the writing. You are never asked for a password again.
- **Your file stays yours.** HostsMaster only ever rewrites the section between its own markers. Everything else in `/etc/hosts` is left exactly as it was, and edits you make by hand outside that section are preserved.
- **Native.** SwiftUI, a real menu bar dropdown, light and dark mode, keyboard shortcuts. It looks and behaves like part of macOS.
- **Free and open source.** MIT licensed, no telemetry, no account.

## Features

### Menu bar
Click the icon to see every group with a checkmark next to the active ones.
Tick and untick as many as you like.
The icon fills in while any group is active, so you can tell at a glance whether overrides are live.
Turn All Off, Flush DNS Cache, and Open HostsMaster live in the same menu.

### Groups
The main window lists your groups in a sidebar with a switch on each row.
The editor is a plain monospaced text area: paste anything a hosts file accepts, including comments.
Bad lines are flagged with the line number and the reason, and the footer shows how many entries the group carries.
Drag to reorder, press ⌫ to delete, ⌘N to add.

### Keeps itself honest
HostsMaster watches `/etc/hosts`.
If another tool or a manual edit changes its section, the window and the menu show "Re-apply" until the file matches your groups again.

### Import from an existing setup
If you are coming from SwitchHosts or a hand-maintained file, the System view shows the custom lines it found and offers to import them.
Each blank-line-separated block becomes a group, named after the shared domain or the comment above it, and the adopted lines are removed from the system section so nothing is applied twice.

## How it works

```
HostsMaster.app (menu bar, SwiftUI)  ──XPC──▶  HostsMasterHelper (root, launchd)
  owns groups, renders the section              merges the section into /etc/hosts,
  watches the file, shows sync state            writes atomically, flushes DNS
```

- The app never writes `/etc/hosts` itself.
- The helper is registered through Apple's `SMAppService` and started on demand by launchd.
  It accepts connections only from HostsMaster signed by the same team.
- Every write re-reads the live file, replaces only the region between the HostsMaster markers, writes a temporary file with the original permissions, and renames it into place.
- After each write it runs `dscacheutil -flushcache` and sends `SIGHUP` to `mDNSResponder`.

What the managed section looks like inside `/etc/hosts`:

```
# ==== HostsMaster: managed section, edits here are overwritten ====
# Group: Staging
10.0.0.5 app.example.com
# Group: Tunnel
127.0.0.1 me.tunnel.dev
# ==== HostsMaster: end of managed section ====
```

## Requirements

macOS 15 Sequoia or later.
Tested on macOS 26 with Apple Silicon; Intel Macs should work but are untested.

## Install

Download the DMG from Releases, drag HostsMaster to Applications, and open it.
The first launch asks you to click Set Up and then turn on HostsMaster in System Settings › General › Login Items & Extensions.
That is the only time macOS will ask.

## Build from source

Requirements: Xcode 26 with the license accepted, and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
git clone https://github.com/kangzj/hostsmaster.git
cd HostsMaster
scripts/build.sh            # Debug build in build/Build/Products/Debug/HostsMaster.app
scripts/build.sh Release
scripts/release.sh          # DMG in dist/
```

### Building a copy that can edit hosts

macOS only lets launchd run a privileged helper whose signature comes from an Apple-issued certificate.
An ad-hoc build launches and lets you edit groups, but shows "Unavailable in this unsigned build" because launchd refuses to start the helper.

A free Apple Development certificate is enough, no paid membership required:

1. In Xcode, open Settings › Accounts, add your Apple ID, and select the Personal Team.
2. Click Manage Certificates…, then + › Apple Development.
3. Run `scripts/build.sh` again. It finds the certificate and its team automatically.

To use a specific identity instead:

```sh
HOSTSMASTER_SIGNING_IDENTITY="Developer ID Application" HOSTSMASTER_SIGNING_TEAM=TEAMID scripts/build.sh
```

Keep one copy of the app on disk.
launchd remembers the helper per registration, so if you move or rebuild the app and toggles stop working, open Settings › Helper and click Reinstall.

The Xcode project is generated from `project.yml`; do not edit `HostsMaster.xcodeproj` by hand.
The app icon is drawn by `scripts/render-icon.swift`; run `swift scripts/render-icon.swift App/Assets.xcassets/AppIcon.appiconset` after changing it.

Tests cover hosts syntax, section rendering and merging, import, and persistence:

```sh
swift test --package-path Packages/HostsMasterKit
```

## Uninstall

Open Settings › Helper and click Remove, then quit the app and delete it.
Removing the helper leaves `/etc/hosts` as it is; turn all groups off first if you want the section gone.

## License

MIT. See [LICENSE](LICENSE).
