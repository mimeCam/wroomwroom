//

import SystemPackage
import Foundation
import ArgumentParser

public struct FileLoader { }

public extension FileLoader {

    static func saveInstaneState(_ state: InstanceState) async throws {
        let data = try enc.encode(state)

        let fp = Paths.curDir
            .appending("openloop")
            .appending("state.\(json)")

        guard await File(fp.string).write(data) else {
            throw ValidationError("Failed to write state to file: \(fp.string)")
        }
    }

    static func loadInstanceState(at instancePath: String) async throws -> InstanceState? {
        let fp = FilePath(instancePath)
            .appending("openloop")
            .appending("state.\(json)")

        let exists = PathIO.isFileExistent(atPath: fp.string)
        print("DEBUG: loadInstanceState - path: \(fp.string), exists: \(exists)")

        guard exists else {
            return nil
        }

        let state: InstanceState = try await loadAtPath(fp)
        print("DEBUG: loadInstanceState - loaded state for \(instancePath): lastLoopAt=\(state.lastLoopAt)")
        return state
    }

    static func saveRunLog(_ log: RunLog) async throws {
        do {
            try LogManager.saveLog(log)
        } catch {
            assertionFailure(#function)
        }
    }

    static func savePersona(_ persona: Persona, at fp: FilePath) async throws {
        let data = try enc.encode(persona)

        guard await File(fp.string).write(data) else {
            throw ValidationError("Failed to write persona to file: \(fp.string)")
        }
    }

    static func saveWorkflow(_ workflow: Workflow, at fp: FilePath) async throws {
        let data = try enc.encode(workflow)

        guard await File(fp.string).write(data) else {
            throw ValidationError("Failed to write workflow to file: \(fp.string)")
        }
    }

    static func loadWorkflowById(_ id: String) async throws -> Workflow? {
        func tryLoad(in root: FilePath) async throws -> Workflow? {
            let fp = root
                .appending("openloop").appending("workflows")
                .appending("\(id).\(json)")
            guard PathIO.isFileExistent(atPath: fp.string) else {
                return nil
            }

            return try await loadWorkflowAtPath(fp)
        }

        if let w = try await tryLoad(in: Paths.curDir) {
            return w
        }
        if let w = try await tryLoad(in: Paths.share) {
            return w
        }

        return nil
    }

    static func loadPersonById(_ id: String) async throws -> Persona? {
        func tryLoad(in root: FilePath) async throws -> Persona? {
            let fp = root
                .appending("openloop").appending("personas")
                .appending("\(id).\(json)")
            guard PathIO.isFileExistent(atPath: fp.string) else {
                return nil
            }

            return try await loadPersonaAtPath(fp)
        }

        if let p = try await tryLoad(in: Paths.curDir) {
            return p
        }
        if let p = try await tryLoad(in: Paths.share) {
            return p
        }

        return nil
    }

    static func loadPersonaAtPath(_ fp: FilePath) async throws -> Persona {
        try await loadAtPath(fp)
    }

    static func loadWorkflowAtPath(_ fp: FilePath) async throws -> Workflow {
        try await loadAtPath(fp)
    }


}

private func loadAtPath<T: Decodable>(_ fp: FilePath) async throws -> T {
    guard let data = await File(fp.string).read(), data.notEmpty else {
        assertionFailure("Failed to read json file contents: \(fp.string)")
        throw ValidationError("Failed to read json file contents: \(fp.string)")
//        return nil
    }

    do {
        return try dec.decode(T.self, from: data)
    } catch {
        throw ValidationError("\(error)\nFailed to read parse JSON file at: \(fp.string)")
    }
}

private let dec: JSONDecoder = {
    let dec = JSONDecoder()

    dec.keyDecodingStrategy = .convertFromSnakeCase
    dec.allowsJSON5 = true // https://developer.apple.com/documentation/foundation/jsondecoder/allowsjson5

    return dec
}()

private let enc: JSONEncoder = {
    let enc = JSONEncoder()
    enc.keyEncodingStrategy = .convertToSnakeCase
    enc.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
    return enc
}()

public let json = "json5"
