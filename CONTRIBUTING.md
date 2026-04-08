# Contributing

## Scope

This repository is evolving from a Lookin-derived desktop tool into a CLI-first runtime inspection platform for iOS and AI workflows.

Contributions are welcome in these areas:

- CLI behavior and docs
- runtime protocol compatibility
- diagnostics and query language
- packaging and releases
- tests

## Ground Rules

- keep behavior changes documented
- prefer small, reviewable pull requests
- add tests for any bug fix or new command behavior
- do not silently change compatibility claims with LookinServer
- avoid breaking machine-readable JSON output without documenting it

## Development

- Swift package code lives in `Sources/`
- legacy macOS app code lives in `LookinClient/`
- tests live in `Tests/`
- product and repo strategy docs live in `Docs/`

## Pull Requests

Please include:

- what changed
- why it changed
- how it was tested
- any compatibility or migration impact

If you change CLI output, include examples.
