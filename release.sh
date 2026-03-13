#!/bin/sh
set -e

MANIFEST=".claude-plugin/marketplace.json"

die() { echo "ERROR: $1" >&2; exit 1; }

# Ensure we're at the repo root
[ -f "$MANIFEST" ] || die "Must be run from the repo root (marketplace.json not found)"

cmd_validate() {
    echo "Validating manifest..."

    result=$(python3 - <<'EOF'
import json, sys
try:
    from urllib.request import urlopen
    from urllib.error import URLError
except ImportError:
    from urllib2 import urlopen, URLError

manifest_path = ".claude-plugin/marketplace.json"
try:
    with open(manifest_path) as f:
        manifest = json.load(f)
except Exception as e:
    print(f"FAIL: marketplace.json is invalid JSON: {e}")
    sys.exit(1)

errors = []
warnings = []

def raw_url(source, file):
    """Build a raw.githubusercontent.com URL for a file inside a plugin's repo."""
    src_type = source.get("source", "")
    if src_type == "github":
        repo = source.get("repo", "")
        return f"https://raw.githubusercontent.com/{repo}/main/{file}"
    elif src_type == "git-subdir":
        url = source.get("url", "").replace("https://github.com/", "https://raw.githubusercontent.com/")
        path = source.get("path", "")
        return f"{url}/main/{path}/{file}" if path else f"{url}/main/{file}"
    elif src_type == "url":
        url = source.get("url", "").replace("https://github.com/", "https://raw.githubusercontent.com/")
        url = url.removesuffix(".git")
        return f"{url}/main/{file}"
    return ""

for plugin in manifest.get("plugins", []):
    name = plugin.get("name", "<unknown>")
    source = plugin.get("source")
    manifest_version = plugin.get("version", "")

    if not source or not isinstance(source, dict):
        errors.append(f"{name}: missing or invalid 'source' field")
        continue

    fetch_url = raw_url(source, ".claude-plugin/plugin.json")
    if not fetch_url:
        errors.append(f"{name}: unrecognized source type '{source.get('source')}'")
        continue

    try:
        with urlopen(fetch_url, timeout=10) as resp:
            plugin_data = json.loads(resp.read().decode())
    except URLError as e:
        errors.append(f"{name}: could not fetch plugin.json from '{fetch_url}': {e}")
        continue
    except Exception as e:
        errors.append(f"{name}: invalid plugin.json at '{fetch_url}': {e}")
        continue

    plugin_version = plugin_data.get("version", "")
    if manifest_version != plugin_version:
        warnings.append(f"{name}: manifest version '{manifest_version}' != remote version '{plugin_version}'")
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
    echo "Syncing plugin versions from remote plugin.json files..."
    python3 - <<'EOF'
import json, sys
try:
    from urllib.request import urlopen
    from urllib.error import URLError
except ImportError:
    from urllib2 import urlopen, URLError

manifest_path = ".claude-plugin/marketplace.json"
with open(manifest_path) as f:
    manifest = json.load(f)

def raw_url(source, file):
    """Build a raw.githubusercontent.com URL for a file inside a plugin's repo."""
    src_type = source.get("source", "")
    if src_type == "github":
        repo = source.get("repo", "")
        return f"https://raw.githubusercontent.com/{repo}/main/{file}"
    elif src_type == "git-subdir":
        url = source.get("url", "").replace("https://github.com/", "https://raw.githubusercontent.com/")
        path = source.get("path", "")
        return f"{url}/main/{path}/{file}" if path else f"{url}/main/{file}"
    elif src_type == "url":
        url = source.get("url", "").replace("https://github.com/", "https://raw.githubusercontent.com/")
        url = url.removesuffix(".git")
        return f"{url}/main/{file}"
    return ""

changed = []
for plugin in manifest.get("plugins", []):
    name = plugin.get("name", "<unknown>")
    source = plugin.get("source")

    if not source or not isinstance(source, dict):
        print(f"  SKIP {name}: missing or invalid 'source' field")
        continue

    fetch_url = raw_url(source, ".claude-plugin/plugin.json")
    if not fetch_url:
        print(f"  SKIP {name}: unrecognized source type '{source.get('source')}'")
        continue

    try:
        with urlopen(fetch_url, timeout=10) as resp:
            plugin_data = json.loads(resp.read().decode())
    except Exception as e:
        print(f"  SKIP {name}: could not fetch plugin.json: {e}")
        continue

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
    url="$2"
    # Optional: if 4th arg exists, it's the path and 5th is desc; otherwise 3rd is desc
    if [ -n "$5" ]; then
        plugin_path="$3"
        desc="$4 $5"
    elif [ -n "$4" ]; then
        # Convention: if 4 args given, $3 is plugin_path and $4 is desc
        plugin_path="$3"
        desc="$4"
    else
        plugin_path=""
        desc="$3"
    fi

    [ -n "$name" ] || die "usage: add <name> <url> [<path>] <desc>"
    [ -n "$url" ]  || die "usage: add <name> <url> [<path>] <desc>"
    [ -n "$desc" ] || die "usage: add <name> <url> [<path>] <desc>"

    python3 - "$name" "$url" "$plugin_path" "$desc" <<'EOF'
import json, sys
try:
    from urllib.request import urlopen
    from urllib.error import URLError
except ImportError:
    from urllib2 import urlopen, URLError

name, url, plugin_path, desc = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
manifest_path = ".claude-plugin/marketplace.json"

# Derive owner/repo from GitHub URL (e.g. https://github.com/owner/repo)
def github_repo(github_url):
    return github_url.replace("https://github.com/", "").strip("/")

def raw_url(github_url, path, file):
    base = github_url.replace("https://github.com/", "https://raw.githubusercontent.com/")
    if path:
        return f"{base}/main/{path}/{file}"
    return f"{base}/main/{file}"

fetch_url = raw_url(url, plugin_path, ".claude-plugin/plugin.json")
try:
    with urlopen(fetch_url, timeout=10) as resp:
        plugin_data = json.loads(resp.read().decode())
except Exception as e:
    print(f"ERROR: could not fetch plugin.json from '{fetch_url}': {e}", file=sys.stderr)
    sys.exit(1)

version = plugin_data.get("version", "0.0.0")

with open(manifest_path) as f:
    manifest = json.load(f)

for existing in manifest.get("plugins", []):
    if existing.get("name") == name:
        print(f"ERROR: plugin '{name}' already exists in manifest", file=sys.stderr)
        sys.exit(1)

if plugin_path:
    source = {"source": "git-subdir", "url": url, "path": plugin_path}
else:
    source = {"source": "github", "repo": github_repo(url)}

entry = {"name": name, "source": source, "description": desc, "version": version}
manifest["plugins"].append(entry)

with open(manifest_path, "w") as f:
    json.dump(manifest, f, indent=2)
    f.write("\n")

print(f"Added '{name}' @ {version} from '{url}'")
EOF
}

cmd_release() {
    bump_type="$1"
    case "$bump_type" in
        major|minor|patch) ;;
        *) die "release type must be one of: major, minor, patch" ;;
    esac

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
    validate) cmd_validate ;;
    sync)     cmd_sync ;;
    bump)     cmd_bump "$2" ;;
    add)      cmd_add "$2" "$3" "$4" "$5" "$6" ;;
    release)  cmd_release "$2" ;;
    *)
        echo "Usage: $0 <command> [args]"
        echo ""
        echo "Commands:"
        echo "  validate                           Check manifest: JSON validity, remote reachability, version consistency"
        echo "  sync                               Fetch each plugin's remote plugin.json and update manifest versions"
        echo "  bump <major|minor|patch>           Bump marketplace metadata.version"
        echo "  add <name> <url> [<path>] <desc>   Add a new plugin entry (version fetched from GitHub)"
        echo "  release <major|minor|patch>        Full flow: sync → validate → bump"
        exit 1
        ;;
esac
