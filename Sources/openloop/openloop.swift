
import Foundation
import SystemPackage
import Dispatch
import shared
import ArgumentParser

@main
struct openloop: ParsableCommand {

    func run() throws {
        Task.detached {
            do {
                try await prepare()

                let success = try? await exec(
                    "/usr/bin/open",
                    args: ["http://localhost:54321"]
                )
                if success == nil {
                    _ = try? await exec(
                        "/usr/bin/xdg-open",
                        args: ["http://localhost:54321"]
                    )

                    print("Open control-plane in the browser: http://localhost:54321")
                }

                while true {
                    try await loop()

                    try await Task.sleep(
                        nanoseconds: 60_000_000_000 // 1m
                        //                    nanoseconds: 10_000_000_000 // 10s
                    )
                }
            } catch {
                openloop.exit(withError: error)
            }
        }

        dispatchMain()
    }
}

private func prepare() async throws {
    prepareFolders()

    #if os(macOS)
    try await registerLaunchAgent()
    #endif
}

#if os(macOS)
private func registerLaunchAgent() async throws {
    guard let md5 = Paths.curDir.string.md5 else {
        assertionFailure(); return
    }

    let contents = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>\(Naming.instanceWorkerLabel(for: Paths.curDir.string))</string>

    <key>ProgramArguments</key>
    <array>
        <string>\(Paths.bin.appending("openloop"))</string>
    </array>

    <key>WorkingDirectory</key>
    <string>\(Paths.curDir.string)</string>

    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>

    <key>StandardOutPath</key>
    <string>\(Paths.curDir.appending("openloop").appending("openloop-stdout.log"))</string>
    <key>StandardErrorPath</key>
    <string>\(Paths.curDir.appending("openloop").appending("openloop-stderr.log"))</string>
</dict>
</plist>
"""

    let dest = FilePath(NSHomeDirectory())
        .appending("Library").appending("LaunchAgents")
        .appending(Naming.instanceWorkerLabel(for: Paths.curDir.string) + ".plist")

    try await writeFileIfNotExistent(dest) {
        guard let data = contents.data(using: .utf8) else {
            fatalError()
        }

        return data
    }
}
#endif

/// Use with delayed data loading like so: ```writeFileIfNotExistent(fileName) { actuallyLoadData() }
private func writeFileIfNotExistent(
    _ dest: FilePath,
    contents: () async throws -> Data
) async throws {
    if PathIO.isFileExistent(atPath: dest.string) {
        return
    }

    let data = try await contents()
    guard await File(dest.string).write(data) else {
        throw ValidationError("Failed to write data to a file. \(#function)")
    }
}

private func prepareFolders() {
    let created0 = PathIO.createDirectoryIfNotExists(
        atPath: Paths.bin.string
    )
    assert(created0)

    let curDirOpenloop = Paths.curDir.appending("openloop")
    let created10 = PathIO.createDirectoryIfNotExists(
        atPath: curDirOpenloop.string
    )
    assert(created10)
    let created11 = PathIO.createDirectoryIfNotExists(
        atPath: curDirOpenloop.appending("workflows").string
    )
    assert(created11)
    let created12 = PathIO.createDirectoryIfNotExists(
        atPath: curDirOpenloop.appending("personas").string
    )
    assert(created12)
    let created13 = PathIO.createDirectoryIfNotExists(
        atPath: curDirOpenloop.appending("knowledge").string
    )
    assert(created13)
//    let created14 = PathIO.createDirectoryIfNotExists(
//        atPath: curDirOpenloop.appending("bin").string
//    )
//    assert(created14)

    let shareOpenloop = Paths.share.appending("openloop")
    let created20 = PathIO.createDirectoryIfNotExists(
        atPath: shareOpenloop.string
    )
    assert(created20)
    let created21 = PathIO.createDirectoryIfNotExists(
        atPath: shareOpenloop.appending("workflows").string
    )
    assert(created21)
    let created22 = PathIO.createDirectoryIfNotExists(
        atPath: shareOpenloop.appending("personas").string
    )
    assert(created22)
    let created23 = PathIO.createDirectoryIfNotExists(
        atPath: shareOpenloop.appending("knowledge").string
    )
    assert(created23)
}

private func loop() async throws {
    let all = try await readWorkflows()

    if all.isEmpty {
        print("Open http://localhost:54321 to create or edit workflows. Currently have 0.")
    }

    var skipped = 0
    for (id, w) in all {
        guard w.everySecs > 0 else {
            skipped += 1
            continue
        }

        if await state.isRunning(id) {
            continue
        }
        let last = await state.lastCompletion(id)
        guard Int(Date().timeIntervalSince(last)) > w.everySecs else {
            continue
        }

        await state.markLaunched(id)
        Task.detached {
            defer {
                Task {
                    await state.markCompleted(id)
                }
            }

            _ = try await runWorkflow(id, w)
        }
    }

    if skipped > 0 {
        print("Skipped \(skipped) manual workflows (everySecs = 0)")
    }

    try await FileLoader.saveInstaneState(
        InstanceState(
            lastLoopAt: Date().timeIntervalSinceReferenceDate,
            activeRunningWorkflows: await state.countRunnint(),
            inactiveWorkflows: skipped
        )
    )
}

private func runWorkflow(
    _ id: String, _ w: Workflow
) async throws -> WorkflowResult? {
    print("Start workflow: \(id)")

    let res = try await subprocess(
        "openloop-runner",
        args: [id, w.ask],
        chroot: .init(Paths.curDir)
    )

    guard let res, res.notEmpty else {
        assertionFailure("Workflow returned empty or no response: \(id)")
        return nil
    }

    print("Workflow \(id): \(res)")

    return nil
}

private let state = State()

private final actor State {

    func isRunning(_ id: String) -> Bool {
        running.contains(id)
    }

    func lastCompletion(_ id: String) -> Date {
        ts[id] ?? Date.distantPast
    }

    func markLaunched(_ id: String) {
        running.insert(id)
//        ts[id] = Date()
    }

    func markCompleted(_ id: String) {
        running.remove(id)
        ts[id] = Date()
    }

    func countRunnint() -> Int {
        running.count
    }

    private var running: Set<String> = []
    private var ts: [String : Date] = [:]

}

private func readWorkflows() async throws -> [String: Workflow] {
    let root = Paths.curDir.appending("openloop").appending("workflows")

    struct IdAndPath {
        let id: String
        let path: FilePath
    }

    var idAndPaths: [IdAndPath] = []
    let files = try PathIO.contentsOfDirectory(atPath: root.string)
    for file in files {
        let parts = file.components(separatedBy: ".")
        guard parts.count == 2, parts.last == shared.json, let id = parts.first else {
            continue
        }
        let path = root.appending(file)
        guard PathIO.isFileExistent(atPath: path.string) else {
            continue
        }
        idAndPaths.append(IdAndPath(id: id, path: path))
    }

    var result: [String: Workflow] = [:]
    for idAndPath in idAndPaths {
        let w: Workflow
        do {
            w = try await FileLoader.loadWorkflowAtPath(idAndPath.path)
        } catch {
            throw ValidationError("Workflow '\(idAndPath.id)' at: \(idAndPath.path) has invalid JSON. Error: \(error.localizedDescription)")
        }

        result[idAndPath.id] = w
    }

    return result
}
