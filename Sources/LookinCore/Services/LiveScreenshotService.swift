import AppKit
import Darwin
import Foundation
import LookinSharedBridge

public final class LiveScreenshotService: ScreenshotServiceProtocol, @unchecked Sendable {
    private let sessionService: LiveSessionService
    private let hierarchyService: LiveHierarchyService

    public init(sessionService: LiveSessionService, hierarchyService: LiveHierarchyService) {
        self.sessionService = sessionService
        self.hierarchyService = hierarchyService
    }

    public func captureScreen(sessionId: String, outputPath: String, preferredDeviceIdentifier: String? = nil) async throws -> LKScreenshotRef {
        var hostFailures: [String] = []
        if let app = try? await resolveAppDescriptor(sessionId: sessionId) {
            do {
                let hostRef = try await captureHostScreen(
                    app: app,
                    outputPath: outputPath,
                    preferredDeviceIdentifier: preferredDeviceIdentifier
                )
                if let reason = hostRef.agentUnusableScreenReason {
                    hostFailures.append("\(hostRef.captureProvider?.rawValue ?? "host"): \(reason)")
                } else {
                    return hostRef
                }
            } catch {
                hostFailures.append(error.localizedDescription)
            }
        }

        let fallbackReason = hostFailures.isEmpty ? nil : hostFailures.joined(separator: "; ")
        let serverRef = try await captureServerScreen(
            sessionId: sessionId,
            outputPath: outputPath,
            fallbackReason: fallbackReason
        )
        if let reason = serverRef.agentUnusableScreenReason {
            let details = ([fallbackReason, "server: \(reason)"].compactMap { $0 }).joined(separator: "; ")
            throw LookinCoreError.screenshotFailed(reason: "All full-screen screenshot providers produced unusable output. \(details)")
        }
        return serverRef
    }

    private func captureServerScreen(sessionId: String, outputPath: String, fallbackReason: String?) async throws -> LKScreenshotRef {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let client = try await sessionService.getClient(for: sessionId)
                let data = try await client.fetchHighResolutionScreenScreenshot()
                return try writeScreenshot(
                    data: data,
                    fallbackNodeOid: 0,
                    screenshotType: .screen,
                    outputPath: outputPath,
                    captureProvider: .server,
                    fallbackReason: fallbackReason
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.screenshotFailed(reason: "Unknown screen capture failure")
    }

    public func captureNode(oid: UInt, sessionId: String, outputPath: String, preferredDeviceIdentifier: String? = nil) async throws -> LKScreenshotRef {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                let snapshot = try await hierarchyService.fetchHierarchy(sessionId: sessionId)
                guard let node = snapshot.findNode(oid: oid) else {
                    throw LookinCoreError.nodeNotFound(oid: oid)
                }

                guard let layerOid = node.layerOid ?? node.viewOid else {
                    throw LookinCoreError.screenshotFailed(reason: "Node \(oid) does not expose a capturable layer")
                }

                let client = try await sessionService.getClient(for: sessionId)
                let data = try await client.fetchHighResolutionNodeScreenshot(oid: layerOid)
                return try writeScreenshot(
                    data: data,
                    fallbackNodeOid: oid,
                    screenshotType: node.layerOid != nil ? .group : .solo,
                    outputPath: outputPath,
                    captureProvider: .server,
                    fallbackReason: nil
                )
            } catch {
                lastError = error
                guard attempt == 0, shouldRetry(after: error) else {
                    throw error
                }
                sessionService.disconnectAll()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }

        throw lastError ?? LookinCoreError.screenshotFailed(reason: "Unknown node capture failure")
    }

    private func resolveAppDescriptor(sessionId: String) async throws -> LKAppDescriptor {
        _ = try await sessionService.getClient(for: sessionId)
        if let session = await sessionService.currentSession(),
           session.sessionId == sessionId || session.app.identifier == sessionId || "\(session.app.port)" == sessionId {
            return session.app
        }
        throw LookinCoreError.sessionNotConnected
    }

    private func captureHostScreen(
        app: LKAppDescriptor,
        outputPath: String,
        preferredDeviceIdentifier: String?
    ) async throws -> LKScreenshotRef {
        switch app.deviceType {
        case .simulator:
            let udid = try resolveSimulatorUDID(
                preferredDeviceIdentifier: preferredDeviceIdentifier,
                deviceName: app.deviceName
            )
            let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? FileManager.default.removeItem(at: outputURL)
            let result = try runProcess(
                executable: "/usr/bin/xcrun",
                arguments: ["simctl", "io", udid, "screenshot", "--type=png", "--mask=ignored", outputURL.path],
                timeout: 15
            )
            return try screenshotRefFromFile(
                outputURL,
                fallbackNodeOid: 0,
                screenshotType: .screen,
                captureProvider: .simctl,
                fallbackReason: nil,
                providerOutput: result.diagnosticOutput
            )

        case .device:
            let udid = preferredDeviceIdentifier ?? app.deviceIdentifier
            guard let udid, !udid.isEmpty else {
                throw LookinCoreError.screenshotFailed(reason: "Device UDID is unavailable for host screenshot capture")
            }
            return try captureDeviceHostScreen(udid: udid, outputPath: outputPath)
        }
    }

    private func captureDeviceHostScreen(udid: String, outputPath: String) throws -> LKScreenshotRef {
        var failures: [String] = []
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? FileManager.default.removeItem(at: outputURL)

        do {
            let result = try runProcess(
                executable: "/usr/bin/env",
                arguments: ["pymobiledevice3", "developer", "screenshot", "--udid", udid, outputURL.path],
                timeout: 20
            )
            return try screenshotRefFromFile(
                outputURL,
                fallbackNodeOid: 0,
                screenshotType: .screen,
                captureProvider: .pymobiledevice3,
                fallbackReason: nil,
                providerOutput: result.diagnosticOutput
            )
        } catch {
            failures.append("pymobiledevice3: \(error.localizedDescription)")
        }

        let tiffURL = outputURL
            .deletingLastPathComponent()
            .appendingPathComponent(".\(outputURL.lastPathComponent).idevicescreenshot.tiff")
        try? FileManager.default.removeItem(at: tiffURL)
        do {
            let result = try runProcess(
                executable: "/usr/bin/env",
                arguments: ["idevicescreenshot", "-u", udid, tiffURL.path],
                timeout: 20
            )
            let tiffData = try Data(contentsOf: tiffURL)
            let pngData = try encodePNG(from: tiffData)
            try pngData.write(to: outputURL, options: .atomic)
            try? FileManager.default.removeItem(at: tiffURL)
            return try screenshotRefFromFile(
                outputURL,
                fallbackNodeOid: 0,
                screenshotType: .screen,
                captureProvider: .idevicescreenshot,
                fallbackReason: nil,
                providerOutput: result.diagnosticOutput
            )
        } catch {
            failures.append("idevicescreenshot: \(error.localizedDescription)")
            try? FileManager.default.removeItem(at: tiffURL)
        }

        throw LookinCoreError.screenshotFailed(reason: failures.joined(separator: "; "))
    }

    private func writeScreenshot(
        data: Data,
        fallbackNodeOid: UInt,
        screenshotType: LKScreenshotRef.ScreenshotType,
        outputPath: String,
        captureProvider: LKScreenshotRef.CaptureProvider,
        fallbackReason: String?
    ) throws -> LKScreenshotRef {
        let outputURL = URL(fileURLWithPath: outputPath).standardizedFileURL
        try FileManager.default.createDirectory(
            at: outputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: outputURL, options: .atomic)
        return try makeScreenshotRef(
            data: data,
            fallbackNodeOid: fallbackNodeOid,
            screenshotType: screenshotType,
            outputURL: outputURL,
            captureProvider: captureProvider,
            fallbackReason: fallbackReason
        )
    }

    private func screenshotRefFromFile(
        _ outputURL: URL,
        fallbackNodeOid: UInt,
        screenshotType: LKScreenshotRef.ScreenshotType,
        captureProvider: LKScreenshotRef.CaptureProvider,
        fallbackReason: String?,
        providerOutput: String? = nil
    ) throws -> LKScreenshotRef {
        guard
            let attributes = try? FileManager.default.attributesOfItem(atPath: outputURL.path),
            let fileSize = attributes[.size] as? NSNumber,
            fileSize.intValue > 0
        else {
            let outputDetail = providerOutput?.isEmpty == false ? " Output: \(providerOutput!)" : ""
            throw LookinCoreError.screenshotFailed(reason: "Host provider \(captureProvider.rawValue) did not produce a screenshot file at \(outputURL.path).\(outputDetail)")
        }
        let data = try Data(contentsOf: outputURL)
        return try makeScreenshotRef(
            data: data,
            fallbackNodeOid: fallbackNodeOid,
            screenshotType: screenshotType,
            outputURL: outputURL,
            captureProvider: captureProvider,
            fallbackReason: fallbackReason
        )
    }

    private func makeScreenshotRef(
        data: Data,
        fallbackNodeOid: UInt,
        screenshotType: LKScreenshotRef.ScreenshotType,
        outputURL: URL,
        captureProvider: LKScreenshotRef.CaptureProvider,
        fallbackReason: String?
    ) throws -> LKScreenshotRef {
        let format = detectFormat(data)
        let size = try imageSize(for: data)
        let quality = inspectImageQuality(data: data, width: size.width, height: size.height, screenshotType: screenshotType)

        return LKScreenshotRef(
            nodeOid: fallbackNodeOid,
            screenshotType: screenshotType,
            format: format,
            width: size.width,
            height: size.height,
            dataSize: data.count,
            filePath: outputURL.path,
            captureProvider: captureProvider,
            fallbackReason: fallbackReason,
            qualityWarnings: quality.warnings,
            blackPixelRatio: quality.blackPixelRatio,
            nonBlackPixelRatio: quality.nonBlackPixelRatio
        )
    }

    private func imageSize(for data: Data) throws -> (width: Int, height: Int) {
        guard let image = NSImage(data: data) else {
            throw LookinCoreError.screenshotFailed(reason: "Captured image data is unreadable")
        }
        let rect = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size), context: nil, hints: nil)?.pixelsWide
        let rep = image.bestRepresentation(for: NSRect(origin: .zero, size: image.size), context: nil, hints: nil)
        return (
            width: rect ?? Int(image.size.width),
            height: rep?.pixelsHigh ?? Int(image.size.height)
        )
    }

    private func detectFormat(_ data: Data) -> LKScreenshotRef.ImageFormat {
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return .png
        }
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return .jpeg
        }
        if data.starts(with: [0x49, 0x49, 0x2A, 0x00]) || data.starts(with: [0x4D, 0x4D, 0x00, 0x2A]) {
            return .tiff
        }
        return .png
    }

    private struct ProcessResult {
        let stdout: String
        let stderr: String
        let exitCode: Int32

        var diagnosticOutput: String {
            [stderr, stdout].filter { !$0.isEmpty }.joined(separator: " ")
        }
    }

    private struct ProcessFailure: LocalizedError {
        let executable: String
        let arguments: [String]
        let exitCode: Int32?
        let stdout: String
        let stderr: String

        var errorDescription: String? {
            let command = ([executable] + arguments).joined(separator: " ")
            let status = exitCode.map { "exit \($0)" } ?? "timed out"
            let detail = [stderr, stdout].filter { !$0.isEmpty }.joined(separator: " ")
            return detail.isEmpty ? "\(command) failed with \(status)" : "\(command) failed with \(status): \(detail)"
        }
    }

    private struct QualityInspection {
        let warnings: [String]
        let blackPixelRatio: Double?
        let nonBlackPixelRatio: Double?
    }

    private func runProcess(executable: String, arguments: [String], timeout: TimeInterval) throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            semaphore.signal()
        }

        try process.run()
        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            if semaphore.wait(timeout: .now() + 2) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = semaphore.wait(timeout: .now() + 1)
            }
            throw ProcessFailure(
                executable: executable,
                arguments: arguments,
                exitCode: nil,
                stdout: String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "",
                stderr: String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            )
        }

        let stdout = String(data: stdoutPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: stderrPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        guard process.terminationStatus == 0 else {
            throw ProcessFailure(
                executable: executable,
                arguments: arguments,
                exitCode: process.terminationStatus,
                stdout: stdout,
                stderr: stderr
            )
        }
        return ProcessResult(stdout: stdout, stderr: stderr, exitCode: process.terminationStatus)
    }

    private func resolveSimulatorUDID(preferredDeviceIdentifier: String?, deviceName: String?) throws -> String {
        if let preferredDeviceIdentifier, !preferredDeviceIdentifier.isEmpty {
            return preferredDeviceIdentifier
        }

        let result = try runProcess(
            executable: "/usr/bin/xcrun",
            arguments: ["simctl", "list", "devices", "--json"],
            timeout: 10
        )
        guard
            let jsonData = result.stdout.data(using: .utf8),
            let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
            let devicesByRuntime = root["devices"] as? [String: [[String: Any]]]
        else {
            throw LookinCoreError.screenshotFailed(reason: "Failed to parse simctl device list")
        }

        let booted = devicesByRuntime.values.flatMap { $0 }.filter { device in
            (device["state"] as? String) == "Booted"
        }
        if let deviceName, !deviceName.isEmpty,
           let match = booted.first(where: { ($0["name"] as? String) == deviceName }),
           let udid = match["udid"] as? String {
            return udid
        }
        if booted.count == 1, let udid = booted[0]["udid"] as? String {
            return udid
        }

        let names = booted.compactMap { device -> String? in
            guard let name = device["name"] as? String, let udid = device["udid"] as? String else {
                return nil
            }
            return "\(name)(\(udid))"
        }.joined(separator: ", ")
        throw LookinCoreError.screenshotFailed(reason: "Unable to choose a unique booted simulator for host screenshot capture. Booted: \(names)")
    }

    private func encodePNG(from data: Data) throws -> Data {
        guard let image = NSImage(data: data) else {
            throw LookinCoreError.screenshotFailed(reason: "Failed to decode host screenshot")
        }
        guard
            let tiff = image.tiffRepresentation,
            let rep = NSBitmapImageRep(data: tiff),
            let png = rep.representation(using: .png, properties: [:])
        else {
            throw LookinCoreError.screenshotFailed(reason: "Failed to encode host screenshot as PNG")
        }
        return png
    }

    private func inspectImageQuality(
        data: Data,
        width: Int,
        height: Int,
        screenshotType: LKScreenshotRef.ScreenshotType
    ) -> QualityInspection {
        var warnings: [String] = []
        if screenshotType == .screen && (width < 300 || height < 300) {
            warnings.append("suspiciousSmallDimensions")
        }
        if screenshotType == .screen && width * height > 1_000_000 && data.count < 80_000 {
            warnings.append("suspiciousSmallEncodedImage")
        }

        guard let rep = bitmapRep(from: data) else {
            return QualityInspection(warnings: warnings + ["unreadableImageForQualityInspection"], blackPixelRatio: nil, nonBlackPixelRatio: nil)
        }

        let sampleWidth = max(rep.pixelsWide, 1)
        let sampleHeight = max(rep.pixelsHigh, 1)
        let stepX = max(1, sampleWidth / 80)
        let stepY = max(1, sampleHeight / 80)
        var sampled = 0
        var black = 0
        var nonBlack = 0

        for y in stride(from: 0, to: sampleHeight, by: stepY) {
            for x in stride(from: 0, to: sampleWidth, by: stepX) {
                guard let color = rep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else {
                    continue
                }
                sampled += 1
                let red = color.redComponent
                let green = color.greenComponent
                let blue = color.blueComponent
                let alpha = color.alphaComponent
                let maxChannel = max(red, green, blue)
                let sum = red + green + blue
                if alpha < 0.05 || (maxChannel < 0.08 && sum < 0.18) {
                    black += 1
                }
                if alpha > 0.05 && maxChannel > 0.14 && sum > 0.31 {
                    nonBlack += 1
                }
            }
        }

        guard sampled > 0 else {
            return QualityInspection(warnings: warnings + ["emptyQualitySample"], blackPixelRatio: nil, nonBlackPixelRatio: nil)
        }

        let blackRatio = Double(black) / Double(sampled)
        let nonBlackRatio = Double(nonBlack) / Double(sampled)
        if screenshotType == .screen && blackRatio > 0.90 {
            warnings.append("mostlyBlack")
        }
        if screenshotType == .screen && nonBlackRatio < 0.03 {
            warnings.append("lowVisibleContentRatio")
        }

        return QualityInspection(
            warnings: warnings,
            blackPixelRatio: (blackRatio * 10_000).rounded() / 10_000,
            nonBlackPixelRatio: (nonBlackRatio * 10_000).rounded() / 10_000
        )
    }

    private func bitmapRep(from data: Data) -> NSBitmapImageRep? {
        if let rep = NSBitmapImageRep(data: data) {
            return rep
        }
        guard let image = NSImage(data: data), let tiff = image.tiffRepresentation else {
            return nil
        }
        return NSBitmapImageRep(data: tiff)
    }

    private func shouldRetry(after error: Error) -> Bool {
        switch error {
        case let LookinCoreError.protocolError(reason):
            return reason.localizedCaseInsensitiveContains("connection closed")
                || reason.localizedCaseInsensitiveContains("connect failed")
        case let LookinCoreError.appNotFound(identifier):
            return !identifier.isEmpty
        default:
            return false
        }
    }

}
