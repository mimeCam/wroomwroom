import Vapor

struct RunHandler: Sendable {

    func getAll(req: Request) async throws -> RunListResponse {
        guard let rawId = req.parameters.get("id"),
              let rawWid = req.parameters.get("wid") else {
            throw Abort(.badRequest)
        }
        let id = rawId.removingPercentEncoding ?? rawId
        let wid = rawWid.removingPercentEncoding ?? rawWid
        return RunListResponse(instance_id: id, workflow_id: wid, runs: [])
    }
}

extension RunHandler {
    struct RunListResponse: Content, Sendable {
        var instance_id: String
        var workflow_id: String
        var runs: [String]
    }
}
