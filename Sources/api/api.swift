import Vapor
import shared
import SystemPackage

@main
struct api {
    static func main() async throws {
        #if os(macOS)
        try await registerLaunchAgent()
        #endif

        var env = try Environment.detect()
        try LoggingSystem.bootstrap(from: &env)

        let app = try await Application.make(env)

        do {
            try await configure(app)
            try await app.execute()
        } catch {
            app.logger.report(error: error)
            try? await app.asyncShutdown()
            throw error
        }

        try await app.asyncShutdown()
    }
}

#if os(macOS)
private func registerLaunchAgent() async throws {
    let contents = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>openloop.api</string>

    <key>ProgramArguments</key>
    <array>
        <string>\(Paths.bin.appending("openloop-api"))</string>
        <string>serve</string>
        <string>--port</string>
        <string>54321</string>
    </array>

    <key>WorkingDirectory</key>
    <string>\(Paths.curDir.string)</string>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>\(Paths.share.appending("openloop").appending("api-stdout.log"))</string>
    <key>StandardErrorPath</key>
    <string>\(Paths.share.appending("openloop").appending("api-stderr.log"))</string>
</dict>
</plist>
"""

    let dest = FilePath(NSHomeDirectory())
        .appending("Library").appending("LaunchAgents")
        .appending("openloop.api.plist")
    if PathIO.isFileExistent(atPath: dest.string) {
        return
    }

    guard let data = contents.data(using: .utf8) else {
        assertionFailure()
        return
    }
    guard await File(dest.string).write(data) else {
        assertionFailure()
        return
    }
}
#endif

func configure(_ app: Application) async throws {
    app.routes.defaultMaxBodySize = "2mb"

    let publicPath: String
#if DEBUG
    let local = NSHomeDirectory() + "/dev/sven/opensource/openloop/Sources/api/Public/" // TODO: - change to actual path
    if isDirectoryExistent(atPath: local) {
        publicPath = local
    } else {
        fatalError("Could not find Public directory")
    }
#else
    publicPath = NSHomeDirectory() + "/.local/bin/Public/"
#endif

    app.logger.info("app.directory.publicDirectory: \(app.directory.publicDirectory)")
    app.logger.info("publicPath: \(publicPath)")

    app.middleware.use(FileMiddleware(publicDirectory: publicPath))

    app.get { req async throws in //req async -> Response in
        try await req.fileio.asyncStreamFile(
            at: publicPath  + "index.html"
        )
    }

    let api = app.grouped("api")
    let instances = api.grouped("instances")

    // Instances endpoints
    instances.get { req async throws in
        try await InstanceHandler().getAll(req: req)
    }
    instances.post(":id", "launch") { req async throws in
        try await InstanceHandler().launch(req: req)
    }
    instances.delete(":id") { req async throws in
        try await InstanceHandler().unload(req: req)
    }

    // Workflows endpoints
    instances.grouped(":id", "workflows").get { req async throws in
        try await WorkflowHandler().getAll(req: req)
    }
    instances.grouped(":id", "workflows").post { req async throws in
        try await WorkflowHandler().create(req: req)
    }
    instances.grouped(":id", "workflows", ":wid").get { req async throws in
        try await WorkflowHandler().getOne(req: req)
    }
    instances.grouped(":id", "workflows", ":wid").put { req async throws in
        try await WorkflowHandler().update(req: req)
    }

    // Runs endpoints
    instances.grouped(":id", "workflows", ":wid", "runs").get { req async throws in
        try await RunHandler().getAll(req: req)
    }

    // Personas endpoints
    instances.grouped(":id", "personas").get { req async throws in
        try await PersonaHandler().getAll(req: req)
    }
    instances.grouped(":id", "personas").post { req async throws in
        try await PersonaHandler().create(req: req)
    }
    instances.grouped(":id", "personas", ":pid").get { req async throws in
        try await PersonaHandler().getOne(req: req)
    }
    instances.grouped(":id", "personas", ":pid").put { req async throws in
        try await PersonaHandler().update(req: req)
    }
    instances.grouped(":id", "personas", ":pid").delete { req async throws in
        try await PersonaHandler().delete(req: req)
    }

    // Persona logs endpoint
    instances.grouped(":id", "logs", "personas").get { req async throws in
        try await LogHandler().getPersonaLogs(req: req)
    }

    // Workflow logs endpoint
    instances.grouped(":id", "logs", "workflows", ":workflowId").get { req async throws in
        try await LogHandler().getWorkflowLogs(req: req)
    }

    // Workflow delete endpoint
    instances.grouped(":id", "workflows", ":wid").delete { req async throws in
        try await WorkflowHandler().delete(req: req)
    }

    // Manual workflows endpoints
    instances.grouped(":id", "manual-workflows").get { req async throws in
        try await ManualWorkflowHandler().getAll(req: req)
    }
    instances.grouped(":id", "manual-workflows").post { req async throws in
        try await ManualWorkflowHandler().launch(req: req)
    }
    instances.grouped(":id", "manual-workflows", ":runid").get { req async throws in
        try await ManualWorkflowHandler().getOne(req: req)
    }
    instances.grouped(":id", "manual-workflows", ":runid").delete { req async throws in
        try await ManualWorkflowHandler().delete(req: req)
    }
}

private func isDirectoryExistent(atPath path: String) -> Bool {
    var isDirectory = ObjCBool(false)
    let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
    return exists && isDirectory.boolValue
}

private func publicFolderURL() -> String? {
    return Bundle.module.path(forResource: "Public", ofType: nil)
}
