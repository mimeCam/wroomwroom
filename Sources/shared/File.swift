
import Foundation

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

@available(macOS 10.15, iOS 13.0, *)
public final actor File {
    public init(_ filePath: String) {
        self.filePath = filePath
    }

    public func write(_ data: Data) -> Bool {
        guard let file = fopen(filePath, "w") else {
            assertionFailure()
            return false
        }
        defer { fclose(file) }
        guard _lockExclusive(file) else {
            assertionFailure("Failed to acquire exclusive lock")
            return false
        }

        return data.withUnsafeBytes { p in
            fwrite(p.baseAddress, byteSize, data.count, file)
        } == data.count
    }

    public func read() -> Data? {
        let file = fopen(filePath, "r")
        guard let file else {
            return nil
        }
        defer { fclose(file) }
        guard _lockShared(file) else {
            assertionFailure("Failed to acquire shared lock")
            return nil
        }

        let totalSize = _seekToEndAndGetSize(file)
        rewind(file)

        var data = Data(count: totalSize)
        let read = data.withUnsafeMutableBytes { p in
            fread(p.baseAddress, byteSize, totalSize, file)
        }

        return read == totalSize ? data : nil
    }

    private let filePath: String
}

private let byteSize = MemoryLayout<Int8>.size

private func _seekToEndAndGetSize(
    _ file: UnsafeMutablePointer<FILE>!
) -> Int {
    guard fseek(file, 0, SEEK_END) == 0 else {
        perror("Error seeking to end of file")
        return 0
    }

    let size = ftell(file)
    guard size > 0 else {
        assertionFailure("ftell() failed")
        return 0
    }

    return size
}

// MARK: - File Locking

@inline(__always)
private func _lockShared(_ file: UnsafeMutablePointer<FILE>) -> Bool {
    flock(fileno(file), LOCK_SH | LOCK_NB) == 0
}

@inline(__always)
private func _lockExclusive(_ file: UnsafeMutablePointer<FILE>) -> Bool {
    flock(fileno(file), LOCK_EX) == 0
}
