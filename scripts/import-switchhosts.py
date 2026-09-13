#!/usr/bin/env python3
"""Copy every SwitchHosts group, including switched-off ones, into HostsMaster's configuration.

Usage: quit HostsMaster, run `scripts/import-switchhosts.py`, then launch HostsMaster again.
Existing HostsMaster groups are kept; a SwitchHosts group with the same name is skipped.
"""
import json
import os
import sys
import uuid

SWITCHHOSTS = os.path.expanduser("~/.SwitchHosts")
CONFIG = os.path.expanduser("~/Library/Application Support/HostsMaster/configuration.json")


def switchhosts_groups():
    manifest = json.load(open(os.path.join(SWITCHHOSTS, "manifest.json")))
    for item in manifest["root"]:
        if item.get("type") != "local" or "contentFile" not in item:
            continue
        with open(os.path.join(SWITCHHOSTS, item["contentFile"])) as handle:
            content = handle.read().strip("\n")
        yield {"id": str(uuid.uuid4()).upper(), "name": item["title"], "content": content, "isEnabled": bool(item.get("on"))}


def main():
    if not os.path.isdir(SWITCHHOSTS):
        sys.exit(f"No SwitchHosts data at {SWITCHHOSTS}")
    existing = json.load(open(CONFIG))["groups"] if os.path.exists(CONFIG) else []
    taken = {group["name"] for group in existing}
    added = [group for group in switchhosts_groups() if group["name"] not in taken]
    os.makedirs(os.path.dirname(CONFIG), exist_ok=True)
    with open(CONFIG, "w") as handle:
        json.dump({"groups": existing + added}, handle, indent=2, sort_keys=True)
    for group in added:
        print(f"{'on ' if group['isEnabled'] else 'off'}  {group['name']}  ({len(group['content'].splitlines())} lines)")
    print(f"Imported {len(added)} group(s); {len(existing)} already present.")


if __name__ == "__main__":
    main()
