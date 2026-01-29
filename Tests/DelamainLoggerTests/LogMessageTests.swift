import Testing
import Foundation
@testable import DelamainLogger

@Suite("LogMessage Tests")
struct LogMessageTests {
    
    @Test("LogMessage captures all required fields")
    func capturesRequiredFields() {
        let message = LogMessage(
            level: .info,
            message: "Test message",
            metadata: ["key": "value"],
            source: "TestSource",
            file: "Test.swift",
            function: "testFunction()",
            line: 42
        )
        
        #expect(message.level == .info)
        #expect(message.message == "Test message")
        #expect(message.metadata?["key"] == "value")
        #expect(message.source == "TestSource")
        #expect(message.file == "Test.swift")
        #expect(message.function == "testFunction()")
        #expect(message.line == 42)
    }
    
    @Test("LogMessage has timestamp")
    func hasTimestamp() {
        let before = Date()
        let message = LogMessage(
            level: .debug,
            message: "Test",
            source: "Test"
        )
        let after = Date()
        
        #expect(message.timestamp >= before)
        #expect(message.timestamp <= after)
    }
    
    @Test("LogMessage metadata is optional")
    func metadataIsOptional() {
        let message = LogMessage(
            level: .info,
            message: "No metadata",
            source: "Test"
        )
        
        #expect(message.metadata == nil)
    }
    
    @Test("LogMessage is Sendable")
    func isSendable() async {
        let message = LogMessage(
            level: .info,
            message: "Sendable test",
            metadata: ["concurrent": "safe"],
            source: "Test"
        )
        
        // If this compiles and runs, LogMessage is Sendable
        await Task.detached {
            _ = message.message
        }.value
    }
}
