# Claude Code Plugin Marketplace

A curated registry of plugins for [Claude Code](https://claude.ai/code). Each plugin is referenced by its GitHub URL — no submodules, no local clones.

## Setup

### Install the marketplace

Add this repo as a Claude Code plugin:

```sh
claude plugin add https://github.com/devnill/claude-marketplace
```

Once installed, Claude Code will have access to all skills and agents bundled with the marketplace.

### Install individual plugins

Each plugin can also be installed directly. Find the GitHub URL for the plugin you want (listed below) and run:

```sh
claude plugin add <github-url>
```

For plugins in a subdirectory, pass the path:

```sh
claude plugin add <github-url> --path <subdir>
```

---

## Plugins

### beepboop
**Source:** `https://github.com/devnill/beepboop` (path: `plugin`)

Plays sounds on Claude Code hook events and sends desktop notifications. Gives you audio feedback when Claude starts working, finishes a task, or hits an error — so you can step away and come back when something needs your attention.

---

### moodring
**Source:** `https://github.com/devnill/moodring` (path: `plugin`)

Sonifies Claude's self-reported internal state by playing mood-mapped synthesized sounds. As Claude works, it reports its emotional tone and moodring translates that into ambient audio — a subtle, continuous sense of what the model is experiencing.

---

### ideate
**Source:** `https://github.com/ideate-ai/ideate`

A structured SDLC workflow for planning, building, and validating software projects. Ideate walks you through an interview to understand your requirements, decomposes the work into atomic tasks, executes them with specialized agents, and runs continuous review cycles until the project converges. Includes an autopilot mode that loops until zero critical findings remain.

---

### outpost
**Source:** `https://github.com/devnill/outpost`

MCP orchestration infrastructure for delegating work to separate Claude Code instances. Supports both local subprocess and remote process execution, letting you run parallel agents across processes without managing them by hand. Requires Python.

---

### cyberbrain
**Source:** `https://github.com/devnill/cyberbrain`

Knowledge capture and retrieval for Claude Code sessions. Extracts durable knowledge from conversations and files it into an Obsidian vault, then retrieves relevant context in future sessions. Useful for long-running projects where important decisions and context would otherwise be lost between conversations.

---

### hamlet
**Source:** `https://github.com/devnill/hamlet`

Visualizes Claude Code agent activity as a roguelike idle game. Agents appear as characters in a small village, moving around and doing things as Claude works. A lightweight, entertaining way to monitor what's happening in the background.

---

### guardrail
**Source:** `https://github.com/devnill/guardrail`

Automates permission allowlists and sandbox configuration for Claude Code projects. Analyzes your project's tech stack and generates tuned permission rules so Claude operates with the minimum access it actually needs. Includes an audit skill to review and clean up existing rules.

---

## Maintainer Notes

The manifest lives at `.claude-plugin/marketplace.json`. Plugin versions are kept in sync with each plugin's remote `plugin.json` via `release.sh`.

```sh
./release.sh sync                              # Pull remote versions into the manifest
./release.sh validate                          # Check JSON validity and remote reachability
./release.sh add <name> <url> [<path>] <desc>  # Add a new plugin
./release.sh release <major|minor|patch>       # sync → validate → bump version
```
