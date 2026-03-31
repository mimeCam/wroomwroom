//

import Foundation

public struct Naming { }

public extension Naming {

    #if os(macOS)
    static let workerPrefix = "openloop.worker"
    static let apiServiceName = "openloop.api"
    #elseif os(Linux)
    static let workerPrefix = "openloop-worker"
    static let apiServiceName = "openloop-api"
    #endif

    static func instanceWorkerLabel(for path: String) -> String {
        guard let md5 = path.md5 else {
            assertionFailure("Failed to generate MD5 for path: \(path)")
            return ""
        }
        return "\(workerPrefix).\(md5)"
    }

    static func workerServiceName(for path: String) -> String {
        #if os(macOS)
        return instanceWorkerLabel(for: path)
        #elseif os(Linux)
        guard let md5 = path.md5 else {
            assertionFailure("Failed to generate MD5 for path: \(path)")
            return ""
        }
        return "\(workerPrefix)-\(md5)"
        #endif
    }

}
