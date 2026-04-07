# Lookin CLI Progress

## Current Milestone

- Phase 4 complete: All commands implemented, tested, and committed.

## Completed Changes

- Created `codex/lookin-cli` branch
- Created Package.swift with LookinCore, LookinCLI, LookinCoreTests, LookinCLITests targets
- Created directory structure: Sources/LookinCore, Sources/LookinCLI, Tests/

### LookinCore (Phase 1)
- Data models: LKAppDescriptor, LKSessionDescriptor, LKNode, LKRect, LKAttributeGroup, LKScreenshotRef, LKHierarchySnapshot, LKNodeTree, LKDiagnosticResult, LKConsoleResult, LKModificationResult
- Error system: LookinCoreError (16 error types with exit codes), LKErrorResponse
- Service protocols: SessionServiceProtocol, HierarchyServiceProtocol, NodeQueryServiceProtocol, ScreenshotServiceProtocol, MutationServiceProtocol, ExportServiceProtocol
- Mock services: MockSessionService, MockHierarchyService, MockNodeQueryService, MockScreenshotService, MockMutationService, MockExportService
- ServiceContainer with dependency injection
- Query engine: LKQueryEngine with class name, wildcard, oid, tag, depth, accessibility, parent, visibility, interactive filters, AND/OR/NOT/parentheses
- Diagnostics: DiagnosticsService with overlap, hidden-interactive, offscreen detection
- Export: HierarchyTextFormatter (text, HTML), ReportGenerator
- Protocol: LKPortConstants

### LookinCLI (Phase 2)
- 12 command families implemented:
  1. `apps list` — discover inspectable apps
  2. `session connect|status|disconnect` — session lifecycle
  3. `hierarchy dump` — full hierarchy dump with --max-depth
  4. `node get` — single node inspection
  5. `query` — expression-based node query with --count
  6. `screenshot screen|node` — screenshot capture
  7. `refresh` — hierarchy refresh
  8. `attr get|set` — attribute inspection and mutation with --force guard
  9. `console eval` — method invocation
  10. `select` — node selection
  11. `export hierarchy|report` — export to JSON/text/HTML/markdown
  12. `diagnose overlap|hidden-interactive|offscreen|all` — diagnostic checks
- All commands support `--json` flag
- stderr for diagnostics, stdout for results
- Non-zero exit codes on failure

### Tests (Phase 3)
- 98 tests total, all passing
- LookinCoreTests: LKNodeTests, LKAppDescriptorTests, LKRectTests, LKHierarchySnapshotTests, LKErrorTests, MockSessionServiceTests, LKQueryEngineTests (20 tests), DiagnosticsServiceTests
- LookinCLITests: CLICommandTests, JSONOutputTests, TextFormatterTests

### Bug Fixes (from Codex Review)
- Fixed query parser splitting on AND/OR inside quoted accessibility labels
- Fixed parentheses inside quoted labels affecting paren depth counter

## Open Risks

- Live protocol integration requires Peertalk/NSKeyedArchiver compatibility (ObjC bridging)
- No live device tests yet — all tests use fixture/mock data
- Attribute key mapping (e.g. `LookinAttr_ViewLayer_Tag_Tag` vs `"tag"`) needs refinement for live connections
- Query parser uses token-level splitting; edge cases with mixed paren+quote tokens need character-level parsing

### Protocol Layer (Phase 5)

- LookinSharedBridge ObjC module: 15 NSSecureCoding-compatible classes
- TCP protocol: LKFrameCodec, LKTCPConnection (NWConnection), LKProtocolClient
- Live services: LiveSessionService, LiveHierarchyService, LKBridgeConverter
- Fixture integration tests: 8 tests with sample_hierarchy.json

## Commands And Tests Run

```bash
swift build                          # Build complete
swift run lookin-cli --help          # All 12 subcommands listed
swift run lookin-cli apps list --json # JSON output verified
swift run lookin-cli apps list       # Human-readable output verified
swift test                           # 106 tests, 0 failures (0.023s)
```

## Latest Checkpoint Commit

- `3473f41` — fix connection double-resume, add device port scanning, preserve node attributes
- `65042ea` — add Peertalk TCP protocol layer, ObjC bridge, and fixture tests
- `503903f` — update progress ledger with final status
- `5aae397` — ignore parentheses inside quoted labels in query parser
- `f1a3204` — fix query parser splitting on AND/OR inside quoted labels
- `866b82f` — scaffold core, CLI, and test targets with 12 command families

## Next Step

- Map real LookinAttr identifier constants for live attribute extraction
- Consider session persistence via file-based cache for cross-invocation state
- Prepare skills-oriented workflow wrappers (Phase 4 of blueprint)
- Add .lookin file import support for offline analysis
