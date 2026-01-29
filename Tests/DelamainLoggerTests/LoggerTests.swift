import Testing
import Foundation
@testable import DelamainLogger

/// Mock destination for testing log capture
actor MockDestination: LogDestination {
    private(set) var messages: [LogMessage] = []
    nonisolated let minimumLevel: LogLevel
    
    init(minimumLevel: LogLevel = .trace) {
        self.minimumLevel = minimumLevel
    }
    
    func log(_ message: LogMessage) async {
        messages.append(message)
    }
    
    func getMessages() -> [LogMessage] {
        messages
    }
    
    func clear() {
        messages.removeAll()
    }
}

@Suite("Logger Tests")
struct LoggerTests {
    
    @Test("Logger logs messages at each level")
    func logsAtEachLevel() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.trace("Trace message")
        await logger.debug("Debug message")
        await logger.info("Info message")
        await logger.warning("Warning message")
        await logger.error("Error message")
        await logger.critical("Critical message")
        
        let messages = await destination.getMessages()
        #expect(messages.count == 6)
        #expect(messages[0].level == .trace)
        #expect(messages[1].level == .debug)
        #expect(messages[2].level == .info)
        #expect(messages[3].level == .warning)
        #expect(messages[4].level == .error)
        #expect(messages[5].level == .critical)
    }
    
    @Test("Logger respects minimum log level")
    func respectsMinimumLevel() async {
        let destination = MockDestination(minimumLevel: .warning)
        
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.debug("Should be filtered")
        await logger.info("Should be filtered")
        await logger.warning("Should appear")
        await logger.error("Should appear")
        
        let messages = await destination.getMessages()
        #expect(messages.count == 2)
        #expect(messages[0].level == .warning)
        #expect(messages[1].level == .error)
    }
    
    @Test("Logger includes metadata")
    func includesMetadata() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.info("With metadata", metadata: ["userId": "123", "action": "login"])
        
        let messages = await destination.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].metadata?["userId"] == "123")
        #expect(messages[0].metadata?["action"] == "login")
    }
    
    @Test("Logger captures source location")
    func capturesSourceLocation() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.info("Location test")
        
        let messages = await destination.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].file.contains("LoggerTests.swift"))
        #expect(messages[0].function.contains("capturesSourceLocation"))
        #expect(messages[0].line > 0)
    }
    
    @Test("Logger routes to multiple destinations")
    func routesToMultipleDestinations() async {
        let destination1 = MockDestination()
        let destination2 = MockDestination()
        
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination1)
        await logger.addDestination(destination2)
        
        await logger.info("Multi-destination test")
        
        let messages1 = await destination1.getMessages()
        let messages2 = await destination2.getMessages()
        
        #expect(messages1.count == 1)
        #expect(messages2.count == 1)
        #expect(messages1[0].message == messages2[0].message)
    }
    
    @Test("Logger is thread-safe")
    func isThreadSafe() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        // Log from multiple concurrent tasks
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<100 {
                group.addTask {
                    await logger.info("Concurrent message \(i)")
                }
            }
        }
        
        let messages = await destination.getMessages()
        #expect(messages.count == 100)
    }
    
    @Test("Logger can be disabled")
    func canBeDisabled() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.setEnabled(false)
        await logger.info("Should not appear")
        
        let messages = await destination.getMessages()
        #expect(messages.count == 0)
    }
    
    @Test("Logger can remove destinations")
    func canRemoveDestinations() async {
        let destination = MockDestination()
        let logger = Logger(subsystem: "test", category: "unit")
        await logger.addDestination(destination)
        
        await logger.info("Before removal")
        await logger.removeAllDestinations()
        await logger.info("After removal")
        
        let messages = await destination.getMessages()
        #expect(messages.count == 1)
    }
    
    @Test("Shared logger exists")
    func sharedLoggerExists() async {
        let shared = Logger.shared
        #expect(shared != nil)
    }
}

// MockDestination configured via init

// MARK: - CI Verification Tests

extension LoggerTests {
    func testCIVerification() async {
        // Simple test to verify CI pipeline runs tests
        let logger = Logger()
        XCTAssertNotNil(logger, "Logger should initialize")
    }
    
    func testLogLevelsAreOrdered() {
        // Verify log levels have correct ordering
        XCTAssertTrue(LogLevel.debug.rawValue < LogLevel.info.rawValue)
        XCTAssertTrue(LogLevel.info.rawValue < LogLevel.warning.rawValue)
        XCTAssertTrue(LogLevel.warning.rawValue < LogLevel.error.rawValue)
    }
}
