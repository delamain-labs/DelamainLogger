import Testing
import Foundation
@testable import DelamainLogger

@Suite("SQLiteDestination Tests")
struct SQLiteDestinationTests {
    
    @Test("SQLiteDestination logs messages to database")
    func logsMessagesToDatabase() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let message = LogMessage(
            level: .info,
            message: "Test message",
            metadata: ["key": "value"],
            source: "TestSource"
        )
        
        await destination.log(message)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 1)
        #expect(logs[0].message == "Test message")
        #expect(logs[0].level == .info)
        #expect(logs[0].source == "TestSource")
        #expect(logs[0].metadata?["key"] == "value")
    }
    
    @Test("SQLiteDestination respects minimum level")
    func respectsMinimumLevel() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:", minimumLevel: .warning)
        
        await destination.log(LogMessage(level: .debug, message: "Debug", source: "Test"))
        await destination.log(LogMessage(level: .warning, message: "Warning", source: "Test"))
        await destination.log(LogMessage(level: .error, message: "Error", source: "Test"))
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 2)
        #expect(logs.allSatisfy { $0.level >= .warning })
    }
    
    @Test("SQLiteDestination stores all fields correctly")
    func storesAllFieldsCorrectly() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        let timestamp = Date()
        
        let message = LogMessage(
            level: .error,
            message: "Full message test",
            metadata: ["user": "123", "action": "login"],
            source: "AuthService",
            file: "/path/to/File.swift",
            function: "authenticate()",
            line: 42,
            timestamp: timestamp
        )
        
        await destination.log(message)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 1)
        
        let log = logs[0]
        #expect(log.level == .error)
        #expect(log.message == "Full message test")
        #expect(log.source == "AuthService")
        #expect(log.file == "/path/to/File.swift")
        #expect(log.function == "authenticate()")
        #expect(log.line == 42)
        #expect(log.metadata?["user"] == "123")
        #expect(log.metadata?["action"] == "login")
        #expect(abs(log.timestamp.timeIntervalSince(timestamp)) < 1)
    }
    
    @Test("SQLiteDestination handles nil metadata")
    func handlesNilMetadata() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let message = LogMessage(
            level: .info,
            message: "No metadata",
            metadata: nil,
            source: "Test"
        )
        
        await destination.log(message)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 1)
        #expect(logs[0].metadata == nil)
    }
    
    @Test("SQLiteDestination handles empty metadata")
    func handlesEmptyMetadata() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let message = LogMessage(
            level: .info,
            message: "Empty metadata",
            metadata: [:],
            source: "Test"
        )
        
        await destination.log(message)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 1)
        #expect(logs[0].metadata == nil || logs[0].metadata?.isEmpty == true)
    }
    
    @Test("SQLiteDestination supports custom table name")
    func supportsCustomTableName() async throws {
        let destination = try SQLiteDestination(
            databasePath: ":memory:",
            tableName: "custom_logs"
        )
        
        let message = LogMessage(level: .info, message: "Custom table", source: "Test")
        await destination.log(message)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 1)
    }
    
    @Test("SQLiteDestination fetches by level")
    func fetchesByLevel() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await destination.log(LogMessage(level: .debug, message: "Debug", source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Info", source: "Test"))
        await destination.log(LogMessage(level: .warning, message: "Warning", source: "Test"))
        await destination.log(LogMessage(level: .error, message: "Error 1", source: "Test"))
        await destination.log(LogMessage(level: .error, message: "Error 2", source: "Test"))
        
        let errors = try await destination.fetch(level: .error)
        #expect(errors.count == 2)
        #expect(errors.allSatisfy { $0.level == .error })
        
        let warnings = try await destination.fetch(level: .warning)
        #expect(warnings.count == 1)
    }
    
    @Test("SQLiteDestination fetches by minimum level")
    func fetchesByMinimumLevel() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await destination.log(LogMessage(level: .debug, message: "Debug", source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Info", source: "Test"))
        await destination.log(LogMessage(level: .warning, message: "Warning", source: "Test"))
        await destination.log(LogMessage(level: .error, message: "Error", source: "Test"))
        
        let warningAndAbove = try await destination.fetch(minimumLevel: .warning)
        #expect(warningAndAbove.count == 2)
        #expect(warningAndAbove.allSatisfy { $0.level >= .warning })
    }
    
    @Test("SQLiteDestination fetches by date range")
    func fetchesByDateRange() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        await destination.log(LogMessage(level: .info, message: "Old", source: "Test", timestamp: twoHoursAgo))
        await destination.log(LogMessage(level: .info, message: "Recent", source: "Test", timestamp: hourAgo))
        await destination.log(LogMessage(level: .info, message: "Now", source: "Test", timestamp: now))
        
        let ninetyMinutesAgo = now.addingTimeInterval(-5400)
        let logs = try await destination.fetch(from: ninetyMinutesAgo, to: now.addingTimeInterval(60))
        
        #expect(logs.count == 2)
        #expect(logs.contains { $0.message == "Recent" })
        #expect(logs.contains { $0.message == "Now" })
        #expect(!logs.contains { $0.message == "Old" })
    }
    
    @Test("SQLiteDestination fetches by source")
    func fetchesBySource() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await destination.log(LogMessage(level: .info, message: "Auth log", source: "AuthService"))
        await destination.log(LogMessage(level: .info, message: "Network log", source: "NetworkService"))
        await destination.log(LogMessage(level: .info, message: "Another auth", source: "AuthService"))
        
        let authLogs = try await destination.fetch(source: "AuthService")
        #expect(authLogs.count == 2)
        #expect(authLogs.allSatisfy { $0.source == "AuthService" })
    }
    
    @Test("SQLiteDestination fetches by metadata key")
    func fetchesByMetadataKey() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await destination.log(LogMessage(level: .info, message: "With user", metadata: ["userId": "123"], source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Without user", metadata: ["other": "value"], source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Also with user", metadata: ["userId": "456", "extra": "data"], source: "Test"))
        
        let logsWithUserId = try await destination.fetch(metadataKey: "userId")
        #expect(logsWithUserId.count == 2)
        #expect(logsWithUserId.allSatisfy { $0.metadata?["userId"] != nil })
    }
    
    @Test("SQLiteDestination fetches by metadata key-value pair")
    func fetchesByMetadataKeyValue() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await destination.log(LogMessage(level: .info, message: "User 123", metadata: ["userId": "123"], source: "Test"))
        await destination.log(LogMessage(level: .info, message: "User 456", metadata: ["userId": "456"], source: "Test"))
        await destination.log(LogMessage(level: .info, message: "Another 123", metadata: ["userId": "123"], source: "Test"))
        
        let user123Logs = try await destination.fetch(metadataKey: "userId", value: "123")
        #expect(user123Logs.count == 2)
        #expect(user123Logs.allSatisfy { $0.metadata?["userId"] == "123" })
    }
    
    @Test("SQLiteDestination handles concurrent writes")
    func handlesConcurrentWrites() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    let message = LogMessage(level: .info, message: "Concurrent \(i)", source: "Test")
                    await destination.log(message)
                }
            }
        }
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 100)
    }
    
    @Test("SQLiteDestination deletes all logs")
    func deletesAllLogs() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        for i in 0..<5 {
            await destination.log(LogMessage(level: .info, message: "Log \(i)", source: "Test"))
        }
        
        var logs = try await destination.fetchAll()
        #expect(logs.count == 5)
        
        try await destination.deleteAll()
        
        logs = try await destination.fetchAll()
        #expect(logs.count == 0)
    }
    
    @Test("SQLiteDestination deletes logs older than date")
    func deletesLogsOlderThanDate() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let now = Date()
        let hourAgo = now.addingTimeInterval(-3600)
        let twoHoursAgo = now.addingTimeInterval(-7200)
        
        await destination.log(LogMessage(level: .info, message: "Old", source: "Test", timestamp: twoHoursAgo))
        await destination.log(LogMessage(level: .info, message: "Recent", source: "Test", timestamp: hourAgo))
        await destination.log(LogMessage(level: .info, message: "Now", source: "Test", timestamp: now))
        
        let ninetyMinutesAgo = now.addingTimeInterval(-5400)
        let deleted = try await destination.delete(olderThan: ninetyMinutesAgo)
        #expect(deleted == 1)
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 2)
        #expect(!logs.contains { $0.message == "Old" })
    }
    
    @Test("SQLiteDestination returns log count")
    func returnsLogCount() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        #expect(try await destination.count() == 0)
        
        for i in 0..<10 {
            await destination.log(LogMessage(level: .info, message: "Log \(i)", source: "Test"))
        }
        
        #expect(try await destination.count() == 10)
    }
    
    @Test("SQLiteDestination persists to file")
    func persistsToFile() async throws {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SQLiteDestinationTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true)
        let dbPath = testDir.appendingPathComponent("test.db").path
        
        let destination1 = try SQLiteDestination(databasePath: dbPath)
        await destination1.log(LogMessage(level: .info, message: "Persistent", source: "Test"))
        await destination1.close()
        
        let destination2 = try SQLiteDestination(databasePath: dbPath)
        let logs = try await destination2.fetchAll()
        #expect(logs.count == 1)
        #expect(logs[0].message == "Persistent")
        
        try? FileManager.default.removeItem(at: testDir)
    }
    
    @Test("SQLiteDestination returns logs ordered by timestamp")
    func returnsLogsOrderedByTimestamp() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        let now = Date()
        let times = [
            now.addingTimeInterval(-100),
            now.addingTimeInterval(-50),
            now,
            now.addingTimeInterval(-200),
            now.addingTimeInterval(-25)
        ]
        
        for (i, time) in times.enumerated() {
            await destination.log(LogMessage(level: .info, message: "Log \(i)", source: "Test", timestamp: time))
        }
        
        let logs = try await destination.fetchAll()
        #expect(logs.count == 5)
        
        for i in 0..<(logs.count - 1) {
            #expect(logs[i].timestamp >= logs[i + 1].timestamp)
        }
    }
    
    @Test("SQLiteDestination supports pagination")
    func supportsPagination() async throws {
        let destination = try SQLiteDestination(databasePath: ":memory:")
        
        for i in 0..<20 {
            await destination.log(LogMessage(level: .info, message: "Log \(i)", source: "Test"))
        }
        
        let page1 = try await destination.fetchAll(limit: 5, offset: 0)
        #expect(page1.count == 5)
        
        let page2 = try await destination.fetchAll(limit: 5, offset: 5)
        #expect(page2.count == 5)
        
        let page1Messages = Set(page1.map { $0.message })
        let page2Messages = Set(page2.map { $0.message })
        #expect(page1Messages.isDisjoint(with: page2Messages))
    }
}
