//

import Foundation

public struct Naming { }

public extension Naming {

    static let workerPrefix = "openloop.worker" // Needs to be distinct from what `api` uses.

    static func instanceWorkerLabel(for path: String) -> String {
        guard let md5 = path.md5 else {
            assertionFailure("Failed to generate MD5 for path: \(path)")
            return ""
        }
        return "\(workerPrefix).\(md5)"
    }

}
