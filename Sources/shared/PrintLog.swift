
import Foundation
//@_implementationOnly import Logging

public struct PrintLog: Sendable {
    public init(
        module: String,
//        info: Bool = false, warn: Bool = false, err: Bool = true
        info: Bool? = nil, warn: Bool? = nil, err: Bool? = nil
    ) {
        self.module = module

#if DEBUG
        self.info = info ?? true
//        //self.warn = warn ?? true
//        //self.err = err ?? true
#else
        self.info = info ?? false
//        //self.warn = warn ?? true
//        //self.err = err ?? true
#endif
        self.warn = warn ?? true
        self.err = err ?? true

        //        logger = Logger(label: module)
    }

//    let logger: Logger

    public let module: String
    public let info: Bool
    public let warn: Bool
    public let err: Bool
}

public extension PrintLog {
    // @inlinable
    func info(_ s: @autoclosure () -> String /*Logger.Message*/) {
        guard info else { return }

        //        logger.info("\(module) | \(s())")
        print("INFO", s())
    }

    // @inlinable
    func warn(_ s: @autoclosure () -> String) {
        guard warn else { return }

        //        logger.warning("\(module) | \(s())")
        print("WARN", s())
    }

    func error(_ s: @autoclosure () -> String) {
        err(s())
    }

    // @inlinable
    func err(_ s: @autoclosure () -> String) {
        guard err else { return }

        //        logger.error("\(module) | \(s())")
        print("ERR", s())
    }

}

extension PrintLog {

    @inlinable
    func print(_ level: String, _ s: @autoclosure () -> String) {
        let launchTime = ProcessInfo.processInfo.systemUptime
//        let currentTime = Date().inter
//        let timeOffset = currentTime.timeIntervalSince(launchTime)

        let full = s()
        let contents: String
        let totalCount = full.utf8.count
        let headSize = 200
        let middleSize = 300
        let tailSize = 200
        let shownSize = headSize + middleSize + tailSize
        let hiddenSize = totalCount - shownSize

        if hiddenSize < 1000 {
            contents = full
        } else {
            let head = full.prefix(headSize)
            let tail = full.suffix(tailSize)
            let middleStartIndex = full.index(
                full.startIndex,
                offsetBy: (totalCount - middleSize) / 2
            )
            let middleEndIndex = full.index(
                middleStartIndex,
                offsetBy: middleSize
            )
            let middle = full[middleStartIndex..<middleEndIndex]

            let hiddenBeforeMiddle = (totalCount - middleSize) / 2 - headSize
            let hiddenAfterMiddle = totalCount - tailSize - ((totalCount - middleSize) / 2 + middleSize)

            contents = "\(head)\n... <\(hiddenBeforeMiddle) MORE> ...\n\(middle)\n... <\(hiddenAfterMiddle) MORE> ...\n\(tail)"
        }

        // Comment `Swift.print()` to disable all log output for this file.
        Swift.print("\(launchTime.time2) | \(level) | \(module) | \(contents)")
    }
}
