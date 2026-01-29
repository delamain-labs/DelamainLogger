import Testing
import Foundation
import OSLog
@testable import DelamainLogger

@Suite("OSLogDestination Tests")
struct OSLogDestinationTests {
    
    @Test("OSLogDestination maps log levels correctly")
    func mapsLogLevelsCorrectly() async {
        let destination = OSLogDestination(subsystem: "test", category: "unit")
        
        #expect(destination.osLogType(for: .trace) == .debug)
        #expect(destination.osLogType(for: .debug) == .debug)
        #expect(destination.osLogType(for: .info) == .info)
        #expect(destination.osLogType(for: .warning) == .default)
        #expect(destination.osLogType(for: .error) == .error)
        #expect(destination.osLogType(for: .critical) == .fault)
    }
    
    @Test("OSLogDestination creates valid OSLog instance")
    func createsValidOSLogInstance() async {
        let destination = OSLogDestination(subsystem: "com.delamain.test", category: "unit")
        
        // Should not crash when logging
        let message = LogMessage(
            level: .info,
            message: "OSLog test",
            source: "Test"
        )
        
        await destination.log(message)
        // If we get here without crashing, it works
    }
    
    @Test("OSLogDestination respects minimum level")
    func respectsMinimumLevel() async {
        let destination = OSLogDestination(
            subsystem: "test",
            category: "unit",
            minimumLevel: .error
        )
        
        #expect(await destination.shouldLog(level: .debug) == false)
        #expect(await destination.shouldLog(level: .info) == false)
        #expect(await destination.shouldLog(level: .warning) == false)
        #expect(await destination.shouldLog(level: .error) == true)
        #expect(await destination.shouldLog(level: .critical) == true)
    }
    
    @Test("OSLogDestination includes category in output")
    func includesCategoryInOutput() async {
        let destination = OSLogDestination(
            subsystem: "com.delamain.logger",
            category: "network"
        )
        
        #expect(destination.category == "network")
        #expect(destination.subsystem == "com.delamain.logger")
    }
}
