import Vapor
import Foundation
import shared

struct InstanceHandler: Sendable {

    func getAll(req: Request) async throws -> InstanceListResponse {
        let workerPaths = try await Launcher.listWorkers()

        var instances: [InstanceInfo] = []
        for path in workerPaths {
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

        return InstanceListResponse(instances: instances)
    }

    func launch(req: Request) async throws -> Response {
        guard let rawId = req.parameters.get("id") else {
            throw Abort(.badRequest, headers: [:])
        }

        let id = rawId.removingPercentEncoding ?? rawId

        guard PathIO.isDirectoryExistent(atPath: id) else {
            throw Abort(.notFound, headers: [:])
        }
        guard id.md5 != nil else {
            throw Abort(.badRequest, headers: [:])
        }

        try await Launcher.launchWorker(workingDirectory: id)

        return Response(status: .ok)
    }

    func unload(req: Request) async throws -> Response {
        guard let rawId = req.parameters.get("id") else {
            throw Abort(.badRequest, headers: [:])
        }

        let id = rawId.removingPercentEncoding ?? rawId

        guard PathIO.isDirectoryExistent(atPath: id) else {
            throw Abort(.notFound, headers: [:])
        }
        guard id.md5 != nil else {
            throw Abort(.badRequest, headers: [:])
        }

        try await Launcher.stopWorker(workingDirectory: id)

        return Response(status: .ok)
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
