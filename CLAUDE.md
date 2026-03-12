# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a plugin marketplace for Claude Code — a registry aggregating plugins as git submodules. The root manifest at `.claude-plugin/marketplace.json` records each plugin's name, source path, description, and version. All release tooling lives in `release.sh`.

## Release Commands

```sh
./release.sh update                        # Pull all submodules to latest remote
./release.sh validate                      # Check JSON validity, source paths, version consistency
./release.sh sync                          # Read each plugin's plugin.json and write versions to manifest
./release.sh bump <major|minor|patch>      # Bump metadata.version in marketplace.json
./release.sh add <name> <source> <desc>    # Add new plugin entry (version read from plugin.json)
./release.sh release <major|minor|patch>   # Full flow: update → sync → validate → bump
```

Must be run from the repo root.

## Manifest Structure

`.claude-plugin/marketplace.json`:
- `metadata.version` — the marketplace's own version
- `plugins[].source` — relative path to the plugin root (e.g. `./beepboop/plugin`)
- `plugins[].version` — version as recorded in the manifest (kept in sync with each plugin's `plugin.json`)

Each plugin's canonical version lives at `<source>/.claude-plugin/plugin.json`. The manifest versions are derived from these — run `sync` to pull them in.

## Plugin Layout

| Plugin | Source path | Notes |
|---|---|---|
| beepboop | `./beepboop/plugin` | Has a `generate.sh` for building sounds |
| moodring | `./moodring/plugin` | Has a `generate.sh` for building sounds |
| ideate | `./ideate` | SDLC workflow skills and agents |
| outpost | `./outpost` | MCP orchestration; requires Python |

## Tooling

`release.sh` uses `python3` for all JSON reads/writes (no `jq` dependency). Shell is POSIX (`#!/bin/sh`). Don't add `jq` or `node` dependencies to the release tooling.
