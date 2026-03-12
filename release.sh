#!/bin/sh
set -e

MANIFEST=".claude-plugin/marketplace.json"

die() { echo "ERROR: $1" >&2; exit 1; }

# Ensure we're at the repo root
[ -f "$MANIFEST" ] || die "Must be run from the repo root (marketplace.json not found)"

cmd_update() {
    echo "Updating submodules..."
    git submodule update --remote --merge
    echo "Done."
}

cmd_validate() {
    echo "Validating manifest..."
    failed=0

    result=$(python3 - <<'EOF'
import json, sys

manifest_path = ".claude-plugin/marketplace.json"
try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception as e:
    print(f"FAIL: marketplace.json is invalid JSON: {e}")
    sys.exit(1)

errors = []
warnings = []

for plugin in manifest.get("plugins", []):
    name = plugin.get("name", "<unknown>")
    source = plugin.get("source", "")
    manifest_version = plugin.get("version", "")

    if not source:
        errors.append(f"{name}: missing 'source' field")
        continue

    import os
    if not os.path.isdir(source):
        errors.append(f"{name}: source path '{source}' does not exist")
        continue

    plugin_json_path = f"{source}/.claude-plugin/plugin.json"
    if not os.path.isfile(plugin_json_path):
        errors.append(f"{name}: plugin.json not found at '{plugin_json_path}'")
        continue

    try:
        with open(plugin_json_path) as f:
            plugin_data = json.load(f)
    except Exception as e:
        errors.append(f"{name}: plugin.json is invalid JSON: {e}")
        continue

    plugin_version = plugin_data.get("version", "")
    if manifest_version != plugin_version:
        warnings.append(f"{name}: manifest version '{manifest_version}' != plugin.json version '{plugin_version}'")
    else:
        print(f"  OK  {name} @ {plugin_version}")

for w in warnings:
    print(f"  WARN {w}")
for e in errors:
    print(f"  FAIL {e}")

if errors:
    sys.exit(1)
if warnings:
    sys.exit(2)
EOF
    )
    exit_code=$?
    echo "$result"
    if [ $exit_code -eq 1 ]; then
        echo "Validation FAILED."
        return 1
    elif [ $exit_code -eq 2 ]; then
        echo "Validation passed with warnings (version mismatches — run './release.sh sync' to fix)."
        return 0
    else
        echo "Validation passed."
        return 0
    fi
}

cmd_sync() {
    echo "Syncing plugin versions from plugin.json files..."
    python3 - <<'EOF'
import json, sys, os

manifest_path = ".claude-plugin/marketplace.json"
with open(manifest_path) as f:
    manifest = json.load(f)

changed = []
for plugin in manifest.get("plugins", []):
    name = plugin.get("name", "<unknown>")
    source = plugin.get("source", "")
    plugin_json_path = f"{source}/.claude-plugin/plugin.json"

    if not os.path.isfile(plugin_json_path):
        print(f"  SKIP {name}: plugin.json not found at '{plugin_json_path}'")
        continue

    with open(plugin_json_path) as f:
        plugin_data = json.load(f)

    new_version = plugin_data.get("version", "")
    old_version = plugin.get("version", "")

    if old_version != new_version:
        plugin["version"] = new_version
        changed.append(f"  {name}: {old_version} -> {new_version}")
    else:
        print(f"  OK  {name} @ {new_version} (unchanged)")

if changed:
    with open(manifest_path, "w") as f:
        json.dump(manifest, f, indent=2)
        f.write("\n")
    print("Updated:")
    for c in changed:
        print(c)
else:
    print("No changes needed.")
EOF
}

cmd_bump() {
    bump_type="$1"
    case "$bump_type" in
        major|minor|patch) ;;
        *) die "bump type must be one of: major, minor, patch" ;;
    esac

    python3 - "$bump_type" <<'EOF'
import json, sys

bump_type = sys.argv[1]
manifest_path = ".claude-plugin/marketplace.json"

with open(manifest_path) as f:
    manifest = json.load(f)

version = manifest["metadata"]["version"]
parts = version.split(".")
if len(parts) != 3:
    print(f"ERROR: unexpected version format '{version}'", file=sys.stderr)
    sys.exit(1)

major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

if bump_type == "major":
    major += 1; minor = 0; patch = 0
elif bump_type == "minor":
    minor += 1; patch = 0
else:
    patch += 1

new_version = f"{major}.{minor}.{patch}"
manifest["metadata"]["version"] = new_version

with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

print(f"Bumped marketplace version: {version} -> {new_version}")
EOF
}

cmd_add() {
    name="$1"
    source="$2"
    desc="$3"
    [ -n "$name" ] || die "usage: add <name> <source> <desc>"
    [ -n "$source" ] || die "usage: add <name> <source> <desc>"
    [ -n "$desc" ] || die "usage: add <name> <source> <desc>"

    python3 - "$name" "$source" "$desc" <<'EOF'
import json, sys, os

name, source, desc = sys.argv[1], sys.argv[2], sys.argv[3]
manifest_path = ".claude-plugin/marketplace.json"

if not os.path.isdir(source):
    print(f"ERROR: source path '{source}' does not exist", file=sys.stderr)
    sys.exit(1)

plugin_json_path = f"{source}/.claude-plugin/plugin.json"
if not os.path.isfile(plugin_json_path):
    print(f"ERROR: plugin.json not found at '{plugin_json_path}'", file=sys.stderr)
    sys.exit(1)

with open(plugin_json_path) as f:
    plugin_data = json.load(f)

version = plugin_data.get("version", "0.0.0")

with open(manifest_path) as f:
    manifest = json.load(f)

for existing in manifest.get("plugins", []):
    if existing.get("name") == name:
        print(f"ERROR: plugin '{name}' already exists in manifest", file=sys.stderr)
        sys.exit(1)

manifest["plugins"].append({
    "name": name,
    "source": source,
    "description": desc,
    "version": version
})

with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

print(f"Added '{name}' @ {version} from '{source}'")
EOF
}

cmd_release() {
    bump_type="$1"
    case "$bump_type" in
        major|minor|patch) ;;
        *) die "release type must be one of: major, minor, patch" ;;
    esac

    echo "==> update"
    cmd_update

    echo ""
    echo "==> sync"
    cmd_sync

    echo ""
    echo "==> validate"
    cmd_validate

    echo ""
    echo "==> bump $bump_type"
    cmd_bump "$bump_type"

    echo ""
    echo "Release complete."
}

case "$1" in
    update)   cmd_update ;;
    validate) cmd_validate ;;
    sync)     cmd_sync ;;
    bump)     cmd_bump "$2" ;;
    add)      cmd_add "$2" "$3" "$4" ;;
    release)  cmd_release "$2" ;;
    *)
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  update                        Pull all submodules to latest remote"
        echo "  validate                      Check manifest: JSON validity, paths, version consistency"
        echo "  sync                          Read each plugin's plugin.json and update manifest versions"
        echo "  bump <major|minor|patch>      Bump marketplace metadata.version"
        echo "  add <name> <source> <desc>    Add a new plugin entry to the manifest"
        echo "  release <major|minor|patch>   Full flow: update → sync → validate → bump"
        exit 1
        ;;
esac
