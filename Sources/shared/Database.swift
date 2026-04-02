import Foundation
import Logging
import SQLite
#if canImport(System)
@preconcurrency import System
#else
@preconcurrency import SystemPackage
#endif

private let log = PrintLog(module: "Database")

public struct LogManager {

    private static func getConnection(_ dbPath: String) throws -> Connection {
        return try Connection(dbPath)
    }

    private static func createTables(on db: Connection) throws {
        try db.execute("""
        CREATE TABLE IF NOT EXISTS logs (
            id TEXT PRIMARY KEY,
            success INTEGER NOT NULL,
            took INTEGER NOT NULL,
            started_at REAL NOT NULL,
            ended_at REAL NOT NULL,
            workflow_id TEXT NOT NULL,
            persona_id TEXT,
            agent TEXT NOT NULL,
            instance_path TEXT NOT NULL,
            created_at REAL NOT NULL,
            message_id INTEGER NOT NULL
        );
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_instance_path ON logs(instance_path);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_started_at ON logs(started_at);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_workflow_id ON logs(workflow_id);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_persona_id ON logs(persona_id);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_agent ON logs(agent);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_message_id ON logs(message_id);")

        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_instance_path_persona_workflow_started ON logs(instance_path, persona_id, workflow_id, started_at DESC);")
        try db.run("CREATE INDEX IF NOT EXISTS idx_logs_instance_path_null_persona_started ON logs(instance_path, started_at DESC) WHERE persona_id IS NULL;")

        try db.execute("""
        CREATE TABLE IF NOT EXISTS messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            log_id TEXT NOT NULL,
            input TEXT NOT NULL,
            output TEXT NOT NULL
        );
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_messages_log_id ON messages(log_id);")

        try db.execute("""
        CREATE TABLE IF NOT EXISTS parents (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message_id INTEGER NOT NULL,
            parent_id TEXT NOT NULL,
            text TEXT NOT NULL
        );
        """)

        try db.run("CREATE INDEX IF NOT EXISTS idx_parents_message_id ON parents(message_id);")
    }

    public static func saveLog(_ runLog: RunLog) throws {
        log.info("Starting saveLog")
        log.info("instancePath: \(runLog.instancePath)")
        log.info("workflowId: \(runLog.workflowId)")
        log.info("agent: \(runLog.agent)")
        log.info("success: \(runLog.success)")

        let dbPath = FilePath(runLog.instancePath)
            .appending("openloop")
            .appending("logs.db")
            .string
        log.info("dbPath: \(dbPath)")

        let db = try getConnection(dbPath)
        log.info("Got connection")

        try createTables(on: db)
        log.info("Tables created/verified")

        log.info("Inserting message into messages table")
        try db.run(
            "INSERT INTO messages (log_id, input, output) VALUES (?, ?, ?);",
            runLog.workflowId,
            runLog.msg.input,
            runLog.msg.output
        )
        let messageId = db.lastInsertRowid
        log.info("Message inserted with messageId: \(messageId)")

        log.info("Inserting \(runLog.msg.parents.count) parents")
        for parent in runLog.msg.parents {
            try db.run(
                "INSERT INTO parents (message_id, parent_id, text) VALUES (?, ?, ?);",
                messageId,
                parent.id,
                parent.text
            )
        }
        log.info("Parents inserted")

        log.info("Inserting log into logs table")
        let logId = UUID().uuidString
        if let personaId = runLog.personaId {
            try db.run(
                """
                INSERT INTO logs (id, success, took, started_at, ended_at, workflow_id, persona_id, agent, instance_path, created_at, message_id)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """,
                logId,
                runLog.success ? 1 : 0,
                runLog.took,
                runLog.startedAt,
                runLog.endedAt,
                runLog.workflowId,
                personaId,
                runLog.agent,
                runLog.instancePath,
                Date().timeIntervalSince1970,
                messageId
            )
        } else {
            try db.run(
                """
                INSERT INTO logs (id, success, took, started_at, ended_at, workflow_id, persona_id, agent, instance_path, created_at, message_id)
                VALUES (?, ?, ?, ?, ?, ?, NULL, ?, ?, ?, ?);
                """,
                logId,
                runLog.success ? 1 : 0,
                runLog.took,
                runLog.startedAt,
                runLog.endedAt,
                runLog.workflowId,
                runLog.agent,
                runLog.instancePath,
                Date().timeIntervalSince1970,
                messageId
            )
        }
        log.info("Log inserted successfully")
    }

    public static func countLogs(
        instancePath: String,
        personaId: String? = nil,
        workflowId: String? = nil
    ) throws -> Int {
        log.info("Starting countLogs")
        log.info("instancePath: \(instancePath)")
        log.info("personaId: \(personaId ?? "nil")")
        log.info("workflowId: \(workflowId ?? "nil")")

        let dbPath = FilePath(instancePath)
            .appending("openloop")
            .appending("logs.db")
            .string
        log.info("dbPath: \(dbPath)")

        let db = try getConnection(dbPath)
        log.info("Got connection")

        var baseQuery = "SELECT COUNT(*) as count FROM logs l WHERE l.instance_path = ?"
        var bindCount = 1

        if personaId != nil {
            baseQuery += " AND l.persona_id = ?"
            bindCount += 1
        } else {
            baseQuery += " AND l.persona_id IS NULL"
        }

        if workflowId != nil {
            baseQuery += " AND l.workflow_id = ?"
            bindCount += 1
        }

        let finalQuery = baseQuery + ";"
        log.info("finalQuery: \(finalQuery)")
        log.info("bindCount: \(bindCount)")

        log.info("Executing count query...")

        let count: Int64
        if let personaId, let workflowId {
            count = try db.scalar(finalQuery, instancePath, personaId, workflowId) as? Int64 ?? 0
        } else if let personaId {
            count = try db.scalar(finalQuery, instancePath, personaId) as? Int64 ?? 0
        } else if let workflowId {
            count = try db.scalar(finalQuery, instancePath, workflowId) as? Int64 ?? 0
        } else {
            count = try db.scalar(finalQuery, instancePath) as? Int64 ?? 0
        }

        let resultCount = Int(count)
        log.info("Complete. Count: \(resultCount)")
        return resultCount
    }

    public static func fetchLogs(
        instancePath: String,
        personaId: String? = nil,
        workflowId: String? = nil,
        offset: Int = 0,
        limit: Int = 1000
    ) throws -> [RunLog] {
        log.info("Starting fetchLogs")
        log.info("instancePath: \(instancePath)")
        log.info("personaId: \(personaId ?? "nil")")
        log.info("workflowId: \(workflowId ?? "nil")")

        let dbPath = FilePath(instancePath)
            .appending("openloop")
            .appending("logs.db")
            .string
        log.info("dbPath: \(dbPath)")

        let db = try getConnection(dbPath)
        log.info("Got connection")

        var baseQuery = "SELECT l.success, l.took, l.started_at, l.ended_at, l.workflow_id, l.persona_id, l.agent, l.instance_path, m.input, m.output, m.id FROM logs l JOIN messages m ON l.message_id = m.id WHERE l.instance_path = ?"

        if personaId != nil {
            baseQuery += " AND l.persona_id = ?"
        } else {
            baseQuery += " AND l.persona_id IS NULL"
        }

        if workflowId != nil {
            baseQuery += " AND l.workflow_id = ?"
        }

        let finalQuery = baseQuery + " ORDER BY l.started_at DESC LIMIT ? OFFSET ?;"
        log.info("finalQuery: \(finalQuery)")

        struct LogRowData {
            let success: Bool
            let took: Int
            let startedAt: Double
            let endedAt: Double
            let workflowId: String
            let personaId: String?
            let agent: String
            let instancePath: String
            let input: String
            let output: String
            let messageId: Int64
        }

        log.info("Executing query...")

        var logRows: [LogRowData] = []
        var stmt: Statement

        if let personaId, let workflowId {
            stmt = try db.prepare(finalQuery, instancePath, personaId, workflowId, limit, offset)
        } else if let personaId {
            stmt = try db.prepare(finalQuery, instancePath, personaId, limit, offset)
        } else if let workflowId {
            stmt = try db.prepare(finalQuery, instancePath, workflowId, limit, offset)
        } else {
            stmt = try db.prepare(finalQuery, instancePath, limit, offset)
        }

        for (index, row) in stmt.enumerated() {
            let success = (row[0] as? Int64 ?? 0) != 0
            let took = Int(row[1] as? Int64 ?? 0)
            let startedAt = row[2] as? Double ?? 0
            let endedAt = row[3] as? Double ?? 0
            let workflowId = row[4] as? String ?? ""
            let personaId = row[5] as? String
            let agent = row[6] as? String ?? ""
            let instancePath = row[7] as? String ?? ""
            let input = row[8] as? String ?? ""
            let output = row[9] as? String ?? ""
            let messageId = row[10] as? Int64 ?? 0

            log.info("Row #\(index + 1) data - success: \(success), took: \(took), workflowId: \(workflowId), agent: \(agent), messageId: \(messageId), personaId: \(personaId ?? "NULL")")

            logRows.append(LogRowData(
                success: success,
                took: took,
                startedAt: startedAt,
                endedAt: endedAt,
                workflowId: workflowId,
                personaId: personaId,
                agent: agent,
                instancePath: instancePath,
                input: input,
                output: output,
                messageId: messageId
            ))
        }

        log.info("Query complete. Processing \(logRows.count) logRows into results")

        var parentsMap: [Int64: [RunLog.Message.Parent]] = [:]
        var results: [RunLog] = []

        for logRow in logRows {
            log.info("Processing logRow with messageId: \(logRow.messageId)")
            if parentsMap[logRow.messageId] == nil {
                parentsMap[logRow.messageId] = []
                log.info("Fetching parents for messageId: \(logRow.messageId)")

                var parents: [RunLog.Message.Parent] = []
                let parentStmt = try db.prepare("SELECT parent_id, text FROM parents WHERE message_id = ?;", logRow.messageId)
                for parentRow in parentStmt {
                    if let parentId = parentRow[0] as? String,
                       let text = parentRow[1] as? String {
                        log.info("Found parent - id: \(parentId), text: \(text)")
                        parents.append(RunLog.Message.Parent(id: parentId, text: text))
                    }
                }
                parentsMap[logRow.messageId] = parents
                log.info("Found \(parents.count) parents")
            }

            let parents = parentsMap[logRow.messageId] ?? []
            log.info("Creating RunLog with \(parents.count) parents")
            let runLog = RunLog(
                success: logRow.success,
                took: logRow.took,
                startedAt: logRow.startedAt,
                endedAt: logRow.endedAt,
                instancePath: logRow.instancePath,
                workflowId: logRow.workflowId,
                personaId: logRow.personaId,
                agent: logRow.agent,
                msg: RunLog.Message(input: logRow.input, output: logRow.output, parents: parents)
            )
            results.append(runLog)
        }

        log.info("Complete. Returning \(results.count) results")
        return results
    }
}
