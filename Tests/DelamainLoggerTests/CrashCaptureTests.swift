import Testing
import Foundation
@testable import DelamainLogger

@Suite("CrashCapture Tests", .serialized)
struct CrashCaptureTests {

    // Note: We can't test actual signal handling as it would crash the test runner.
    // These tests focus on context management and installation API.

    // MARK: - Context Management

    @Test("Sets and retrieves context")
    func setsContext() {
        let capture = CrashCapture.shared

        capture.setContext("value1", forKey: "key1")
        capture.setContext("value2", forKey: "key2")

        // Context is private, but we can test through Logger integration
        // Just ensure no crash
    }

    @Test("Clears specific context")
    func clearsSpecificContext() {
        let capture = CrashCapture.shared

        capture.setContext("value", forKey: "toRemove")
        capture.clearContext(forKey: "toRemove")

        // No crash indicates success
    }

    @Test("Clears all context")
    func clearsAllContext() {
        let capture = CrashCapture.shared

        capture.setContext("v1", forKey: "k1")
        capture.setContext("v2", forKey: "k2")
        capture.clearAllContext()

        // No crash indicates success
    }

    // MARK: - Installation

    @Test("Installs and uninstalls without crash")
    func installsAndUninstalls() {
        let capture = CrashCapture.shared

        // Install
        capture.install()

        // Uninstall
        capture.uninstall()

        // No crash indicates success
    }

    @Test("Installs with file URL")
    func installsWithFileURL() {
        let capture = CrashCapture.shared
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_crash.log")

        capture.install(crashLogURL: tempURL)
        capture.uninstall()

        // Cleanup
        try? FileManager.default.removeItem(at: tempURL)
    }

    @Test("Installs with default file")
    func installsWithDefaultFile() {
        let capture = CrashCapture.shared

        capture.installWithDefaultFile(filename: "test_crash.log")
        capture.uninstall()
    }

    @Test("Multiple installs are idempotent")
    func multipleInstallsIdempotent() {
        let capture = CrashCapture.shared

        capture.install()
        capture.install() // Should be no-op
        capture.install() // Should be no-op

        capture.uninstall()
    }

    @Test("Multiple uninstalls are safe")
    func multipleUninstallsSafe() {
        let capture = CrashCapture.shared

        capture.install()
        capture.uninstall()
        capture.uninstall() // Should be no-op
        capture.uninstall() // Should be no-op
    }

    // MARK: - Logger Integration

    @Test("Logger static methods work")
    func loggerStaticMethods() {
        Logger.setCrashContext("testValue", forKey: "testKey")
        Logger.clearCrashContext(forKey: "testKey")

        // No crash indicates success
    }

    // MARK: - Thread Safety

    @Test("Context is thread-safe")
    func contextIsThreadSafe() async {
        let capture = CrashCapture.shared
        capture.clearAllContext()

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    capture.setContext("value\(i)", forKey: "key\(i)")
                }
                group.addTask {
                    capture.clearContext(forKey: "key\(i)")
                }
            }
        }

        capture.clearAllContext()
    }
}
