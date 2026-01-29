import Testing
import Foundation
@testable import DelamainLogger

@Suite("BufferedFileDestination Tests")
struct BufferedFileDestinationTests {

    private func tempFileURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("buffered_test_\(UUID().uuidString).log")
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Basic Tests

    @Test("BufferedFileDestination buffers messages")
    func buffersMessages() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 10,
            flushInterval: 60
        )

        let message = LogMessage(
            level: .info,
            message: "Test message",
            source: "Test"
        )

        await destination.log(message)

        // Should be in buffer, not yet on disk
        let bufferedCount = await destination.bufferedCount()
        #expect(bufferedCount == 1)

        // File should be empty or very small
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.isEmpty)

        await destination.close()
    }

    @Test("BufferedFileDestination flushes when batch size reached")
    func flushesAtBatchSize() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 5,
            flushInterval: 60
        )

        // Log 5 messages to trigger flush
        for i in 0..<5 {
            let message = LogMessage(
                level: .info,
                message: "Message \(i)",
                source: "Test"
            )
            await destination.log(message)
        }

        // Give time for flush
        try await Task.sleep(for: .milliseconds(100))

        // Buffer should be empty after flush
        let bufferedCount = await destination.bufferedCount()
        #expect(bufferedCount == 0)

        // File should contain messages
        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("Message 0"))
        #expect(content.contains("Message 4"))

        await destination.close()
    }

    @Test("BufferedFileDestination manual flush works")
    func manualFlush() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 100,
            flushInterval: 60
        )

        let message = LogMessage(
            level: .info,
            message: "Flush test",
            source: "Test"
        )
        await destination.log(message)

        // Manually flush
        await destination.flush()

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("Flush test"))

        await destination.close()
    }

    @Test("BufferedFileDestination flushes on close")
    func flushesOnClose() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 100,
            flushInterval: 60
        )

        let message = LogMessage(
            level: .info,
            message: "Close test",
            source: "Test"
        )
        await destination.log(message)

        // Close should flush
        await destination.close()

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("Close test"))
    }

    @Test("BufferedFileDestination respects minimum level")
    func respectsMinimumLevel() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            minimumLevel: .warning,
            batchSize: 10,
            flushInterval: 60
        )

        await destination.log(LogMessage(level: .debug, message: "Debug", source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Info", source: "Test"))
        await destination.log(LogMessage(level: .warning, message: "Warning", source: "Test"))

        let bufferedCount = await destination.bufferedCount()
        #expect(bufferedCount == 1) // Only warning

        await destination.close()
    }

    @Test("BufferedFileDestination handles concurrent writes")
    func handlesConcurrentWrites() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 50,
            flushInterval: 60
        )

        // Log from multiple concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let message = LogMessage(
                        level: .info,
                        message: "Concurrent \(i)",
                        source: "Test"
                    )
                    await destination.log(message)
                }
            }
        }

        await destination.close()

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        #expect(lines.count == 100)
    }

    @Test("BufferedFileDestination includes metadata")
    func includesMetadata() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 10,
            flushInterval: 60
        )

        let message = LogMessage(
            level: .info,
            message: "With metadata",
            metadata: ["userId": "123", "action": "login"],
            source: "Test"
        )
        await destination.log(message)
        await destination.flush()

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("userId"))
        #expect(content.contains("123"))

        await destination.close()
    }

    @Test("BufferedFileDestination creates directory if needed")
    func createsDirectory() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("subdir_\(UUID().uuidString)")
        let fileURL = dir.appendingPathComponent("test.log")
        defer {
            try? FileManager.default.removeItem(at: dir)
        }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            createDirectories: true
        )

        await destination.log(LogMessage(level: .info, message: "Dir test", source: "Test"))
        await destination.close()

        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    // MARK: - Interval Flush Test

    @Test("BufferedFileDestination flushes at interval")
    func flushesAtInterval() async throws {
        let fileURL = tempFileURL()
        defer { cleanup(fileURL) }

        let destination = try BufferedFileDestination(
            fileURL: fileURL,
            batchSize: 100,  // High batch size so it won't trigger
            flushInterval: 1.5  // Short interval
        )

        let message = LogMessage(
            level: .info,
            message: "Interval test",
            source: "Test"
        )
        await destination.log(message)

        // Wait for interval flush
        try await Task.sleep(for: .seconds(2.5))

        let content = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(content.contains("Interval test"))

        await destination.close()
    }
}
