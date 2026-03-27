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
- `plugins[].source` — where to fetch the plugin; one of:
  - `{ "source": "github", "repo": "owner/repo" }` — plugin at repo root
  - `{ "source": "git-subdir", "url": "https://github.com/owner/repo", "path": "subdir" }` — plugin in a subdirectory
- `plugins[].version` — version as recorded in the manifest (kept in sync with each plugin's remote `plugin.json`)

Each plugin's canonical version lives in its remote `.claude-plugin/plugin.json`. Run `sync` to pull remote versions into the manifest.

## Plugin Registry

| Plugin | Source | Notes |
|---|---|---|
| beepboop | `git-subdir` → `devnill/beepboop`, path `plugin` | Has a `generate.sh` for building sounds |
| moodring | `git-subdir` → `devnill/moodring`, path `plugin` | Has a `generate.sh` for building sounds |
| ideate | `github` → `ideate-ai/ideate` | SDLC workflow skills and agents |
| outpost | `github` → `devnill/outpost` | MCP orchestration; requires Python |
| hamlet | `github` → `devnill/hamlet` | Visualizes Claude Code agent activity as a roguelike idle game |

## Tooling

`release.sh` uses `python3` + `urllib` for all JSON reads/writes and HTTP fetches (no `jq`, `curl`, or `node` dependencies). Shell is POSIX (`#!/bin/sh`).
