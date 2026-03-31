
import Foundation
import SystemPackage

public struct Launcher { }

public extension Launcher {

    static func registerWorker(
        workingDirectory: FilePath,
        binaryPath: FilePath
    ) async throws {
        let serviceName = Naming.workerServiceName(for: workingDirectory.string)
        let stdout = workingDirectory
            .appending("openloop")
            .appending("openloop-stdout.log")
        let stderr = workingDirectory
            .appending("openloop")
            .appending("openloop-stderr.log")

        #if os(macOS)
        try await registerLaunchAgent(
            serviceName: serviceName,
            programArguments: [binaryPath.string],
            workingDirectory: workingDirectory.string,
            stdout: stdout.string,
            stderr: stderr.string
        )
        #elseif os(Linux)
        try await registerSystemdUserService(
            serviceName: serviceName,
            execStart: binaryPath.string,
            workingDirectory: workingDirectory.string,
            stdout: stdout.string,
            stderr: stderr.string
        )
        #endif
    }

    static func registerAPI(
        binaryPath: FilePath,
        port: Int
    ) async throws {
        let serviceName = Naming.apiServiceName
        let stdout = Paths.share
            .appending("openloop")
            .appending("api-stdout.log")
        let stderr = Paths.share
            .appending("openloop")
            .appending("api-stderr.log")

        #if os(macOS)
        try await registerLaunchAgent(
            serviceName: serviceName,
            programArguments: [
                binaryPath.string, "serve",
                "--port", "\(port)",
                "--hostname", "0.0.0.0",
            ],
            workingDirectory: Paths.curDir.string,
            stdout: stdout.string,
            stderr: stderr.string
        )
        #elseif os(Linux)
        try await registerSystemdUserService(
            serviceName: serviceName,
            execStart: "\(binaryPath.string) serve --port \(port) --hostname 0.0.0.0",
            workingDirectory: Paths.curDir.string,
            stdout: stdout.string,
            stderr: stderr.string
        )
        #endif
    }

    static func listWorkers() async throws -> [String] {
        #if os(macOS)
        return try await listWorkersMacOS()
        #elseif os(Linux)
        return try await listWorkersLinux()
        #endif
    }

    static func launchWorker(workingDirectory: String) async throws {
        let serviceName = Naming.workerServiceName(for: workingDirectory)

        #if os(macOS)
        let plistPath = launchAgentsDir()
            .appending(serviceName + ".plist")

        _ = try? await exec(
            "/bin/launchctl",
            args: ["unload", plistPath.string]
        )
        _ = try await exec(
            "/bin/launchctl",
            args: ["load", plistPath.string]
        )
        #elseif os(Linux)
        _ = try await exec(
            "/usr/bin/systemctl",
            args: ["--user", "restart", serviceName + ".service"]
        )
        #endif
    }

    static func stopWorker(workingDirectory: String) async throws {
        let serviceName = Naming.workerServiceName(for: workingDirectory)

        #if os(macOS)
        _ = try? await exec(
            "/bin/launchctl",
            args: ["remove", serviceName]
        )
        #elseif os(Linux)
        _ = try? await exec(
            "/usr/bin/systemctl",
            args: ["--user", "stop", serviceName + ".service"]
        )
        #endif
    }
}

// MARK: - macOS

#if os(macOS)
private extension Launcher {

    static func launchAgentsDir() -> FilePath {
        FilePath(NSHomeDirectory())
            .appending("Library")
            .appending("LaunchAgents")
    }

    static func registerLaunchAgent(
        serviceName: String,
        programArguments: [String],
        workingDirectory: String,
        stdout: String,
        stderr: String
    ) async throws {
        let argsXml = programArguments.map { "<string>\($0)</string>" }.joined(separator: "\n        ")

        let contents = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(serviceName)</string>

            <key>ProgramArguments</key>
            <array>
        \(argsXml)
            </array>

            <key>WorkingDirectory</key>
            <string>\(workingDirectory)</string>

            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <true/>

            <key>StandardOutPath</key>
            <string>\(stdout)</string>
            <key>StandardErrorPath</key>
            <string>\(stderr)</string>
        </dict>
        </plist>
        """

        let dest = launchAgentsDir()
            .appending(serviceName + ".plist")

        guard !PathIO.isFileExistent(atPath: dest.string) else {
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

    static func listWorkersMacOS() async throws -> [String] {
        let dir = launchAgentsDir()

        guard PathIO.isDirectoryExistent(atPath: dir.string) else {
            return []
        }

        let files = try PathIO.contentsOfDirectory(atPath: dir.string)
        let plistFiles = files.filter {
            $0.hasPrefix(Naming.workerPrefix) && $0.hasSuffix(".plist")
        }

        var results: [String] = []
        for plistFile in plistFiles {
            let plistPath = dir.appending(plistFile)
            if let path = parseWorkingDirectory(from: plistPath.string) {
                results.append(path)
            }
        }

        return results
    }

    static func parseWorkingDirectory(from plistPath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: plistPath) else {
            return nil
        }
        guard let plist = try? PropertyListSerialization.propertyList(
            from: data, options: [], format: nil
        ) as? [String: Any] else {
            return nil
        }
        return plist["WorkingDirectory"] as? String
    }
}
#endif

// MARK: - Linux

#if os(Linux)
private extension Launcher {

    static func systemdUserDir() -> FilePath {
        FilePath(NSHomeDirectory())
            .appending(".config")
            .appending("systemd")
            .appending("user")
    }

    static func registerSystemdUserService(
        serviceName: String,
        execStart: String,
        workingDirectory: String,
        stdout: String,
        stderr: String
    ) async throws {
        let dir = systemdUserDir()
        _ = PathIO.createDirectoryIfNotExists(atPath: dir.string)

        let dest = dir
            .appending(serviceName + ".service")

        if !PathIO.isFileExistent(atPath: dest.string) {
            let contents = """
            [Unit]
            Description=\(serviceName)

            [Service]
            Type=simple
            ExecStart=\(execStart)
            WorkingDirectory=\(workingDirectory)
            Restart=always
            RestartSec=5
            StandardOutput=file:\(stdout)
            StandardError=file:\(stderr)

            [Install]
            WantedBy=default.target
            """

            guard let data = contents.data(using: .utf8) else {
                assertionFailure()
                return
            }
            guard await File(dest.string).write(data) else {
                assertionFailure()
                return
            }
        }

        _ = try? await exec(
            "/usr/bin/systemctl",
            args: ["--user", "daemon-reload"]
        )
        _ = try? await exec(
            "/usr/bin/systemctl",
            args: ["--user", "enable", "--now", serviceName + ".service"]
        )
    }

    static func listWorkersLinux() async throws -> [String] {
        let dir = systemdUserDir()

        guard PathIO.isDirectoryExistent(atPath: dir.string) else {
            return []
        }

        let files = try PathIO.contentsOfDirectory(atPath: dir.string)
        let serviceFiles = files.filter {
            $0.hasPrefix("openloop-worker-") && $0.hasSuffix(".service")
        }

        var results: [String] = []
        for serviceFile in serviceFiles {
            let servicePath = dir.appending(serviceFile)
            if let path = parseWorkingDirectoryFromService(from: servicePath.string) {
                results.append(path)
            }
        }

        return results
    }

    static func parseWorkingDirectoryFromService(from servicePath: String) -> String? {
        guard let data = FileManager.default.contents(atPath: servicePath) else {
            return nil
        }
        guard let contents = String(data: data, encoding: .utf8) else {
            return nil
        }
        for line in contents.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("WorkingDirectory=") {
                let idx = trimmed.firstIndex(of: "=")!
                return String(trimmed[trimmed.index(after: idx)...])
            }
        }
        return nil
    }
}
#endif
