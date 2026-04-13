# ViewglassServer Integration

ViewglassServer now lives in its own repository:

- `https://github.com/WZBbiao/ViewglassServer`

The standalone server keeps the upstream module name `LookinServer` so existing app code can continue to:

```swift
import LookinServer
```

## Why use ViewglassServer

The stock `LookinServer 1.2.8` can still crash the inspected app when Viewglass triggers:

- inbuilt attribute modifications
- semantic control actions
- selector invocation

The patched server adds extra server-side protection in these paths:

- `LKS_InbuiltAttrModificationHandler`
- `LKS_RequestHandler`
- `LKS_AttrGroupsMaker`

The goal is to turn unsafe runtime operations into structured errors instead of app crashes.

## Xcode SPM integration

Recommended for both local development and long-term app integration.

1. Remove the upstream `LookinServer` package reference from the app project.
2. In Xcode, choose `File > Add Packages...`
3. Use either the remote repository URL:

   `https://github.com/WZBbiao/ViewglassServer`

   or click `Add Local...` and select your local clone:

   `/Users/wangzhenbiao/works/ViewglassServer`

4. Add the `LookinServer` product to the app target's Debug configuration.

## Package.swift integration

If the app uses SwiftPM directly and keeps a local checkout:

```swift
.package(path: "../ViewglassServer")
```

Then depend on:

```swift
.product(name: "LookinServer", package: "LookinServer")
```

## CocoaPods migration

If the app currently uses:

```ruby
pod 'LookinServer'
```

remove it and switch to SPM or point CocoaPods at the standalone repository. Do not mix the upstream pod and ViewglassServer in the same target.

Example Podfile entry:

```ruby
pod 'LookinServer', :git => 'https://github.com/WZBbiao/ViewglassServer.git'
```

## Current patch scope

The patched server currently adds:

- selector existence checks before invocation
- safer setter signature validation for inbuilt attribute modification
- `@try/@catch` around selector invocation
- `@try/@catch` around post-modification attribute refresh
- `@try/@catch` around getter invocation during attribute group generation

## Validation

The standalone package was built successfully with:

```bash
xcodebuild -scheme LookinServer -destination 'generic/platform=iOS Simulator' build
```

This validates the patched server source compiles for iOS Simulator. Mainline development now happens in the standalone ViewglassServer repository; the Viewglass CLI repository no longer needs to vendor a copy.
