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
        #expect(message.metadata?["key"] == .string("value"))
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

    @Test("LogMessage with rich metadata types")
    func richMetadataTypes() {
        let message = LogMessage(
            level: .info,
            message: "Rich metadata",
            metadata: [
                "string": "value",
                "int": 42,
                "bool": true,
                "nested": ["inner": "data"]
            ],
            source: "Test"
        )

        #expect(message.metadata?["string"] == .string("value"))
        #expect(message.metadata?["int"] == .int(42))
        #expect(message.metadata?["bool"] == .bool(true))

        if case .dictionary(let nested) = message.metadata?["nested"] {
            #expect(nested["inner"] == .string("data"))
        } else {
            Issue.record("Expected nested dictionary")
        }
    }

    @Test("LogMessage string metadata convenience initializer")
    func stringMetadataConvenience() {
        let message = LogMessage(
            level: .info,
            message: "String metadata",
            stringMetadata: ["key": "value"],
            source: "Test"
        )

        #expect(message.metadata?["key"] == .string("value"))
    }

    @Test("LogMessage formatted metadata")
    func formattedMetadata() {
        let message = LogMessage(
            level: .info,
            message: "Test",
            metadata: ["a": "1", "b": "2"],
            source: "Test"
        )

        let formatted = message.formattedMetadata()
        #expect(formatted != nil)
        #expect(formatted?.contains("a=1") == true)
        #expect(formatted?.contains("b=2") == true)
    }

    @Test("LogMessage JSON metadata")
    func jsonMetadata() {
        let message = LogMessage(
            level: .info,
            message: "Test",
            metadata: ["key": "value"],
            source: "Test"
        )

        let json = message.jsonMetadata()
        #expect(json != nil)
        #expect(json?.contains("\"key\"") == true)
        #expect(json?.contains("\"value\"") == true)
    }

    @Test("LogMessage nil metadata returns nil formatted")
    func nilMetadataReturnsNil() {
        let message = LogMessage(
            level: .info,
            message: "Test",
            source: "Test"
        )

        #expect(message.formattedMetadata() == nil)
        #expect(message.jsonMetadata() == nil)
    }
}
