# Viewglass

Viewglass is a CLI-first iOS runtime inspector compatible with `LookinServer` and designed for automation, AI workflows, and day-to-day UI debugging.

It is built on top of the open-source Lookin ecosystem, but the project direction here is broader than the original macOS GUI product:

- inspect live iOS view hierarchies from the terminal
- query nodes and attributes in structured output
- capture screen and node screenshots
- export hierarchy data and reports
- diagnose discovery failures with per-port probe output
- support future skills and MCP workflows

## Chinese Guide

- 中文使用说明: [Docs/Viewglass-README-CN.md](Docs/Viewglass-README-CN.md)
- 如果你想直接开始，先看下面的 `Quick Start`，再看中文文档里的详细命令示例

## Requirements

- macOS 12.0+
- Xcode 14+ if you install from source or via Homebrew source build
- an iOS app that integrates [ViewglassServer](https://github.com/WZBbiao/ViewglassServer)

## Install

### Homebrew

```bash
brew tap WZBbiao/tap
brew install viewglass
```

Notes:
- the current Homebrew formula builds from source
- first install takes a few minutes because it compiles Swift code locally

### Prebuilt Release Binary

Download the latest binary from [Releases](https://github.com/WZBbiao/viewglass/releases).

```bash
# Apple Silicon
curl -fsSL https://github.com/WZBbiao/viewglass/releases/latest/download/viewglass-macos-arm64.tar.gz | tar xz
sudo mv viewglass /usr/local/bin/

# Intel
curl -fsSL https://github.com/WZBbiao/viewglass/releases/latest/download/viewglass-macos-x86_64.tar.gz | tar xz
sudo mv viewglass /usr/local/bin/
```

### One-liner Installer

```bash
curl -fsSL https://raw.githubusercontent.com/WZBbiao/viewglass/main/scripts/install.sh | bash
```

### Build From Source

```bash
git clone https://github.com/WZBbiao/viewglass.git
cd viewglass
make install
```

## Configure Your App

Viewglass does not instrument apps by itself. The target iOS app must expose Lookin-compatible runtime inspection data through `LookinServer`.

For app-side integration, use the standalone
[ViewglassServer](https://github.com/WZBbiao/ViewglassServer) repository.

Only the essentials are kept here:
- integrate `ViewglassServer` in `Debug`
- keep importing `LookinServer` in app code
- start with Simulator first if you are validating a new integration
- if the CLI finds no apps, first verify the app actually integrated and started `LookinServer`

## Quick Start

```bash
# 1. Scan for inspectable apps
viewglass scan
viewglass scan --verbose

# 2. List discovered apps
viewglass apps list
viewglass apps list --json

# 3. Connect by bundle id
viewglass session connect com.example.app

# 4. Inspect hierarchy
viewglass hierarchy dump
viewglass hierarchy dump --json

# 5. Query nodes
viewglass query "UIButton AND .visible"
viewglass node get 4

# 6. Capture screenshots
viewglass screenshot screen -o screen.png
viewglass screenshot node 4 -o node.png

# 7. Run diagnostics
viewglass diagnose all

# 8. Export a report
viewglass export report -o report.md
```

`viewglass screenshot` now captures high-resolution PNGs through the
`ViewglassServer` protocol for both simulator and physical devices. It no longer
depends on `simctl` or `idevicescreenshot`.

After `session connect`, the current session is persisted to:

```text
~/.viewglass/session.json
```

That means most later commands can omit `--session`.

## Common Workflow

### 1. Discover apps

```bash
viewglass scan
viewglass scan --verbose
viewglass apps list --json
```

### 2. Connect

```bash
viewglass session connect com.example.app
viewglass session status
```

### 3. Read hierarchy

```bash
viewglass hierarchy dump
viewglass node get 4
viewglass query ".visible AND UILabel"
```

### 4. Mutate or refresh

```bash
viewglass attr set 4 alpha 0.5
viewglass console eval setNeedsLayout --node-id 4
viewglass refresh
```

### 5. Export and diagnose

```bash
viewglass export hierarchy -o hierarchy.json
viewglass export report -o report.md
viewglass diagnose overlap
viewglass diagnose all --json
```

## Main Command Groups

- `apps`: discover inspectable apps
- `session`: connect, inspect, and disconnect sessions
- `hierarchy`: print the full tree
- `node`: inspect a single node
- `query`: filter nodes with an expression language
- `attr`: get or set attributes
- `console`: invoke methods on objects in the running app
- `refresh`: reload hierarchy from the app
- `screenshot`: capture screenshots
- `export`: write hierarchy/report output to files
- `diagnose`: run overlap, hidden-interactive, offscreen, and aggregate checks
- `scan`: discovery scan with optional per-port diagnostics

## Output Modes

Most commands support:

- human-readable text output by default
- `--json` for scripts, AI agents, and automation

Examples:

```bash
viewglass apps list --json
viewglass hierarchy dump --json
viewglass diagnose all --json
```

## Current Scope

Today, the project provides:

- a working `viewglass` CLI
- release assets for macOS arm64 and x86_64
- a Homebrew tap
- structured JSON output for automation
- simulator and USB device discovery
- live screen and node screenshots

Planned next layers:

- skills-oriented workflows
- MCP server
- broader runtime inspection depth

## Docs

- English CLI reference: [Docs/Viewglass-README.md](Docs/Viewglass-README.md)
- 中文 CLI 文档: [Docs/Viewglass-README-CN.md](Docs/Viewglass-README-CN.md)
- Brand and repo strategy: [Docs/Brand-and-Repository-Strategy.md](Docs/Brand-and-Repository-Strategy.md)
- Product roadmap: [Docs/Roadmap.md](Docs/Roadmap.md)

## Project Governance

- Contributing: [CONTRIBUTING.md](CONTRIBUTING.md)
- Code of Conduct: [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- Security: [SECURITY.md](SECURITY.md)
- Support: [SUPPORT.md](SUPPORT.md)
