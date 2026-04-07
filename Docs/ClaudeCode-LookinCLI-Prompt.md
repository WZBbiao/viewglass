# Claude Code Prompt For Long-Running Lookin CLI Buildout

You are working inside the Lookin repository. Your goal is to turn this macOS GUI inspector into a full CLI-first programmable tool, then prepare it for AI skills. Treat this as a long-running engineering project, not a one-shot patch.

## Mission

Implement Lookin CLI end to end with complete command coverage, rigorous tests, and clean architecture:

- first extract a reusable `LookinCore`
- then implement `LookinCLI`
- then add skills-oriented workflow wrappers
- preserve the existing GUI app while extracting
- ship the binary and command namespace as `lookin-cli`
- cover the full meaningful Lookin capability set, not only a thin MVP

## Primary Product Requirements

Build a CLI that exposes Lookin capabilities in a machine-friendly way.

Required command families:

- `apps`
- `session`
- `hierarchy`
- `node`
- `query`
- `screenshot`
- `refresh`
- `attr`
- `console`
- `select`
- `export`
- `diagnose`

Every command must support deterministic machine usage. Prefer `--json` outputs with stable field names.

The CLI binary name must be `lookin-cli`.

## Non-Negotiable Engineering Rules

1. Do not do a shallow or fake prototype. Build production-quality scaffolding.
2. Do not leave commands partially implemented without tests.
3. Do not redesign blindly. Extract from existing code with minimal regressions.
4. Keep `LookinClient` operational while moving shared logic into `LookinCore`.
5. Do not couple CLI output models to AppKit types.
6. Every completed command needs full tests:
   - argument parsing tests
   - success-path tests
   - failure-path tests
   - JSON output shape tests
   - fixture-backed integration tests when possible
7. Keep a running progress ledger in `Docs/lookin-cli-progress.md`.
8. After each meaningful milestone, run the relevant tests and record exact commands and outcomes in the ledger.
9. When blocked, reduce scope only temporarily and leave explicit TODOs in the ledger, not hidden in your reasoning.
10. Maintain strict git hygiene on a dedicated branch prefixed with `codex/`.
11. Create checkpoint commits regularly during the run. Do not wait until the very end.
12. Before every checkpoint commit, run the most relevant tests and record them in the ledger.
13. Every checkpoint commit message must start with `lookin-cli:`.
14. If the repo is not already on a `codex/` branch, create one before substantial work begins.

## Working Style

Work in small verified increments:

1. inspect current code
2. extract a core seam
3. implement one command family
4. write **tests**
5. run tests
6. update progress ledger
7. create a checkpoint commit when the increment is coherent
8. continue

Do not stop after planning. Keep implementing until the repository reaches a materially better, tested state.

## Architecture Direction

Target structure:

- `LookinClient`
- `LookinCore`
- `LookinCLI`
- `LookinCoreTests`
- `LookinCLITests`

Expected service seams:

- session discovery and connection
- hierarchy fetch and refresh
- node lookup and querying
- screenshot retrieval
- mutation requests
- export/report generation

## CLI Design Direction

Prefer a structure like:

- `lookin-cli apps list`
- `lookin-cli session connect`
- `lookin-cli hierarchy dump`
- `lookin-cli node get`
- `lookin-cli query`
- `lookin-cli screenshot screen`
- `lookin-cli screenshot node`
- `lookin-cli refresh`
- `lookin-cli attr set`
- `lookin-cli console eval`
- `lookin-cli select`
- `lookin-cli export hierarchy`
- `lookin-cli diagnose overlap`

Use explicit exit codes. Use stderr for diagnostics. Keep stdout parseable.

Do not stop at read-only support. The final CLI must expose the full meaningful Lookin feature set.

## Testing Bar

A command is not done until:

- tests exist
- tests pass locally
- command behavior is documented or self-evident from help output

Where live device testing is impossible, create fixtures and adapters so the behavior is still testable.

## Progress Ledger Format

Maintain `Docs/lookin-cli-progress.md` with sections:

- current milestone
- completed changes
- open risks
- commands/tests run
- latest checkpoint commit
- next step

Append rather than rewrite history unless cleanup is needed.

## End-State

The final outcome should leave this repository with:

- a working CLI surface
- a reusable core layer
- comprehensive tests
- a disciplined sequence of checkpoint commits
- an obvious next step for skills and later MCP support

Start by reading `Docs/LookinCLI-Implementation-Blueprint.md`, inspecting the current connection/hierarchy/export code, and implementing the smallest verified extraction that moves the repo toward `LookinCore`.
