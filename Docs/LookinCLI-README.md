# Lookin CLI

Lookin CLI (`lookin-cli`) is a programmable command-line interface for [Lookin](https://lookin.work) — the iOS view hierarchy inspector. It exposes Lookin's inspection capabilities in a machine-friendly way, suitable for scripts, CI pipelines, and AI-driven workflows.

## Requirements

- macOS 12.0+
- Swift 5.9+
- iOS app with [LookinServer](https://github.com/QMUI/LookinServer) integrated (for live inspection)

## Build

```bash
swift build
```

Binary is at `.build/debug/lookin-cli`.

Release build:

```bash
swift build -c release
```

## Quick Start

```bash
# Scan for running apps with LookinServer
lookin-cli scan

# List inspectable apps
lookin-cli apps list
lookin-cli apps list --json

# Connect and dump hierarchy
lookin-cli hierarchy dump --session 47164
lookin-cli hierarchy dump --session 47164 --json

# Query nodes
lookin-cli query "UIButton" --session 47164
lookin-cli query ".visible AND UILabel" --session 47164 --json

# Run diagnostics
lookin-cli diagnose all --session 47164
```

## Commands

### apps

Discover and list inspectable iOS apps on connected simulators and devices.

```bash
lookin-cli apps list              # Human-readable output
lookin-cli apps list --json       # JSON output
lookin-cli apps list --mock       # Use mock data (for testing)
```

Output example:

```
[SIM] LookinTestApp — com.lookin.testapp (port:47164)
[DEV] AnotherApp — com.example.app (port:47175)
```

### session

Manage inspection sessions.

```bash
lookin-cli session connect <app-id>              # Connect by bundle ID
lookin-cli session connect com.example.app --json
lookin-cli session status                         # Show current session
lookin-cli session disconnect --session <id>      # Disconnect
```

### hierarchy

Fetch and display the full view hierarchy.

```bash
lookin-cli hierarchy dump --session 47164
lookin-cli hierarchy dump --session 47164 --json
lookin-cli hierarchy dump --session 47164 --max-depth 3   # Limit tree depth
```

Human-readable output:

```
App: LookinTestApp (com.lookin.testapp)
Nodes: 24
Screen: 390x844 @3x

UIWindow (oid:1) frame:(0,0,390,844)
  UIView (oid:2) frame:(0,0,390,844)
    UILabel (oid:3) frame:(20,100,200,30)
    UIButton (oid:4) frame:(50,400,100,44)
      UILabel (oid:5) frame:(10,5,80,20)
```

### node

Inspect individual nodes by OID (object identifier).

```bash
lookin-cli node get 4 --session 47164
lookin-cli node get 4 --session 47164 --json
```

Output:

```
UIButton (oid:4)
  Address:    0x600004
  Frame:      (50, 400, 100, 44)
  Bounds:     (0, 0, 100, 44)
  Hidden:     false
  Alpha:      1.0
  Interactive:true
  A11y ID:    tapButton
  Children:   1
```

### query

Query nodes using a powerful expression language.

```bash
lookin-cli query "UILabel" --session 47164
lookin-cli query ".visible AND UIButton" --session 47164 --json
lookin-cli query "UIButton" --session 47164 --count    # Just count
```

#### Query Syntax

| Expression | Description |
|------------|-------------|
| `UILabel` | Exact class name match |
| `UILabel*` | Class name prefix |
| `*Label` | Class name suffix |
| `class:UIButton` | Explicit class match |
| `oid:123` | Match by object ID |
| `tag:42` | Match by tag |
| `depth:3` | Match by tree depth |
| `#loginButton` | Match by accessibility identifier |
| `@"Submit"` | Match by accessibility label |
| `.visible` | Visible nodes only |
| `.hidden` | Hidden nodes only |
| `.interactive` | User interaction enabled |
| `parent:UIView` | Match by parent class |
| `A AND B` | Logical AND |
| `A OR B` | Logical OR |
| `NOT A` | Logical NOT |
| `(A OR B) AND C` | Grouping with parentheses |

Examples:

```bash
lookin-cli query "UIButton AND .visible" --session 47164
lookin-cli query "(UIButton OR UILabel) AND .visible" --session 47164
lookin-cli query "#submitButton" --session 47164
lookin-cli query "@\"Tap me\"" --session 47164
lookin-cli query "parent:UIStackView" --session 47164
lookin-cli query "NOT UIView" --session 47164
```

### screenshot

Capture screenshots.

```bash
lookin-cli screenshot screen --session 47164 -o screen.png
lookin-cli screenshot node 4 --session 47164 -o button.png
```

### refresh

Refresh the view hierarchy from the connected app.

```bash
lookin-cli refresh --session 47164
lookin-cli refresh --session 47164 --json
```

### attr

Get or set node attributes.

```bash
# Get all attributes
lookin-cli attr get 4 --session 47164
lookin-cli attr get 4 --session 47164 --json

# Set an attribute
lookin-cli attr set 4 alpha 0.5 --session 47164
lookin-cli attr set 4 hidden true --session 47164

# Dangerous mutations require --force
lookin-cli attr set 4 removeFromSuperview "" --session 47164 --force
```

### console

Evaluate methods on objects in the running app.

```bash
lookin-cli console eval setNeedsLayout --node-id 4 --session 47164
lookin-cli console eval layoutIfNeeded --node-id 4 --session 47164 --json
```

### select

Select a node in the running app for inspection.

```bash
lookin-cli select 4 --session 47164
```

### export

Export hierarchy data to files.

```bash
# Export as JSON / text / HTML
lookin-cli export hierarchy --session 47164 -o hierarchy.json
lookin-cli export hierarchy --session 47164 -o tree.txt --format text
lookin-cli export hierarchy --session 47164 -o tree.html --format html

# Generate summary report
lookin-cli export report --session 47164 -o report.md
```

### diagnose

Run diagnostic checks on the view hierarchy.

```bash
# Individual checks
lookin-cli diagnose overlap --session 47164             # Overlapping interactive views
lookin-cli diagnose hidden-interactive --session 47164  # Hidden but interactive views
lookin-cli diagnose offscreen --session 47164           # Offscreen views

# Run all diagnostics
lookin-cli diagnose all --session 47164 --json
```

Output example:

```
Diagnostic: overlap
Checked: 7 nodes
Summary: Found 1 overlapping view pair(s)

  [WARN] UIButton(oid:4) overlaps with UIView(oid:7) — 85% of smaller view

Diagnostic: hiddenInteractive
Checked: 8 nodes
Summary: Found 1 hidden interactive view(s)

  [WARN] UIButton(oid:8) is interactive but not visible: isHidden=true
```

Exit code is non-zero when issues are found, making it suitable for CI checks.

### scan

Quick connectivity test — scans all Lookin ports and reports discovered apps.

```bash
lookin-cli scan
```

## JSON Output

All commands support `--json` for machine-parseable output. JSON field names are stable across versions.

```bash
lookin-cli apps list --json
```

```json
[
  {
    "appName": "LookinTestApp",
    "bundleIdentifier": "com.lookin.testapp",
    "deviceName": "iPhone 16 Pro (18.0)",
    "deviceType": "simulator",
    "port": 47164,
    "serverVersion": "1.2.8"
  }
]
```

Errors are also returned as JSON when `--json` is specified:

```json
{
  "error": true,
  "code": 10,
  "message": "No inspectable apps found"
}
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 10 | No apps found |
| 11 | App not found |
| 20 | Session not connected |
| 21 | Connection failed |
| 22 | Connection timeout |
| 30 | Node not found |
| 31 | Query syntax error |
| 40 | Screenshot failed |
| 50 | Attribute modification failed |
| 51 | Console eval failed |
| 60 | Export failed |
| 70 | Server version mismatch |
| 71 | App in background |
| 72 | Protocol error |

## Architecture

```
lookin-cli (executable)
    |
    +-- LookinCLI        (12 command families + output formatters)
    |
    +-- LookinCore        (service protocols, DTOs, query engine, diagnostics)
    |     |
    |     +-- Models      (LKNode, LKHierarchySnapshot, LKAppDescriptor, ...)
    |     +-- Services    (Live + Mock implementations)
    |     +-- Query       (LKQueryEngine)
    |     +-- Diagnostics (overlap, hidden-interactive, offscreen)
    |     +-- Protocol    (LKTCPConnection, LKFrameCodec, LKProtocolClient)
    |     +-- Export      (JSON, text, HTML, report)
    |
    +-- LookinSharedBridge (ObjC NSSecureCoding types for Peertalk protocol)
```

### Protocol

Lookin CLI communicates with iOS simulator apps via the Peertalk protocol over TCP:

- **Simulator ports**: 47164-47169 (localhost)
- **Device ports**: 47175-47179 — not yet implemented (requires usbmuxd/Peertalk USB hub)
- **Frame format**: 16-byte header (version + type + tag + payloadSize) + payload
- **Serialization**: NSKeyedArchiver with NSSecureCoding
- **Server version**: Compatible with LookinServer 1.2.8 (protocol version 7)

## Live Mode

All commands connect to real iOS apps by default. Session state persists to `~/.lookin-cli/session.json`.

**Verified operations on real device (iPhone 16 Pro simulator, LookinServer 1.2.8):**

| Operation | Status | Example |
|-----------|--------|---------|
| App discovery | Working | `apps list` |
| Session connect | Working | `session connect com.example.app` |
| Session persistence | Working | `session status` (cross-process) |
| Hierarchy dump | Working | `hierarchy dump --session 47164` (unlimited) |
| Node query | Working | `query "UILabel" --session 47164` |
| Set alpha | Working | `attr set <oid> alpha 0.5 --session 47164` |
| Set hidden | Working | `attr set <oid> hidden true --session 47164` |
| Set text | Working | `attr set <oid> text "Hello" --session 47164` |
| Diagnostics | Working | `diagnose all --session 47164` |

**Known limitation:** After a mutation (`attr set`), subsequent mutations in separate CLI invocations require restarting the inspected app. This is due to LookinServer's internal state management after processing modification responses. Read-only operations (hierarchy, query, diagnose) work unlimited times.

### Supported Attributes (40+)

View properties: `alpha`, `hidden`, `opaque`, `clipsToBounds`, `userInteractionEnabled`, `backgroundColor`, `tintColor`, `contentMode`, `tag`, `frame`, `bounds`, `center`, `transform`

UILabel: `text`, `numberOfLines`, `textAlignment`, `lineBreakMode`, `textColor`

UIButton: `enabled`, `selected`, `highlighted`

UIScrollView: `contentOffset`, `contentSize`, `contentInset`, `scrollEnabled`, `pagingEnabled`, `bounces`, `zoomScale`, `minimumZoomScale`, `maximumZoomScale`, `bouncesZoom`

UIStackView: `spacing`, `axis`, `alignment`, `distribution`

CALayer: `opacity`, `cornerRadius`, `borderWidth`, `borderColor`, `shadowOpacity`, `shadowRadius`, `masksToBounds`

Values are parsed from strings: `"0.5"` (numbers), `"true"/"false"` (bools), `"#FF0000"` or `"255,0,0"` (colors), `"{{0,0},{100,200}}"` (rects).

## iOS App Setup

Add LookinServer to your iOS project:

```ruby
# Podfile
pod 'LookinServer', :configurations => ['Debug']
```

```bash
pod install
```

No code changes needed — LookinServer starts automatically in debug builds.

## Testing

```bash
swift test     # Run all 106 tests
```

Test categories:
- **Model tests**: Codable round-trip, JSON schema stability, visibility logic
- **Query engine tests**: All expression types, logical operators, edge cases
- **Diagnostics tests**: Overlap detection, hidden-interactive, offscreen
- **CLI command tests**: End-to-end service flows with mock data
- **Fixture integration tests**: JSON fixture loading, query, export, diagnostics
- **JSON output tests**: Stable field names across all response types

## License

Same as [Lookin](https://github.com/nicklama/lookin) — MIT License.
