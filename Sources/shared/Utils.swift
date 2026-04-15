//

#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif
import Foundation
import CoreFoundation
import Subprocess
import Crypto

private let log = PrintLog(module: "utils")

public struct Paths {
#if DEBUG
    public static let curDir: FilePath = {
        let cd = FilePath(
           FileManager.default.currentDirectoryPath
        )

        let isRunningUnderXcodeWithShittyDefaultDir: Bool
        if cd.string.localizedCaseInsensitiveContains("DerivedData") {
            isRunningUnderXcodeWithShittyDefaultDir = true
        } else if cd.string.localizedCaseInsensitiveContains("Products/openloop") {
            isRunningUnderXcodeWithShittyDefaultDir = true
        } else {
            isRunningUnderXcodeWithShittyDefaultDir = false
        }

        if isRunningUnderXcodeWithShittyDefaultDir {
            return Paths.share
        } else {
            return cd
        }
    }()
#else
    public static let curDir = FilePath(
        FileManager.default.currentDirectoryPath

    )
#endif

    public static let local = FilePath(NSHomeDirectory())
        .appending(".local")
    public static let bin = local
        .appending("bin")

//    public static let state = local
//        .appending("state")
    public static let share = local
        .appending("share")

    public static func dirsToHome() -> [FilePath] {
        let home = FilePath(NSHomeDirectory())
        var cur = curDir
        var result: [FilePath] = []
        while cur != home {
            result.append(cur)
            let parent = cur.removingLastComponent()
            guard parent != cur else { break }
            cur = parent
        }
        return result
    }
}

// MARK: -

public struct TimedBenchmark {
    public init() {}

    public let startTime = CFAbsoluteTimeGetCurrent()
    public var now: CFAbsoluteTime {
        CFAbsoluteTimeGetCurrent()
    }

    public var intervalSinceInitialized: CFAbsoluteTime {
        now - startTime
    }
}

public extension String {

    static func timeN(_ v: Double, _ n: Int = 2) -> String {
        guard v.isValid else { return "Invalid/NaN/Infinity" }

        return String(format: "%.\(n)f", v)
    }
    static func timeN(_ v: Float, _ n: Int = 2) -> String {
        guard v.isValid else { return "Invalid/NaN/Infinity" }

        return String(format: "%.\(n)f", v)
    }
}

public extension Double {
    var time5: String {
        String.timeN(self, 5)
    }

    var time2: String {
        String.timeN(self, 2)
    }

    var time0: String {
        guard isValid else { return "Invalid/NaN/Infinity" }

        return String(Int(self))
    }
}

public extension Float {
    var time5: String {
        String.timeN(self, 2)
    }
}

extension FloatingPoint {

    var isValid: Bool {
        if isNaN { return false }
        if isInfinite { return false }

        return true
    }

}

// MARK: -

public final class PathIO { }

public extension PathIO {
    static func isFileExistent(atPath path: String) -> Bool {
        var isDirectory = false
        let exists = isExistent(atPath: path, isDirectory: &isDirectory)

        return exists && !isDirectory
    }

    static func isDirectoryExistent(atPath path: String) -> Bool {
        var isDirectory = false
        let exists = isExistent(atPath: path, isDirectory: &isDirectory)

        return exists && isDirectory
    }

    static func createDirectoryIfNotExists(atPath inputPath: String) -> Bool {
        var created: Bool
        let path = removingFileProtocolPrefix(path: inputPath)

        if isDirectoryExistent(atPath: path) {
            created = true
        } else {
            do {
                try FileManager.default.createDirectory(
                    atPath: path,
                    withIntermediateDirectories: true,
                    attributes: nil
                )

                created = true
            } catch let error as NSError {
                log.err("Failed to create directory at path: \(path). \(error)")

                created = false
            }
        }

        return created
    }

    static func contentsOfDirectory(atPath path: String) throws -> [String] {
        try fm.contentsOfDirectory(
            atPath: removingFileProtocolPrefix(path: path)
        )
    }

    static func deleteDirectoryAndItsContents(atPath inputPath: String) -> Bool {
        let path = removingFileProtocolPrefix(path: inputPath)

        var didDeleteAllContent = true
//        let files = fm.enumerator(atPath: path)

        // Aparently FileManager does recursive deletions for dirs.
//        while let itemName = files?.nextObject() as? String {
//            let itemPath = path.appending("/\(itemName)")
//
//            var isDirectory = ObjCBool(false)
//            fm.fileExists(atPath: itemPath, isDirectory: &isDirectory)
//
//            let isDeleted: Bool
//            if isDirectory.boolValue {
//                isDeleted = deleteDirectoryAndItsContents(atPath: itemPath)
//            } else {
//                do {
//                    try fm.removeItem(atPath: itemPath)
//
//                    isDeleted = true
//                } catch {
//                    isDeleted = false
//                }
//            }
//
//            didDeleteAllContent = didDeleteAllContent && isDeleted
//        }

        do {
            try fm.removeItem(atPath: path)
        } catch {
            assertionFailure()
            didDeleteAllContent = false
        }

        if !didDeleteAllContent {
            log.err("Failed to recursively delete directory at path: \(path)")
        }

        return didDeleteAllContent
    }

    static func copy(_ src: String, _ dest: String) throws {
        try fm.copyItem(atPath: src, toPath: dest)
    }
}

private let fm = FileManager.default


private extension PathIO {

    static func removingFileProtocolPrefix(path inputPath: String) -> String {
//        inputPath.replacingOccurrences(of: "file:///", with: "/")
        inputPath.replacingOccurrences(of: "file://", with: "")
    }

    static func isExistent(atPath inputPath: String, isDirectory: inout Bool) -> Bool {
//        path.suffix(from: )
//        path.starts(with: "file:///")
        let path = removingFileProtocolPrefix(path: inputPath)

        var directory = ObjCBool(false)
        let exists = FileManager.default.fileExists(
            atPath: path,
            isDirectory: &directory
        )

        isDirectory = directory.boolValue
        return exists
    }
}

// MARK: -

public extension Collection {

    @inlinable
    var notEmpty: Bool {
        !isEmpty
    }

}

// MARK: -

@inlinable
public func minsToNanos(_ m: UInt64) -> UInt64 {
    secsToNanos(60 * m)
}

@inlinable
public func secsToNanos(_ s: UInt64) -> UInt64 {
    s * 1_000_000_000
//    s * 1_000 * 1_000 * 1_000
}

@inlinable
public func millisToNanos(_ s: UInt64) -> UInt64 {
    s * 1_000_000
}

// MARK: -

public extension String {

    var md5: String? {
        guard let data = self.data(using: .utf8) else {
            assertionFailure()
            return nil
        }

        return data.md5String
    }

}

public extension Data {

    var md5: Data? {
        Data(Insecure.MD5.hash(data: self))
    }

    var md5String: String? {
        guard let hash = self.md5 else { return nil }
        var result = ""
        result.reserveCapacity(32) // MD5 is always 16 bytes = 32 hex chars
        for byte in hash {
            result += String(format: "%02hhx", byte)
        }
        return result
    }

}
