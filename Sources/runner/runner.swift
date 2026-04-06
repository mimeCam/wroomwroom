
#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif
import Foundation
import Dispatch
import ArgumentParser
import shared
import LLMGraph

private let log = PrintLog(module: "runner")

@main
struct runner: ParsableCommand {
//    @Argument(help: "The agent to use")
//    var agent: String
    @Argument(help: "Worflow ID")
    var workflow: String

    @Argument(help: "Ask (override) in case user overrides an ask during manual run")
    var ask: String?

    func run() throws {
        guard workflow.notEmpty else {
            throw ValidationError("workflow cannot be empty")
        }

        Task {
            do {
                try await start(
                    workflow, ask: ask,
                    context: try? readPipedStdin()
                )
            } catch {
                assertionFailure("ERR. \(error.localizedDescription)")
                log.err(error.localizedDescription)
                runner.exit(withError: error)
            }

            runner.exit()
        }

        dispatchMain()
    }

}

private func readPipedStdin() throws -> String? {
    let isPiped = isatty(FileDescriptor.standardInput.rawValue) == 0

    guard isPiped else {
        return nil
    }

    var data = [UInt8]()
    var buffer = [UInt8](repeating: 0, count: 10 * 1024)

    while true {
        let bytesRead = try buffer.withUnsafeMutableBytes { ptr in
            try FileDescriptor.standardInput.read(into: ptr)
        }
        if bytesRead == 0 { break }
        data.append(contentsOf: buffer[0..<bytesRead])
    }

    return String(bytes: data, encoding: .utf8)
}

private func start(
    _ workflow: String, ask: String?,
    context: String?
) async throws -> String {
    let w = try await FileLoader.loadWorkflowById(workflow)
    guard let w else {
        throw ValidationError("Workflow not found: \(workflow)")
    }

    let validAsk: String
    if let ask, ask.notEmpty {
        validAsk = ask
    } else if w.ask.notEmpty {
        validAsk = w.ask
    } else {
        throw ValidationError("Ask cannot be empty")
    }

    let tb = TimedBenchmark()

    func saveLog(_ res: String) async throws {
        let elapsed = tb.intervalSinceInitialized

        let success = res.notEmpty

        let log = WorkflowRunLog(
            success: success,
            took: Int(elapsed),
            startedAt: tb.startTime, endedAt: tb.now,

            instancePath: Paths.curDir.string,
            workflowId: workflow,
            personaId: nil,


            agent: w.agent,
            msg: .init(
                input: validAsk, output: res,
                parents: []
            )
        )
        try await FileLoader.saveRunLog(log)
    }

    let res: String
    do {
        res = try await runWorkflow(
            workflow,
            ask: validAsk,
            context: context
        )

        print(res) // MUST print to stdout so that openloop captures as a result.

        try await saveLog(res)
    } catch {
        let msg = (error as? ValidationError)?.message ?? error.localizedDescription

        log.err(msg)
        try? await saveLog("ERR. \(msg)")

        runner.exit(withError: error)
    }

    return res
}

// MARK: -

private func runWorkflow(
    _ workflowId: String, ask: String,
    context: String?
) async throws -> String {
    let w = try await fetchWorkflow(by: workflowId)
    guard let w else {
        throw ValidationError("Could not load workflow: \(workflowId)")
    }

    guard w.agent.notEmpty else {
        throw ValidationError("Workflow has empty `agent` value. Set it to `oc_docker`, `cc_docker` or other custom agent.")
    }
    let agent = "openloop_\(w.agent)"
//    let localAgentExists = PathIO.isFileExistent(
//        atPath: Paths.curDir
//            .appending("openloop").appending("bin")
//            .appending(agent).string
//    )
    let agentExists = PathIO.isFileExistent(
        atPath: Paths.bin.appending(agent).string
    )
    guard agentExists else {
        throw ValidationError("Requested agent not found: \(agent)")
    }

    let levels = try await fetchLevels(w.levels)
    guard let levels else {
        throw ValidationError("Bad levels")
    }

    let preparedPersonas = try await preparePersonas(levels)
    guard let preparedPersonas else {
        throw ValidationError("Bad personas")
    }
//    defer {
//        cleanUpTempFolders(for: preparedPersonas)
//    }

    let addSingleBottomCompletion: Bool
    var runPersonas: [[PreparedRunItem]]
    if preparedPersonas.isEmpty {
        runPersonas = []

        addSingleBottomCompletion = true
    } else {
        runPersonas = preparedPersonas

        let empty = (preparedPersonas.last?.count ?? 0) == 0
        assert(!empty)
        let moreThanOne = (preparedPersonas.last?.count ?? 0) > 1
        addSingleBottomCompletion = moreThanOne
    }
    if addSingleBottomCompletion {
        let bottom = PreparedRunItem(
            id: UUID().uuidString, realId: "_bottom_",
            name: "_bottom_",
            persona: PreparedPersona(
                role: "",
                about: "",
                task: "",
                agent: nil
            ),
            workflow: nil,
            forceRW: true
        )
        runPersonas.append(
            [bottom]
        )
    }

    let res = try await runGraph(
        workflowId: workflowId,
        workflowAgent: agent,
        ask: ask,
        levels: runPersonas,
        outerContext: context
    )
    guard res.notEmpty else {
        throw ValidationError("Empty response from the llm-graph. LLM agent failed.")
    }

    return res
}

private func fetchWorkflow(by id: String) async throws -> Workflow? {
    let w = try await FileLoader.loadWorkflowById(id)
    if let w {
        return w
    }

    // TODO: - fetch workflow from web & save to state/*

    return nil
}

private struct LevelRunItemAndId {
    let id: String
    let p: Persona?
    let w: Workflow?
    let isRW: Bool
}

private func fetchLevels(_ ids: [[String]]) async throws -> [[LevelRunItemAndId]]? {
    func fetchPerson(_ id: String) async throws -> Persona? {
        let p = try await FileLoader.loadPersonById(id)
        if let p {
            return p
        }

        // TODO: - load from remote & save under share/*

        return nil
    }

    var res: [[LevelRunItemAndId]] = []
    for level in ids {
        if level.isEmpty  {
            continue
        }

        var levelRes: [LevelRunItemAndId] = []

        for id in level {
            if id.hasPrefix(":") {
                let w = try await FileLoader.loadWorkflowById(
                    String(id.trimmingPrefix(":"))
                )
                guard let w else {
                    throw ValidationError("Inner Workflow not found: \(id)")
                }

                levelRes.append(
                    .init(id: id, p: nil, w: w, isRW: false)
                )
            } else {
                let ref = parsePersonaRef(id)
                let p = try await fetchPerson(ref.id)
                guard let p else {
                    throw ValidationError("Person does not exist: \(ref.id)")
                }

                levelRes.append(
                    .init(id: ref.id, p: p, w: nil, isRW: ref.isRW)
                )
            }
        }

        res.append(levelRes)
    }

    return res
}

private struct PersonaRef: Sendable {
    public let id: String
    public let isRW: Bool

    public init(id: String, isRW: Bool) {
        self.id = id
        self.isRW = isRW
    }
}

private func parsePersonaRef(_ input: String) -> PersonaRef {
    if input.hasPrefix(":") {
        return PersonaRef(id: input, isRW: false)
    }
    if input.hasSuffix(":rw") && input.count > 3 {
        return PersonaRef(id: String(input.dropLast(3)), isRW: true)
    }
    return PersonaRef(id: input, isRW: false)
}


//private func cleanUpTempFolders(for levels: [[PreparedPersona]]) {
//    levels.forEach { personas in
//        personas.forEach { p in
//            let deleted = PathIO.deleteDirectoryAndItsContents(
//                atPath: p.folder
//            )
//            assert(deleted)
//        }
//    }
//}

private func preparePersonaFolder(
    for p: Persona, id: String
) async throws -> String? {

    let cur = Paths.curDir
        .appending("openloop").appending("knowledge")
        .appending(id).string

    if PathIO.isDirectoryExistent(atPath: cur) {
        return cur
    }

    let share = Paths.share
        .appending("openloop").appending("knowledge")
        .appending(id).string

    if PathIO.isDirectoryExistent(atPath: share) {
        try PathIO.copy(share, cur)

        return cur
    }

//    func copySrcToNewTemp(_ src: String) throws -> String? {
//        let dest = FilePath(NSTemporaryDirectory()).appending(UUID().uuidString).string
//
//        try PathIO.copy(src, dest)
//        return dest
//    }
//
//    func withRoot(_ root: FilePath) throws -> String? {
//        let path = root
//            .appending("openloop").appending("knowledge")
//            .appending(p.folderId).string
//
//        if PathIO.isDirectoryExistent(atPath: path) {
//            return try copySrcToNewTemp(path)
//        }
//
//        return nil
//    }
//
//    if let res = try withRoot(Paths.curDir) {
//        return res
//    }
//    if let res = try withRoot(Paths.share) {
//        return res
//    }

    // TODO: - fetch from remote

    throw ValidationError("No persona found and no folder exists. For local-only knowledge create folder: openloop/knowledge/\(id)")

    return nil
}

private func preparePersonas(
    _ levels: [[LevelRunItemAndId]]
) async throws -> [[PreparedRunItem]]? {
    var folders: [[String]] = []

    for runItems in levels {
        var inner: [String] = []

        for ri in runItems {
            if let p = ri.p {

                let fp = try await preparePersonaFolder(for: p, id: ri.id)
                guard let fp else {
                    assertionFailure(); return nil
                }

                inner.append(fp)
            } else if let w = ri.w {
                inner.append("")
            } else {
                fatalError()
            }
        }

        folders.append(inner)
    }

    return levels.enumerated().map { li, personasAndIds in
        let soloOnLevel = personasAndIds.count == 1
        return personasAndIds.enumerated().map { pi, personaAndId in
            if let p = personaAndId.p {
                let effectiveRW = personaAndId.isRW && soloOnLevel
                return PreparedRunItem(
                    id: UUID().uuidString, realId: personaAndId.id,
                    name: p.name,
                    persona: PreparedPersona(
                        role: p.role,
                        about: p.about,
                        task: p.task,
                        agent: p.agent == nil ? nil : ("openloop_" + p.agent!)
                    ),
                    workflow: nil,
                    forceRW: effectiveRW
                )
            } else if let w = personaAndId.w {
                return PreparedRunItem(
                    id: UUID().uuidString, realId: personaAndId.id,
                    name: w.name,
                    persona: nil,
                    workflow: PreparedWorkflow(
                        agent: w.agent
                    ),
                    forceRW: false
                )
            } else {
                fatalError()
            }
        }
    }
}

private struct PreparedRunItem: Hashable, Identifiable {
    let id: String
    let realId: String
    let name: String

    let persona: PreparedPersona?
    let workflow: PreparedWorkflow?
    let forceRW: Bool
}

private struct PreparedPersona: Hashable {
    let role: String
    let about: String
    let task: String
//    let folder: String
    let agent: String?
}

private struct PreparedWorkflow: Hashable {
    let agent: String
}

private func runGraph(
    workflowId: String,
    workflowAgent: String,
    ask: String,
    levels: [[PreparedRunItem]],
    outerContext: String?
) async throws -> String {
    levels.forEach {
        assert($0.notEmpty)
    }

    let tops: Set<PreparedRunItem>
    if levels.count > 1 {
        tops = Set(levels.first!)
    } else {
        tops = []
    }

    let bottoms: Set<PreparedRunItem> = Set(levels.last!)
    assert(bottoms.count == 1)

    typealias P = LLMGraph.Person

    let ps: [String: PreparedRunItem] = levels.reduce(into: [:]) { res, ps in
        ps.forEach { p in
            res[p.id] = p
        }
    }
    @Sendable func runItemById(_ id: String) -> PreparedRunItem {
        assert(ps[id] != nil)
        return ps[id]!
    }

    let g = Graph<String>.withLevels(
        "openloop",
        levels.map { ps in
            ps.map { p in
                P(id: p.id, name: p.name)
            }
        },
        .short
    ) { talk in
        if let _ = talk.to {
            fatalError("Not implemented. Should not be called in Graph.short mode. For now use `.short` mode only.")
        }
        let from = runItemById(talk.from.id)

        let parents: [PreparedRunItem: String] = talk.responsesFromParent.reduce(
            into: [:]
        ) { res, pair in
            res[runItemById(pair.key.id)] = pair.value
        }

        let reportsDir = FilePath(NSTemporaryDirectory())
            .appending(UUID().uuidString)
        guard PathIO.createDirectoryIfNotExists(atPath: reportsDir.string) else {
            throw ValidationError("Could not create tmp _reports folder: \(reportsDir.string)")
        }
        defer {
            _ = PathIO.deleteDirectoryAndItsContents(atPath: reportsDir.string)
        }
        let context: String?

        if tops.contains(from) {
            context = outerContext
        } else {
            context = await contextFromParents(parents, reportsDir: reportsDir)
        }
        let hasContext = context?.notEmpty ?? false

        let res: String
        let tb = TimedBenchmark()

        if from.realId.hasPrefix(":") {
            assert(from.workflow != nil)
            let innerWorkflowId = String(from.realId.trimmingPrefix(":"))
            //
            // This is another workflow (nested inside this workflow)
            //
            res = try await start(
                innerWorkflowId, ask: ask,
                context: context
            )
            let success = res.notEmpty

            guard success else {
                throw ValidationError("Inner workflow (\(talk.from.id)) step failed")
            }
        } else {
            //
            // Persona
            //
            assert(from.persona != nil)

            let rw = bottoms.contains(from) || from.forceRW

            let coreTask: String
            if let task = from.persona?.task, task.notEmpty {
                coreTask = """
\(task)

# Project Vision (read-only context — do not act on this)
\(ask)
"""
            } else {
                coreTask = ask
            }

            let fakeBottom = from.realId == "_bottom_"

            let prompt = """
# Task (your scope)
\(coreTask)

# Instructions
\(hasContext 
    ? (fakeBottom
        ? "- Read directions provided by your teammates in `_reports` folder"
        : "- Read directions provided by your teammates in `../_reports` folder")
    : ""
)
\(fakeBottom
    ? "- Begin working on the task"
    : "- `cd ..` to the project root folder to begin the task, applying knowledge from guides in this folder"
)
\(hasContext
    ? "- When done, save your findings to `~/report.md`. Credit teammates for their input"
    : "- When done, save your findings to `~/report.md`"
)
"""

            let mode: String?

            if bottoms.contains(from) {
                mode = nil // "auto" // "build"
            } else if from.forceRW {
                mode = nil
            } else {
                mode = "plan"
            }

            let systemPrompt = from.persona?.about ?? ""

            let agent: String
            let agentPath: FilePath
            if let pa = from.persona?.agent, pa.notEmpty {
                // Project-specific scripts inside <prj>/openloop/bin does not need `openloop_` prefix.
                // Only ~/.local/bin/openloop_* should be prefixed.
                let shortName = String(pa.trimmingPrefix("openloop_"))

                let prjBin = Paths.curDir
                    .appending("openloop").appending("bin")
                    .appending(shortName)
                let userLocalBin = Paths.bin.appending(pa)

                if PathIO.isFileExistent(atPath: prjBin.string) {
                    agent = shortName
                    agentPath = prjBin
                } else if PathIO.isFileExistent(atPath: userLocalBin.string) {
                    agent = pa
                    agentPath = userLocalBin
                } else {
                    agent = workflowAgent
                    agentPath = Paths.bin.appending(workflowAgent)
                }
            } else {
                agent = workflowAgent
                agentPath = Paths.bin.appending(workflowAgent)
            }

            res = try await subprocess(
                agentPath,
                args: (mode == nil) ? [
                    from.realId, prompt, systemPrompt
                ] : [
                    from.realId,
                    prompt,
                    systemPrompt,
                    mode!,
                ],
                chroot: Paths.curDir, // .init(from.folder),
                stdin: context
            ) ?? ""

            let success = res.notEmpty

            let log = PersonaRunLog(
                success: success,
                took: Int(tb.intervalSinceInitialized),
                startedAt: tb.startTime, endedAt: tb.now,

                instancePath: Paths.curDir.string,
                workflowId: workflowId,
                personaId: from.realId,

                agent: agent,
                msg: .init(
                    input: prompt, output: res,
                    parents: parents.map { p, msg in
                        PersonaRunLog.Message.Parent(
                            id: p.realId, text: msg
                        )
                    }
                )
            )
            try await FileLoader.saveRunLog(log)

            guard success else {
                throw ValidationError("Person (\(from.name)) step failed")
            }
        }

        return res
    }

    return try await g.run(ask)

}

private func slugify(_ s: String) -> String {
    s.lowercased()
        .components(separatedBy: CharacterSet.alphanumerics.inverted)
        .filter { $0.notEmpty }
        .joined(separator: "-")
}

private func contextFromParents(
    _ all: [PreparedRunItem: String],
    reportsDir: FilePath
) async -> String? {
    guard all.notEmpty else { return nil }

    for pair in all {
        let item = pair.key
        let suffix = Int.random(in: 1...100)
        let fileName: String

        if let p = item.persona {
            if item.name.notEmpty, p.role.notEmpty {
                fileName = "from-\(slugify(item.name))-\(slugify(p.role))-\(suffix).md"
            } else {
                fileName = "by-\(slugify(p.role))-\(suffix).md"
            }
        } else if item.workflow != nil {
            fileName = "\(slugify(item.name))-\(suffix).md"
        } else {
            assertionFailure(); continue
        }

        let filePath = reportsDir.appending(fileName)
        guard let data = pair.value.data(using: .utf8) else {
            assertionFailure(); continue
        }
        let f = File(filePath.string)
        guard await f.write(data) else {
            assertionFailure(); continue
        }
    }

    return reportsDir.string
}
