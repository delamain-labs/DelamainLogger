import Testing
import Foundation
@testable import DelamainLogger

@Suite("ConsoleDestination Tests")
struct ConsoleDestinationTests {
    
    @Test("ConsoleDestination formats messages correctly")
    func formatsMessagesCorrectly() async {
        let destination = ConsoleDestination()
        
        let message = LogMessage(
            level: .info,
            message: "Test message",
            metadata: nil,
            source: "TestSource",
            file: "Test.swift",
            function: "test()",
            line: 10
        )
        
        let formatted = await destination.format(message)
        
        #expect(formatted.contains("INFO"))
        #expect(formatted.contains("Test message"))
        #expect(formatted.contains("TestSource"))
    }
    
    @Test("ConsoleDestination includes metadata when present")
    func includesMetadata() async {
        let destination = ConsoleDestination()
        
        let message = LogMessage(
            level: .debug,
            message: "With metadata",
            metadata: ["key": "value"],
            source: "Test"
        )
        
        let formatted = await destination.format(message)
        
        #expect(formatted.contains("key"))
        #expect(formatted.contains("value"))
    }
    
    @Test("ConsoleDestination supports different formats")
    func supportsDifferentFormats() async {
        let compactDestination = ConsoleDestination(format: .compact)
        let verboseDestination = ConsoleDestination(format: .verbose)
        let jsonDestination = ConsoleDestination(format: .json)
        
        let message = LogMessage(
            level: .info,
            message: "Format test",
            source: "Test"
        )
        
        let compact = await compactDestination.format(message)
        let verbose = await verboseDestination.format(message)
        let json = await jsonDestination.format(message)
        
        // JSON should be parseable
        #expect(json.contains("{"))
        #expect(json.contains("}"))
        
        // Verbose should include file/line info
        #expect(verbose.count >= compact.count)
    }
    
    @Test("ConsoleDestination supports color output")
    func supportsColorOutput() async {
        let coloredDestination = ConsoleDestination(useColors: true)
        
        let errorMessage = LogMessage(
            level: .error,
            message: "Error test",
            source: "Test"
        )
        
        let formatted = await coloredDestination.format(errorMessage)
        
        // ANSI color codes start with escape sequence
        #expect(formatted.contains("\u{001B}[") || !coloredDestination.useColors)
    }
    
    @Test("ConsoleDestination respects minimum level")
    func respectsMinimumLevel() async {
        let destination = ConsoleDestination(minimumLevel: .warning)
        
        #expect(await destination.shouldLog(level: .debug) == false)
        #expect(await destination.shouldLog(level: .info) == false)
        #expect(await destination.shouldLog(level: .warning) == true)
        #expect(await destination.shouldLog(level: .error) == true)
    }
}
