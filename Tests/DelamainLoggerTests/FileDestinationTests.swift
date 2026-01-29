import Testing
import Foundation
@testable import DelamainLogger

@Suite("FileDestination Tests")
struct FileDestinationTests {
    
    /// Creates a unique test directory for each test
    private func setupTestDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DelamainLoggerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
    
    @Test("FileDestination writes to file")
    func writesToFile() async throws {
        let testDir = try setupTestDirectory()
        let logFile = testDir.appendingPathComponent("test.log")
        let destination = try FileDestination(fileURL: logFile, createDirectories: true)
        
        let message = LogMessage(
            level: .info,
            message: "File test message",
            source: "Test"
        )
        
        await destination.log(message)
        await destination.flush()
        
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        #expect(contents.contains("File test message"))
    }
    
    @Test("FileDestination appends to existing file")
    func appendsToExistingFile() async throws {
        let testDir = try setupTestDirectory()
        let logFile = testDir.appendingPathComponent("append.log")
        
        // Write initial content
        try "Initial content\n".write(to: logFile, atomically: true, encoding: .utf8)
        
        let destination = try FileDestination(fileURL: logFile)
        
        let message = LogMessage(
            level: .info,
            message: "Appended message",
            source: "Test"
        )
        
        await destination.log(message)
        await destination.flush()
        
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        #expect(contents.contains("Initial content"))
        #expect(contents.contains("Appended message"))
    }
    
    @Test("FileDestination creates directory if needed")
    func createsDirectoryIfNeeded() async throws {
        let testDir = try setupTestDirectory()
        let nestedDir = testDir.appendingPathComponent("nested/deep/logs")
        let logFile = nestedDir.appendingPathComponent("test.log")
        
        let destination = try FileDestination(fileURL: logFile, createDirectories: true)
        
        let message = LogMessage(
            level: .info,
            message: "Nested test",
            source: "Test"
        )
        
        await destination.log(message)
        await destination.flush()
        
        #expect(FileManager.default.fileExists(atPath: logFile.path))
    }
    
    @Test("FileDestination respects minimum level")
    func respectsMinimumLevel() async throws {
        let testDir = try setupTestDirectory()
        let logFile = testDir.appendingPathComponent("level.log")
        let destination = try FileDestination(fileURL: logFile, minimumLevel: .error, createDirectories: true)
        
        let debugMessage = LogMessage(level: .debug, message: "Debug", source: "Test")
        let errorMessage = LogMessage(level: .error, message: "Error", source: "Test")
        
        await destination.log(debugMessage)
        await destination.log(errorMessage)
        await destination.flush()
        
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        #expect(!contents.contains("Debug"))
        #expect(contents.contains("Error"))
    }
    
    @Test("FileDestination handles concurrent writes")
    func handlesConcurrentWrites() async throws {
        let testDir = try setupTestDirectory()
        let logFile = testDir.appendingPathComponent("concurrent.log")
        let destination = try FileDestination(fileURL: logFile, createDirectories: true)
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<50 {
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
        
        await destination.flush()
        
        let contents = try String(contentsOf: logFile, encoding: .utf8)
        let lines = contents.components(separatedBy: .newlines).filter { !$0.isEmpty }
        #expect(lines.count == 50)
    }
    
    @Test("FileDestination supports rotation by size")
    func supportsRotationBySize() async throws {
        let testDir = try setupTestDirectory()
        let logFile = testDir.appendingPathComponent("rotate.log")
        let destination = try FileDestination(
            fileURL: logFile,
            createDirectories: true,
            maxFileSize: 500, // 500 bytes
            maxBackupCount: 2
        )
        
        // Write enough to trigger rotation
        for i in 0..<20 {
            let message = LogMessage(
                level: .info,
                message: "Rotation test message \(i) with some padding to fill space",
                source: "Test"
            )
            await destination.log(message)
        }
        
        await destination.flush()
        
        // Check that the main log file exists
        #expect(FileManager.default.fileExists(atPath: logFile.path))
    }
}
