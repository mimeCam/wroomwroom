import Vapor
import Foundation
import SystemPackage
import shared

struct InstanceHandler: Sendable {

    func getAll(req: Request) async throws -> InstanceListResponse {
        let home = FilePath(NSHomeDirectory())
        let launchAgentsPath = home
            .appending("Library")
            .appending("LaunchAgents")

        var instances: [InstanceInfo] = []

        guard PathIO.isDirectoryExistent(atPath: launchAgentsPath.string) else {
            return InstanceListResponse(instances: [])
        }

        let files = try PathIO.contentsOfDirectory(atPath: launchAgentsPath.string)
        let plistFiles = files.filter { $0.hasPrefix(Naming.workerPrefix) && $0.hasSuffix(".plist") }

        for plistFile in plistFiles {
            let plistPath = launchAgentsPath.appending(plistFile)
            if let path = await parseInstancePath(from: URL(fileURLWithPath: plistPath.string)) {
                do {
                    let state = try await FileLoader.loadInstanceState(at: path)
                    guard let s = state else {
                        throw Abort(.internalServerError, headers: [:])
                    }
                    let date = Date(timeIntervalSinceReferenceDate: s.lastLoopAt)
                    let unixMs = Int64(date.timeIntervalSince1970 * 1000)
                    print("DEBUG: Loading state for instance: \(path), lastLoopAt: \(s.lastLoopAt), unixMs: \(unixMs)")
                    let stateInfo = InstanceStateInfo(
                        lastLoopAtUnixMs: unixMs,
                        activeRunningWorkflows: s.activeRunningWorkflows,
                        inactiveWorkflows: s.inactiveWorkflows
                    )
                    instances.append(InstanceInfo(path: path, state: stateInfo))
                } catch {
                    print("DEBUG: Failed to load state for instance: \(path), error: \(error)")
                    let stateInfo: InstanceStateInfo? = nil
                    instances.append(InstanceInfo(path: path, state: stateInfo))
                }
            }
        }

        return InstanceListResponse(instances: instances)
    }

    func launch(req: Request) async throws -> Response {
        guard let rawId = req.parameters.get("id") else {
            throw Abort(.badRequest, headers: [:])
        }

        let id = rawId.removingPercentEncoding ?? rawId
        let instancePath = FilePath(id)

        guard PathIO.isDirectoryExistent(atPath: instancePath.string) else {
            throw Abort(.notFound, headers: [:])
        }

        guard id.md5 != nil else {
            throw Abort(.badRequest, headers: [:])
        }

        let workerServiceId = Naming.instanceWorkerLabel(for: id)
        let plistPath = FilePath(NSHomeDirectory())
            .appending("Library")
            .appending("LaunchAgents")
            .appending(workerServiceId + ".plist")

        guard PathIO.isFileExistent(atPath: plistPath.string) else {
            throw Abort(.notFound, headers: [:])
        }

        // Unload first (stops if running, removes from launchd)
        _ = try? await exec(
            "/bin/launchctl",
//            args: ["unload", plistPath.string]
            args: ["remove", workerServiceId]
        )

//        // Load (registers with launchd, starts due to RunAtLoad: true)
//        _ = try await exec(
//            "/bin/launchctl",
////            args: ["load", plistPath.string]
//            args: ["start", workerServiceId]
//        )
        let res = try await subprocess(
            "openloop", args: ["&"], chroot: instancePath
        )

        return Response(status: .ok)
    }

    func unload(req: Request) async throws -> Response {
        guard let rawId = req.parameters.get("id") else {
            throw Abort(.badRequest, headers: [:])
        }

        let id = rawId.removingPercentEncoding ?? rawId
        let instancePath = FilePath(id)

        guard PathIO.isDirectoryExistent(atPath: instancePath.string) else {
            throw Abort(.notFound, headers: [:])
        }

        guard id.md5 != nil else {
            throw Abort(.badRequest, headers: [:])
        }

        let workerServiceId = Naming.instanceWorkerLabel(for: id)
        let plistPath = FilePath(NSHomeDirectory())
            .appending("Library")
            .appending("LaunchAgents")
            .appending(workerServiceId + ".plist")

        guard PathIO.isFileExistent(atPath: plistPath.string) else {
            throw Abort(.notFound, headers: [:])
        }

        // Unload (stops process, removes from launchd)
        _ = try await exec(
            "/bin/launchctl",
//            args: ["unload", plistPath.string] # fupertino
            args: ["remove", workerServiceId]
        )

        return Response(status: .ok)
    }

    private func parseInstancePath(from path: URL) async -> String? {
        guard let data = await File(path.path).read() else {
            assertionFailure("Failed to read instance LaunchAgent plist file")
//            throw ValidationError("Failed to read instance LaunchAgent plist file")
            return nil
        }
        guard let plist = try? PropertyListSerialization.propertyList(
                  from: data,
                  options: [],
                  format: nil
        ) as? [String: Any] else {
            assertionFailure("Failed to parse instance LaunchAgent plist file")
//            throw ValidationError("Failed to parse instance LaunchAgent plist file")
            return nil
        }
        guard let workingDirectory = plist["WorkingDirectory"] as? String else {
            assertionFailure("LaunchAgent plist file must have <WorkingDirectory>")
//            throw ValidationError("LaunchAgent plist file must have <WorkingDirectory>")
            return nil
        }

        return workingDirectory
    }
}

extension InstanceHandler {
    struct InstanceInfo: Content, Sendable {
        var path: String
        var state: InstanceStateInfo?
    }

    struct InstanceListResponse: Content, Sendable {
        var instances: [InstanceInfo]
    }

    struct InstanceResponse: Content, Sendable {
        var path: String
    }

    struct InstanceStateInfo: Content, Sendable {
        var lastLoopAtUnixMs: Int64
        var activeRunningWorkflows: Int
        var inactiveWorkflows: Int
    }
}
