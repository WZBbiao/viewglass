import Foundation
import LookinCore

public enum OutputMode {
    case json
    case human
}

public enum OutputFormatter {
    public static func printApps(_ apps: [LKAppDescriptor], mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(apps)
        case .human:
            if apps.isEmpty {
                printStderr("No inspectable apps found.")
                return
            }
            for app in apps {
                let deviceIcon = app.deviceType == .simulator ? "SIM" : "DEV"
                print("[\(deviceIcon)] \(app.appName) — \(app.bundleIdentifier) (port:\(app.port))")
            }
        }
    }

    public static func printDiscoveryProbes(_ probes: [LKDiscoveryProbe], mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(probes)
        case .human:
            if probes.isEmpty {
                printStderr("No ports or devices were probed.")
                return
            }
            for probe in probes {
                let endpoint = "\(probe.host):\(probe.port)"
                let deviceLabel = probe.deviceType == .simulator ? "SIM" : "DEV"
                let remoteLabel = probe.remotePort.map { " remote:\($0)" } ?? ""
                switch probe.status {
                case .discovered:
                    if let app = probe.app {
                        print("[\(deviceLabel)] \(endpoint)\(remoteLabel) -> \(app.appName) (\(app.bundleIdentifier))")
                    } else {
                        print("[\(deviceLabel)] \(endpoint)\(remoteLabel) -> discovered")
                    }
                default:
                    print("[\(deviceLabel)] \(endpoint)\(remoteLabel) -> \(probe.status.rawValue): \(probe.detail ?? "unknown")")
                }
            }
        }
    }

    public static func printSession(_ session: LKSessionDescriptor, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(session)
        case .human:
            let statusLabel: String
            switch session.status {
            case .connected:
                statusLabel = "Connected to"
            case .disconnected:
                statusLabel = "Cached session for"
            case .backgrounded:
                statusLabel = "Backgrounded session for"
            }
            print("\(statusLabel) \(session.app.appName)")
            print("  Session: \(session.sessionId)")
            print("  Bundle:  \(session.app.bundleIdentifier)")
            print("  Port:    \(session.app.port)")
            print("  Status:  \(session.status.rawValue)")
        }
    }

    public static func printHierarchy(_ snapshot: LKHierarchySnapshot, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(snapshot)
        case .human:
            print(HierarchyTextFormatter.format(snapshot: snapshot))
        }
    }

    public static func printNode(_ node: LKNode, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(node)
        case .human:
            print("\(node.className) (oid:\(node.oid))")
            print("  Address:    \(node.address)")
            print("  Frame:      (\(Int(node.frame.x)), \(Int(node.frame.y)), \(Int(node.frame.width)), \(Int(node.frame.height)))")
            print("  Bounds:     (\(Int(node.bounds.x)), \(Int(node.bounds.y)), \(Int(node.bounds.width)), \(Int(node.bounds.height)))")
            print("  Hidden:     \(node.isHidden)")
            print("  Alpha:      \(node.alpha)")
            print("  Interactive:\(node.isUserInteractionEnabled)")
            if let bg = node.backgroundColor { print("  Background: \(bg)") }
            if let label = node.accessibilityLabel { print("  A11y Label: \(label)") }
            if let id = node.accessibilityIdentifier { print("  A11y ID:    \(id)") }
            print("  Children:   \(node.childrenOids.count)")
        }
    }

    public static func printNodes(_ nodes: [LKNode], mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(nodes)
        case .human:
            print("Found \(nodes.count) node(s):")
            for node in nodes {
                let frame = node.frame
                let visibility = node.isVisible ? "" : " [hidden]"
                print("  \(node.className) (oid:\(node.oid)) (\(Int(frame.x)),\(Int(frame.y)),\(Int(frame.width)),\(Int(frame.height)))\(visibility)")
            }
        }
    }

    public static func printDiagnostic(_ result: LKDiagnosticResult, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(result)
        case .human:
            print("Diagnostic: \(result.diagnosticType.rawValue)")
            print("Checked: \(result.checkedNodeCount) nodes")
            print("Summary: \(result.summary)")
            if !result.issues.isEmpty {
                print("")
                for issue in result.issues {
                    let icon: String
                    switch issue.severity {
                    case .error: icon = "ERROR"
                    case .warning: icon = "WARN"
                    case .info: icon = "INFO"
                    }
                    print("  [\(icon)] \(issue.message)")
                }
            }
        }
    }

    public static func printModification(_ result: LKModificationResult, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(result)
        case .human:
            if result.success {
                print("Modified \(result.attributeKey) on oid:\(result.nodeOid)")
                print("  Before: \(result.previousValue)")
                print("  After:  \(result.newValue)")
            } else {
                printStderr("Modification failed: \(result.error ?? "unknown")")
            }
        }
    }

    public static func printConsoleResult(_ result: LKConsoleResult, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(result)
        case .human:
            print("\(result.targetClass)(oid:\(result.targetOid)) > \(result.expression)")
            if let value = result.returnValue {
                print("  => \(value)")
            }
        }
    }

    public static func printScreenshot(_ ref: LKScreenshotRef, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(ref)
        case .human:
            print("Screenshot saved: \(ref.filePath ?? "N/A")")
            print("  Type:   \(ref.screenshotType.rawValue)")
            print("  Size:   \(ref.width)x\(ref.height)")
            print("  Format: \(ref.format.rawValue)")
        }
    }

    public static func printAction(_ result: LKActionResult, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(result)
        case .human:
            print("Performed \(result.mode.rawValue) \(result.action) on \(result.targetClass)(oid:\(result.nodeOid))")
            if let detail = result.detail, !detail.isEmpty {
                print("  \(detail)")
            }
        }
    }

    public static func printGestureInspection(_ result: LKGestureInspectionResult, mode: OutputMode) {
        switch mode {
        case .json:
            JSONOutput.print(result)
        case .human:
            print("Gestures on \(result.targetClass)(oid:\(result.nodeOid))")
            if result.gestures.isEmpty {
                print("  None")
                return
            }
            for (index, gesture) in result.gestures.enumerated() {
                let state = gesture.state ?? "unknown"
                let id = gesture.recognizerId.map(String.init) ?? "-"
                let viewClass = gesture.viewClass ?? result.targetClass
                print("  [\(index)] \(gesture.recognizerClass) id:\(id) state:\(state) view:\(viewClass)")
                if gesture.actions.isEmpty {
                    print("      actions: none")
                } else {
                    for action in gesture.actions {
                        let target = action.targetClass ?? "unknown"
                        print("      \(action.selector) -> \(target)")
                    }
                }
            }
        }
    }
}

func printStderr(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}
