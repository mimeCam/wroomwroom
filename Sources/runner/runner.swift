
import SystemPackage
import Foundation
import Dispatch
import ArgumentParser
import shared
import LLMGraph

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
                print("ERR. \(error.localizedDescription)")
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

            agent: "", // Persona may specify custom agent. It is possible that no 1 single agent drove the workflow.
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

        print("ERR. \(msg)")
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

    let agent = "openloop_\(w.agent)"
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

    var runPersonas: [[PreparedPersona]]
    if preparedPersonas.isEmpty {
        runPersonas = []
//        runPersonas = [
//            [
//                PreparedPersona(
//                    id: UUID().uuidString,
//                    realId: "_head_",
//                    name: w.name, role: "",
//                    about: "",
//                    task: "",
////                    folder: Paths.curDir.string,
//                    agent: nil
//                )
//            ]
//        ]
    } else {
        runPersonas = preparedPersonas
    }
    let bottom = PreparedPersona(
        id: UUID().uuidString,
        realId: "_bottom_",
        name: w.name, role: "",
        about: "",
        task: "",
//        folder: Paths.curDir.string,
        agent: nil
    )
    runPersonas.append(
        [bottom]
    )

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

private struct PersonaAndId {
    let id: String
    let p: Persona
}

private func fetchLevels(_ ids: [[String]]) async throws -> [[PersonaAndId]]? {
    func fetchPerson(_ id: String) async throws -> Persona? {
        let p = try await FileLoader.loadPersonById(id)
        if let p {
            return p
        }

        // TODO: - load from remote & save under share/*

        return nil
    }

    var res: [[PersonaAndId]] = []
    for level in ids {
        var levelRes: [PersonaAndId] = []

        for id in level {
            let p = try await fetchPerson(id)
            guard let p else {
                assertionFailure(); return nil
            }

            levelRes.append(
                .init(id: id, p: p)
            )
        }

        res.append(levelRes)
    }

    return res
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
    _ levels: [[PersonaAndId]]
) async throws -> [[PreparedPersona]]? {
    var folders: [[String]] = []

    for personas in levels {
        var inner: [String] = []

        for pid in personas {
            let p = pid.p

            let fp = try await preparePersonaFolder(for: p, id: pid.id)
            guard let fp else {
                assertionFailure(); return nil
            }

            inner.append(fp)
        }

        folders.append(inner)
    }

    return levels.enumerated().map { li, personasAndIds in
        personasAndIds.enumerated().map { pi, personaAndId in
            let p = personaAndId.p
            return PreparedPersona(
                id: UUID().uuidString,
                realId: personaAndId.id,
                name: p.name,
                role: p.role,
                about: p.about,
                task: p.task,
//                folder: folders[li][pi],
                agent: p.agent == nil ? nil : ("openloop_" + p.agent!)
            )
        }
    }
}


private struct PreparedPersona: Hashable, Identifiable {
    let id: String
    let realId: String
    let name: String
    let role: String
    let about: String
    let task: String
//    let folder: String
    let agent: String?
}

private func runGraph(
    workflowId: String,
    workflowAgent: String,
    ask: String,
    levels: [[PreparedPersona]],
    outerContext: String?
) async throws -> String {
    levels.forEach {
        assert($0.notEmpty)
    }

    let tops: Set<PreparedPersona>
    if levels.count > 1 {
        tops = Set(levels.first!)
    } else {
        tops = []
    }

    let bottoms: Set<PreparedPersona> = Set(levels.last!)
    assert(bottoms.count == 1)

    typealias P = LLMGraph.Person

    let ps: [String: PreparedPersona] = levels.reduce(into: [:]) { res, ps in
        ps.forEach { p in
            res[p.id] = p
        }
    }
    @Sendable func personById(_ id: String) -> PreparedPersona {
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
        let fromId = talk.from.id
        let from = personById(fromId)

        let parents: [PreparedPersona: String] = talk.responsesFromParent.reduce(
            into: [:]
        ) { res, pair in
            res[personById(pair.key.id)] = pair.value
        }


        let prompt: String
        let middle = """
# Task
\(ask)

# Your job
\(from.task)

Review team reports, provide your professional analysis, and create an updated comprehensive report incorporating all inputs.

FYI: Main project files are located 3 directory levels up from here.
Current directory contains various guides that should help with the task.
Familiarize yourself and then `cd ../../..` to the project's root folder. 
"""
        let bottom = """
# Task
\(ask)

# Reports
Use reports to help you accomplish the task correctly.

FYI: Main project files are located 3 directory levels up from here.
Current directory contains various guides that should help with the task.
Familiarize yourself and then `cd ../../..` to the project's root folder.  
"""

        let context: String?

        if tops.contains(from) {
            context = outerContext
            if let outerContext, outerContext.notEmpty {
                prompt = middle
            } else {
                prompt = ask
            }
        } else if bottoms.contains(from) {
            prompt = bottom
            context = contextFromParents(parents)
        } else {
            prompt = middle
            context = contextFromParents(parents)
            //                # Output
            //                Tell your full response here so that your teammates can continue with the task using your input.
        }

        let res: String
        let tb = TimedBenchmark()

        if fromId.hasPrefix(":") {
            let innerWorkflowId = String(fromId.trimmingPrefix(":"))
            //
            // This is another workflow (nested inside this workflow)
            //
            res = try await start(
                innerWorkflowId, ask: ask,
                context: context
            )
            let success = res.notEmpty

            let log = PersonaRunLog(
                success: success,
                took: Int(tb.intervalSinceInitialized),
                startedAt: tb.startTime, endedAt: tb.now,

                instancePath: Paths.curDir.string,
                workflowId: workflowId,
                personaId: innerWorkflowId,

                agent: "", // Workflows are driver by agents from Personas
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
                throw ValidationError("Inner workflow (\(talk.from.id)) step failed")
            }
        } else {
            //
            // Persona
            //

            let mode: String?

            if tops.contains(from) {
                mode = "plan"
            } else if bottoms.contains(from) {
                mode = nil // "auto" // "build"
            } else {
                mode = "plan"
            }

            let systemPrompt = from.about

            let agent: String
            if let pa = from.agent, pa.notEmpty,
               PathIO.isFileExistent(atPath: Paths.bin.appending(pa).string) {
                agent = pa
            } else {
                agent = workflowAgent
            }

            res = try await subprocess(
                agent,
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




private func contextFromParents(_ all: [PreparedPersona: String]) -> String? {
    all.reduce(into: "") { res, pair in
        let p = pair.key

        if p.name.notEmpty, p.role.notEmpty {
        res += """
## Report from \(p.name), \(p.role):
\(pair.value)

"""
        } else {
            res += """
## Report:
\(pair.value)

"""
        }
    }
}
