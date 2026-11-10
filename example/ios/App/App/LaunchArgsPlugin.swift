import Foundation
import Capacitor

/// Example app only. Hands the "-validate <phase>" launch argument to the web page, so a validation
/// run can be started with: xcrun simctl launch <device> <bundle id> -validate p1
@objc(LaunchArgsPlugin)
public class LaunchArgsPlugin: CAPPlugin {
    @objc func get(_ call: CAPPluginCall) {
        let args = ProcessInfo.processInfo.arguments
        var result: [String: Any] = [:]
        if let i = args.firstIndex(of: "-validate"), i + 1 < args.count {
            result["validate"] = args[i + 1]
        }
        call.resolve(result)
    }

    /// Sizes in bytes of the plugin's collection files, for the timing report.
    @objc func fileSizes(_ call: CAPPluginCall) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OfflineBM25", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: base.path)) ?? []
        let files: [[String: Any]] = names.sorted().map { name in
            let attributes = try? FileManager.default.attributesOfItem(atPath: base.appendingPathComponent(name).path)
            return ["name": name, "bytes": (attributes?[.size] as? NSNumber)?.intValue ?? -1]
        }
        call.resolve(["files": files])
    }
}
