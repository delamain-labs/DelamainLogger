import Testing
@testable import DelamainLogger

@Suite("LogLevel Tests")
struct LogLevelTests {
    
    @Test("All log levels exist")
    func allLevelsExist() {
        let levels: [LogLevel] = [.trace, .debug, .info, .warning, .error, .critical]
        #expect(levels.count == 6)
    }
    
    @Test("Log levels have correct severity ordering")
    func severityOrdering() {
        #expect(LogLevel.trace < LogLevel.debug)
        #expect(LogLevel.debug < LogLevel.info)
        #expect(LogLevel.info < LogLevel.warning)
        #expect(LogLevel.warning < LogLevel.error)
        #expect(LogLevel.error < LogLevel.critical)
    }
    
    @Test("Log levels have display names")
    func displayNames() {
        #expect(LogLevel.trace.description == "TRACE")
        #expect(LogLevel.debug.description == "DEBUG")
        #expect(LogLevel.info.description == "INFO")
        #expect(LogLevel.warning.description == "WARNING")
        #expect(LogLevel.error.description == "ERROR")
        #expect(LogLevel.critical.description == "CRITICAL")
    }
    
    @Test("Log levels have emoji representations")
    func emojiRepresentations() {
        #expect(LogLevel.trace.emoji == "🔍")
        #expect(LogLevel.debug.emoji == "🐛")
        #expect(LogLevel.info.emoji == "ℹ️")
        #expect(LogLevel.warning.emoji == "⚠️")
        #expect(LogLevel.error.emoji == "❌")
        #expect(LogLevel.critical.emoji == "🔥")
    }
}
