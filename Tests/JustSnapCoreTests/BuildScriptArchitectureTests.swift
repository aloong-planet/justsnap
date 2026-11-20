import Foundation
import Testing

@Suite("Build script architecture")
struct BuildScriptArchitectureTests {
    @Test("the app build script refuses every architecture except arm64", arguments: ["x64", "universal", "x86_64"])
    func buildScriptRefusesOtherArchitectures(architecture: String) throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("justsnap-build-architecture-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            repositoryRoot.appendingPathComponent("Scripts/build-macos-app.sh").path,
            architecture,
            "1.0.0",
            "1",
            "https://updates.aloongplanet.com/justsnap/appcast-arm64.xml",
            "public-key",
            root.appendingPathComponent("JustSnap.app").path,
        ]
        // A refused architecture must stop before any build starts; if it did
        // not, the missing developer directory makes the build fail fast
        // with a different exit status instead of compiling anything.
        var environment = ProcessInfo.processInfo.environment
        environment["DEVELOPER_DIR"] = root.appendingPathComponent("no-developer-dir").path
        environment["JUSTSNAP_SCRATCH_PATH"] = root.appendingPathComponent("scratch").path
        process.environment = environment
        let errors = Pipe()
        process.standardError = errors

        try process.run()
        process.waitUntilExit()
        let errorText = String(
            data: errors.fileHandleForReading.readDataToEndOfFile(),
            encoding: .utf8
        )

        #expect(process.terminationStatus == 64)
        #expect(errorText?.contains("Unsupported architecture: \(architecture)") == true)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("JustSnap.app").path))
    }

    private var repositoryRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}
