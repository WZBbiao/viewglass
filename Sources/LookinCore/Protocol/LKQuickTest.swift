import Foundation
import LookinSharedBridge

/// Quick test utility to verify live connection to a running iOS app.
public enum LKQuickTest {

    /// Scans all simulator ports and reports what's found.
    public static func scanAndReport() async {
        print("=== Lookin CLI Live Connection Test ===")
        print("")

        // Scan simulator ports
        print("Scanning simulator ports (47164-47169)...")
        for port in LKPortConstants.simulatorPorts {
            await testPort(port: port)
        }

        // Scan device ports
        print("")
        print("Scanning device ports (47175-47179)...")
        for port in LKPortConstants.devicePorts {
            await testPort(port: port)
        }

        print("")
        print("=== Scan complete ===")
    }

    private static func testPort(port: Int) async {
        let client = LKProtocolClient()
        do {
            try await client.connect(host: "127.0.0.1", port: port)

            // Step 1: App info
            let appInfo = try await client.fetchAppInfo(needImages: false)
            print("  Port \(port): \(appInfo.appName ?? "Unknown") (\(appInfo.appBundleIdentifier ?? "?"))")
            print("    Server: \(appInfo.serverReadableVersion ?? "?")")
            print("    Device: \(appInfo.deviceDescription ?? "?")")
            print("    Screen: \(appInfo.screenWidth)x\(appInfo.screenHeight) @\(appInfo.screenScale)x")

            // Step 2: Hierarchy
            print("    Fetching hierarchy...")
            do {
                let hierarchy = try await client.fetchHierarchy()
                let itemCount = countItems(hierarchy.displayItems)
                print("    OK: \(itemCount) display items")

                // Print top-level items
                if let items = hierarchy.displayItems {
                    for item in items {
                        let className = item.viewObject?.rawClassName() ?? item.layerObject?.rawClassName() ?? "?"
                        let oid = item.layerObject?.oid ?? item.viewObject?.oid ?? 0
                        print("      Window: \(className) (oid:\(oid)) frame:\(NSStringFromRect(NSRectFromCGRect(item.frame)))")
                        printSubitems(item.subitems, indent: 8, maxDepth: 3, currentDepth: 0)
                    }
                }
            } catch {
                print("    Hierarchy ERROR: \(error)")
            }

            client.disconnect()
        } catch {
            // Port not available — skip
        }
    }

    private static func printSubitems(_ items: [LookinDisplayItem]?, indent: Int, maxDepth: Int, currentDepth: Int) {
        guard let items, currentDepth < maxDepth else { return }
        let prefix = String(repeating: " ", count: indent)
        for item in items {
            let className = item.viewObject?.rawClassName() ?? item.layerObject?.rawClassName() ?? "?"
            let oid = item.layerObject?.oid ?? item.viewObject?.oid ?? 0
            let hidden = item.isHidden ? " [hidden]" : ""
            print("\(prefix)\(className) (oid:\(oid)) \(Int(item.frame.origin.x)),\(Int(item.frame.origin.y)) \(Int(item.frame.size.width))x\(Int(item.frame.size.height))\(hidden)")
            printSubitems(item.subitems, indent: indent + 2, maxDepth: maxDepth, currentDepth: currentDepth + 1)
        }
    }

    private static func countItems(_ items: [LookinDisplayItem]?) -> Int {
        guard let items else { return 0 }
        var count = items.count
        for item in items {
            count += countItems(item.subitems)
        }
        return count
    }
}
