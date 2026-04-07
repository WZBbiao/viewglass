# Lookin CLI Implementation Blueprint

## Goal

Turn Lookin into a programmable runtime inspector with:

- `LookinCore`: reusable service layer with no AppKit UI dependency
- `lookin-cli`: CLI for humans, scripts, and AI skills
- future-ready protocol surface that can later back MCP without redesign
- complete Lookin feature coverage, not a minimal subset

## Git Control Requirements

- all work must happen on a dedicated branch prefixed with `codex/`
- use small checkpoint commits throughout the run, not one final dump
- every commit must correspond to a tested milestone or a clearly labeled scaffolding checkpoint
- commit messages must be specific and machine-scannable
- record the latest checkpoint commit in `Docs/lookin-cli-progress.md`
- do not rewrite history during the long-running implementation unless explicitly instructed

## Delivery Order

### Phase 0: Establish engineering rails

- Create new targets/modules:
  - `LookinCore`
  - `LookinCLI`
- Keep `LookinClient` working during extraction
- Add test bundles:
  - `LookinCoreTests`
  - `LookinCLITests`
- Add fixture support for hierarchy snapshots and expected JSON output
- Add a machine-readable progress ledger at `Docs/lookin-cli-progress.md`
- Create or switch to a working branch such as `codex/lookin-cli`

### Phase 1: Extract read-only core

Move or wrap non-UI logic behind services:

- session discovery
- app connection
- hierarchy fetch
- hierarchy file load/export
- node lookup
- screenshot retrieval

Suggested service boundaries:

- `LKCoreSessionService`
- `LKCoreHierarchyService`
- `LKCoreNodeQueryService`
- `LKCoreSnapshotService`
- `LKCoreExportService`

Suggested DTOs:

- `LKCLIAppDescriptor`
- `LKCLISessionDescriptor`
- `LKCLINode`
- `LKCLIRect`
- `LKCLIScreenshotRef`
- `LKCLIHierarchySnapshot`

Rules:

- DTOs must be stable and GUI-agnostic
- no AppKit views in public core APIs
- every service returns structured errors

### Phase 2: First CLI surface

Implement these commands first:

- `lookin-cli apps list --json`
- `lookin-cli session connect <app-id> --json`
- `lookin-cli hierarchy dump --session <id> --json`
- `lookin-cli node get <node-id> --session <id> --json`
- `lookin-cli query <expr> --session <id> --json`
- `lookin-cli screenshot screen --session <id> --output <path>`
- `lookin-cli refresh --session <id> --json`

Rules:

- JSON output must be stable
- non-zero exit codes on failure
- stderr for diagnostics, stdout for result payloads
- every command supports `--json`

### Phase 3: Mutation surface

Add controlled write commands:

- `lookin-cli attr set <node-id> <key> <value> --session <id> --json`
- `lookin-cli console eval <expr> --session <id> --json`
- `lookin-cli select <node-id> --session <id> --json`

Guardrails:

- separate safe mutations from dangerous mutations
- dangerous mutations require explicit flag
- emit before/after summaries for writes

### Phase 4: Skills-oriented workflows

Build composable higher-level commands or scripts:

- `lookin-cli diagnose overlap`
- `lookin-cli diagnose hidden-interactive`
- `lookin-cli summarize screen`
- `lookin-cli export report`

These are not replacements for low-level commands. They are task wrappers.

## Full Feature Coverage Target

The end state must expose all major Lookin capabilities through `lookin-cli`, including:

- app discovery and connection
- hierarchy fetch and refresh
- preview and screenshot-related data access where programmatically meaningful
- node selection and inspection
- property and attribute mutation
- screenshot and image export
- console evaluation
- hierarchy file read/export
- measurement-related data access where available without GUI dependence
- notifications or messages that matter to automation
- diagnostic helpers layered on top of the raw commands

## Testing Standard

Every command must have all of the following before being considered done:

1. unit tests for parser/formatter/service behavior
2. golden tests for JSON output shape
3. fixture-backed integration tests when live device access is not required
4. live integration test path for commands that require a running app
5. negative-path test for invalid args or unavailable session

Required test categories:

- parse and validate args
- session lifecycle
- JSON schema stability
- empty/no-app states
- error propagation
- large hierarchy handling
- file output behavior

## CLI Design Constraints

- default human-readable output may exist, but `--json` is mandatory
- never require GUI interaction for CLI success paths
- avoid hidden global state when explicit `--session` can be used
- if persistent state is needed, keep it under a clear cache dir
- command names must map cleanly to future MCP tools
- binary and command namespace must be `lookin-cli`

## Commit Cadence

Create checkpoint commits at least:

- after repository and target scaffolding
- after each command family becomes functional and tested
- after major refactors that move code into `LookinCore`
- after any stabilization pass that fixes multiple failing tests

Recommended commit message style:

- `lookin-cli: scaffold core and cli targets`
- `lookin-cli: add apps and session commands with tests`
- `lookin-cli: expose hierarchy dump and node query`

## Mapping From Current Code

Likely extraction starting points:

- `LookinClient/Connection/LKConnectionManager.*`
- `LookinClient/Connection/LKAppsManager.*`
- `LookinClient/Connection/LKInspectableApp.*`
- `LookinClient/Static/LKStaticAsyncUpdateManager.*`
- `LookinClient/Static/LKStaticHierarchyDataSource.*`
- `LookinClient/Export/*`
- `LookinClient/Read/*`

Likely UI-only boundaries to keep out of core:

- AppKit window controllers
- toolbar and menu behavior
- view layout classes
- popovers and tutorial UI

## Definition Of Done

The effort is complete only when:

- `lookin-cli` builds locally from the workspace
- read-only commands work without GUI usage
- write commands are protected and tested
- each command has documented examples
- a skill layer can call CLI without extra prompt glue
- the design leaves a direct path to a future `lookin mcp`
- work is represented by a clean sequence of checkpoint commits
