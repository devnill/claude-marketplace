# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a plugin marketplace for Claude Code — a registry of plugins referenced by their GitHub URLs. The root manifest at `.claude-plugin/marketplace.json` records each plugin's name, GitHub URL, optional subdirectory path, description, and version. All release tooling lives in `release.sh`.

Plugin versions are fetched directly from each plugin's remote `plugin.json` via `raw.githubusercontent.com` — no local clones or submodules.

## Release Commands

```sh
./release.sh sync                              # Fetch each plugin's remote plugin.json and update manifest versions
./release.sh validate                          # Check JSON validity, remote reachability, version consistency
./release.sh bump <major|minor|patch>          # Bump metadata.version in marketplace.json
./release.sh add <name> <url> [<path>] <desc>  # Add new plugin entry (version fetched from GitHub)
./release.sh release <major|minor|patch>       # Full flow: sync → validate → bump
```

Must be run from the repo root.

## Manifest Structure

`.claude-plugin/marketplace.json`:
- `metadata.version` — the marketplace's own version
- `plugins[].url` — GitHub repo URL (e.g. `https://github.com/devnill/beepboop`)
- `plugins[].path` — optional subdirectory within the repo where the plugin root lives (e.g. `plugin`); omit if the plugin root is the repo root
- `plugins[].version` — version as recorded in the manifest (kept in sync with each plugin's remote `plugin.json`)

Each plugin's canonical version lives at `<url>/blob/main/<path>/.claude-plugin/plugin.json`. Run `sync` to pull remote versions into the manifest.

## Plugin Registry

| Plugin | URL | Path | Notes |
|---|---|---|---|
| beepboop | `https://github.com/devnill/beepboop` | `plugin` | Has a `generate.sh` for building sounds |
| moodring | `https://github.com/devnill/moodring` | `plugin` | Has a `generate.sh` for building sounds |
| ideate | `https://github.com/devnill/ideate` | _(root)_ | SDLC workflow skills and agents |
| outpost | `https://github.com/devnill/outpost` | _(root)_ | MCP orchestration; requires Python |

## Tooling

`release.sh` uses `python3` + `urllib` for all JSON reads/writes and HTTP fetches (no `jq`, `curl`, or `node` dependencies). Shell is POSIX (`#!/bin/sh`).
