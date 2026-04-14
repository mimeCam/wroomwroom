import Vapor
import Foundation
import shared

private let log = PrintLog(module: "instance-handler")

struct InstanceHandler: Sendable {

    func getAll(req: Request) async throws -> InstanceListResponse {
        let workerPaths = try await Launcher.listWorkers()

        // Fetch all manual workflows once (RAM-only, cheap)
        let allManual = await ManualWorkflowRegistry.shared.getAll()

        var instances: [InstanceInfo] = []
        for path in workerPaths {
            do {
                let state = try await FileLoader.loadInstanceState(at: path)
                guard let s = state else {
                    throw Abort(.internalServerError, headers: [:])
                }
                let date = Date(timeIntervalSinceReferenceDate: s.lastLoopAt)
                let unixMs = Int64(date.timeIntervalSince1970 * 1000)
                let stateInfo = InstanceStateInfo(
                    lastLoopAtUnixMs: unixMs,
                    activeRunningWorkflows: s.activeRunningWorkflows,
                    inactiveWorkflows: s.inactiveWorkflows
                )

                let instanceManual = allManual.filter { $0.instancePath == path }
                let manualActive = instanceManual.filter { $0.status == "running" }.count
                let manualCompleted = instanceManual.filter { $0.status == "completed" || $0.status == "failed" }.count

                instances.append(InstanceInfo(
                    path: path,
                    parentPath: nil,
                    state: stateInfo,
                    manualActive: manualActive,
                    manualCompleted: manualCompleted
                ))
            } catch {
                log.err("Failed to load state for instance: \(path), error: \(error)")
                let stateInfo: InstanceStateInfo? = nil

                let instanceManual = allManual.filter { $0.instancePath == path }
                let manualActive = instanceManual.filter { $0.status == "running" }.count
                let manualCompleted = instanceManual.filter { $0.status == "completed" || $0.status == "failed" }.count

                instances.append(InstanceInfo(
                    path: path,
                    parentPath: nil,
                    state: stateInfo,
                    manualActive: manualActive,
                    manualCompleted: manualCompleted
                ))
            }
        }

        let parentPaths = InstanceHandler.computeParentPaths(
            instances.map { $0.path }
        )
        for i in instances.indices {
            instances[i].parentPath = parentPaths[i]
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
        var parentPath: String?
        var state: InstanceStateInfo?
        var manualActive: Int
        var manualCompleted: Int
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

    // O(n²) on instance count — fine for typical n < 20
    static func computeParentPaths(_ paths: [String]) -> [String?] {
        let sorted = paths.sorted { $0.count < $1.count }
        return paths.map { path in findParent(for: path, among: sorted) }
    }

    static func findParent(for path: String, among candidates: [String]) -> String? {
        candidates
            .filter { isStrictParentPath($0, of: path) }
            .max(by: { $0.count < $1.count })
    }

    static func isStrictParentPath(_ candidate: String, of path: String) -> Bool {
        guard path.hasPrefix(candidate), candidate != path else { return false }
        let idx = candidate.endIndex
        return candidate.last == "/" || path[idx] == "/"
    }
}
