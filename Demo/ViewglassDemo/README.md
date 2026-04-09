# ViewglassDemo

`ViewglassDemo` is the self-owned iOS demo app used for real Viewglass E2E testing.

It is intentionally designed around a small set of broad, reusable interaction surfaces instead of
mock data or one-off screens:

- navigation and controller transitions
- alerts, action sheets, page sheets, and full-screen modals
- forms with common UIKit input controls
- long scrolling content
- tap and long-press gesture targets

## Dependency

The demo app depends on [`ViewglassServer`](https://github.com/WZBbiao/ViewglassServer) through Swift Package Manager.

## Generate The Xcode Project

```bash
cd Demo/ViewglassDemo
xcodegen generate
```

## Build

```bash
xcodebuild -project ViewglassDemo.xcodeproj -scheme ViewglassDemo -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## Why This Demo Exists

This demo replaces external sample apps for Viewglass development. New primitives and E2E flows
should be validated against this app first so the project owns its own runtime fixtures.
