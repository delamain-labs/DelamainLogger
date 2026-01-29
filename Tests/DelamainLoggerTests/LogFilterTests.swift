import Testing
import Foundation
@testable import DelamainLogger

@Suite("LogFilter Tests")
struct LogFilterTests {

    // MARK: - Helper

    private func makeMessage(
        level: LogLevel = .info,
        message: String = "Test message",
        metadata: LogMetadata? = nil,
        source: String = "TestSource"
    ) -> LogMessage {
        LogMessage(
            level: level,
            message: message,
            metadata: metadata,
            source: source
        )
    }

    // MARK: - LevelFilter Tests

    @Test("LevelFilter passes messages at or above minimum level")
    func levelFilterPasses() {
        let filter = LevelFilter(minimumLevel: .warning)

        #expect(filter.shouldLog(makeMessage(level: .warning)) == true)
        #expect(filter.shouldLog(makeMessage(level: .error)) == true)
        #expect(filter.shouldLog(makeMessage(level: .critical)) == true)
    }

    @Test("LevelFilter blocks messages below minimum level")
    func levelFilterBlocks() {
        let filter = LevelFilter(minimumLevel: .warning)

        #expect(filter.shouldLog(makeMessage(level: .trace)) == false)
        #expect(filter.shouldLog(makeMessage(level: .debug)) == false)
        #expect(filter.shouldLog(makeMessage(level: .info)) == false)
    }

    // MARK: - SourceFilter Tests

    @Test("SourceFilter includes matching sources")
    func sourceFilterIncludes() {
        let filter = SourceFilter.include("Networking", "Database")

        #expect(filter.shouldLog(makeMessage(source: "Networking")) == true)
        #expect(filter.shouldLog(makeMessage(source: "Database")) == true)
        #expect(filter.shouldLog(makeMessage(source: "UI")) == false)
    }

    @Test("SourceFilter excludes matching sources")
    func sourceFilterExcludes() {
        let filter = SourceFilter.exclude("Verbose", "Debug")

        #expect(filter.shouldLog(makeMessage(source: "Verbose")) == false)
        #expect(filter.shouldLog(makeMessage(source: "Debug")) == false)
        #expect(filter.shouldLog(makeMessage(source: "Important")) == true)
    }

    // MARK: - MessageFilter Tests

    @Test("MessageFilter contains substring")
    func messageFilterContains() {
        let filter = MessageFilter.contains("error")

        #expect(filter.shouldLog(makeMessage(message: "An error occurred")) == true)
        #expect(filter.shouldLog(makeMessage(message: "Success")) == false)
    }

    @Test("MessageFilter case insensitive")
    func messageFilterCaseInsensitive() {
        let filter = MessageFilter.contains("ERROR", caseSensitive: false)

        #expect(filter.shouldLog(makeMessage(message: "An error occurred")) == true)
        #expect(filter.shouldLog(makeMessage(message: "ERROR: failed")) == true)
    }

    @Test("MessageFilter regex pattern")
    func messageFilterRegex() {
        let filter = MessageFilter.matches(pattern: "user_\\d+")

        #expect(filter.shouldLog(makeMessage(message: "Login for user_123")) == true)
        #expect(filter.shouldLog(makeMessage(message: "Login for admin")) == false)
    }

    // MARK: - MetadataFilter Tests

    @Test("MetadataFilter hasKey")
    func metadataFilterHasKey() {
        let filter = MetadataFilter.hasKey("userId")

        #expect(filter.shouldLog(makeMessage(metadata: ["userId": "123"])) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["other": "value"])) == false)
        #expect(filter.shouldLog(makeMessage(metadata: nil)) == false)
    }

    @Test("MetadataFilter equals")
    func metadataFilterEquals() {
        let filter = MetadataFilter.equals(key: "status", value: .int(200))

        #expect(filter.shouldLog(makeMessage(metadata: ["status": 200])) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["status": 404])) == false)
        #expect(filter.shouldLog(makeMessage(metadata: ["status": "200"])) == false)
    }

    @Test("MetadataFilter hasAnyKey")
    func metadataFilterHasAnyKey() {
        let filter = MetadataFilter.hasAnyKey("error", "warning")

        #expect(filter.shouldLog(makeMessage(metadata: ["error": "failed"])) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["warning": "slow"])) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["info": "ok"])) == false)
    }

    @Test("MetadataFilter hasAllKeys")
    func metadataFilterHasAllKeys() {
        let filter = MetadataFilter.hasAllKeys("userId", "sessionId")

        #expect(filter.shouldLog(makeMessage(metadata: ["userId": "1", "sessionId": "abc"])) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["userId": "1"])) == false)
        #expect(filter.shouldLog(makeMessage(metadata: nil)) == false)
    }

    // MARK: - Combinator Tests

    @Test("AllOfFilter requires all filters to pass")
    func allOfFilter() {
        let filter = AllOfFilter([
            LevelFilter(minimumLevel: .warning),
            SourceFilter.include("Critical")
        ])

        #expect(filter.shouldLog(makeMessage(level: .error, source: "Critical")) == true)
        #expect(filter.shouldLog(makeMessage(level: .info, source: "Critical")) == false)
        #expect(filter.shouldLog(makeMessage(level: .error, source: "Other")) == false)
    }

    @Test("AnyOfFilter passes if any filter passes")
    func anyOfFilter() {
        let filter = AnyOfFilter([
            LevelFilter(minimumLevel: .error),
            MetadataFilter.hasKey("important")
        ])

        #expect(filter.shouldLog(makeMessage(level: .error)) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["important": true])) == true)
        #expect(filter.shouldLog(makeMessage(level: .info)) == false)
    }

    @Test("NotFilter inverts result")
    func notFilter() {
        let filter = NotFilter(SourceFilter.include("Debug"))

        #expect(filter.shouldLog(makeMessage(source: "Debug")) == false)
        #expect(filter.shouldLog(makeMessage(source: "Production")) == true)
    }

    // MARK: - Operator Extensions

    @Test("Filter and operator")
    func filterAndOperator() {
        let filter = LevelFilter(minimumLevel: .warning).and(SourceFilter.include("API"))

        #expect(filter.shouldLog(makeMessage(level: .error, source: "API")) == true)
        #expect(filter.shouldLog(makeMessage(level: .info, source: "API")) == false)
    }

    @Test("Filter or operator")
    func filterOrOperator() {
        let filter = LevelFilter(minimumLevel: .error).or(MetadataFilter.hasKey("alert"))

        #expect(filter.shouldLog(makeMessage(level: .error)) == true)
        #expect(filter.shouldLog(makeMessage(metadata: ["alert": true])) == true)
        #expect(filter.shouldLog(makeMessage(level: .info)) == false)
    }

    @Test("Filter not property")
    func filterNotProperty() {
        let filter = SourceFilter.include("Verbose").not

        #expect(filter.shouldLog(makeMessage(source: "Verbose")) == false)
        #expect(filter.shouldLog(makeMessage(source: "Other")) == true)
    }

    // MARK: - Pass/Block Filters

    @Test("PassFilter always passes")
    func passFilter() {
        let filter = PassFilter()

        #expect(filter.shouldLog(makeMessage()) == true)
        #expect(filter.shouldLog(makeMessage(level: .trace)) == true)
    }

    @Test("BlockFilter always blocks")
    func blockFilter() {
        let filter = BlockFilter()

        #expect(filter.shouldLog(makeMessage()) == false)
        #expect(filter.shouldLog(makeMessage(level: .critical)) == false)
    }
}

// MARK: - Integration Tests

@Suite("LogFilter Integration Tests")
struct LogFilterIntegrationTests {

    actor MockFilterDestination: LogDestination {
        private(set) var messages: [LogMessage] = []
        nonisolated let minimumLevel: LogLevel
        let filter: (any LogFilter)?

        init(minimumLevel: LogLevel = .trace, filter: (any LogFilter)? = nil) {
            self.minimumLevel = minimumLevel
            self.filter = filter
        }

        func log(_ message: LogMessage) async {
            messages.append(message)
        }

        func getMessages() -> [LogMessage] {
            messages
        }
    }

    @Test("Logger global filter blocks messages")
    func loggerGlobalFilter() async {
        let destination = MockFilterDestination()
        let logger = Logger(subsystem: "test", category: "filter")
        await logger.addDestination(destination)
        await logger.setFilter(LevelFilter(minimumLevel: .warning))

        await logger.info("Should be filtered")
        await logger.warning("Should pass")
        await logger.error("Should pass")

        let messages = await destination.getMessages()
        #expect(messages.count == 2)
        #expect(messages[0].level == .warning)
        #expect(messages[1].level == .error)
    }

    @Test("Destination filter blocks messages")
    func destinationFilter() async {
        let destination = MockFilterDestination(
            filter: MetadataFilter.hasKey("important")
        )
        let logger = Logger(subsystem: "test", category: "filter")
        await logger.addDestination(destination)

        await logger.info("No metadata")
        await logger.info("With important", metadata: ["important": true])
        await logger.info("Other metadata", metadata: ["other": "value"])

        let messages = await destination.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].metadata?["important"] == .bool(true))
    }

    @Test("Global and destination filters combine")
    func combinedFilters() async {
        let destination = MockFilterDestination(
            filter: SourceFilter.include("test.allowed")
        )
        let logger = Logger(subsystem: "test", category: "allowed")
        await logger.addDestination(destination)
        await logger.setFilter(LevelFilter(minimumLevel: .info))

        await logger.debug("Blocked by global")
        await logger.info("Should pass")

        let messages = await destination.getMessages()
        #expect(messages.count == 1)
    }
}
