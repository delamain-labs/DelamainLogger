import Testing
import Foundation
@testable import DelamainLogger

/// Mock destination for testing aggregation
actor MockAggregationDestination: LogDestination {
    nonisolated let minimumLevel: LogLevel = .trace
    private(set) var messages: [LogMessage] = []

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

@Suite("LogAggregator Tests", .serialized)
struct LogAggregatorTests {

    private func makeMessage(
        level: LogLevel = .info,
        message: String = "Test message",
        source: String = "Test"
    ) -> LogMessage {
        LogMessage(level: level, message: message, source: source)
    }

    // MARK: - Basic Aggregation

    @Test("Aggregates repeated messages")
    func aggregatesRepeatedMessages() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        // Log same message 5 times
        for _ in 0..<5 {
            await aggregator.log(makeMessage(message: "Repeated"))
        }

        // Close to flush
        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].message.contains("[5x]"))
        #expect(messages[0].message.contains("Repeated"))
    }

    @Test("Does not aggregate different messages")
    func doesNotAggregateDifferent() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        await aggregator.log(makeMessage(message: "Message 1"))
        await aggregator.log(makeMessage(message: "Message 2"))
        await aggregator.log(makeMessage(message: "Message 3"))

        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages.count == 3)
    }

    @Test("Respects min count to aggregate")
    func respectsMinCount() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 3)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        // Log twice - below threshold
        await aggregator.log(makeMessage(message: "Twice"))
        await aggregator.log(makeMessage(message: "Twice"))

        // Log thrice - at threshold
        await aggregator.log(makeMessage(message: "Thrice"))
        await aggregator.log(makeMessage(message: "Thrice"))
        await aggregator.log(makeMessage(message: "Thrice"))

        await aggregator.close()

        let messages = await mock.getMessages()

        // "Twice" should not be aggregated (count=2, min=3)
        let twiceMessages = messages.filter { $0.message.contains("Twice") }
        #expect(twiceMessages.count == 1)
        #expect(!twiceMessages[0].message.contains("["))

        // "Thrice" should be aggregated
        let thriceMessages = messages.filter { $0.message.contains("Thrice") }
        #expect(thriceMessages.count == 1)
        #expect(thriceMessages[0].message.contains("[3x]"))
    }

    // MARK: - Key Generation

    @Test("Groups by level, source, and message")
    func groupsByKey() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 1)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        // Same message, different level
        await aggregator.log(makeMessage(level: .info, message: "Same"))
        await aggregator.log(makeMessage(level: .info, message: "Same"))
        await aggregator.log(makeMessage(level: .error, message: "Same"))

        // Same message, different source
        await aggregator.log(makeMessage(message: "Other", source: "Source1"))
        await aggregator.log(makeMessage(message: "Other", source: "Source2"))

        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages.count == 4) // 2 + 1 + 1
    }

    // MARK: - Metadata

    @Test("Includes aggregation metadata")
    func includesAggregationMetadata() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        await aggregator.log(makeMessage(message: "Test"))
        await aggregator.log(makeMessage(message: "Test"))
        await aggregator.log(makeMessage(message: "Test"))

        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages.count == 1)

        let metadata = messages[0].metadata
        #expect(metadata?["_aggregated_count"] == .int(3))
        #expect(metadata?["_aggregated_first"] != nil)
        #expect(metadata?["_aggregated_last"] != nil)
    }

    @Test("Preserves latest metadata from messages")
    func preservesLatestMetadata() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 1, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        await aggregator.log(LogMessage(
            level: .info,
            message: "Test",
            metadata: ["attempt": 1],
            source: "Test"
        ))
        await aggregator.log(LogMessage(
            level: .info,
            message: "Test",
            metadata: ["attempt": 2],
            source: "Test"
        ))

        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages[0].metadata?["attempt"] == .int(2))
    }

    // MARK: - Flush Behavior

    @Test("Flush outputs tracked messages")
    func flushOutputsTracked() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 0.1, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        await aggregator.log(makeMessage(message: "Flush test"))
        await aggregator.log(makeMessage(message: "Flush test"))

        // Wait for window to expire
        try? await Task.sleep(for: .milliseconds(200))

        await aggregator.flush()

        let messages = await mock.getMessages()
        #expect(messages.count == 1)
        #expect(messages[0].message.contains("[2x]"))
    }

    @Test("Close flushes all remaining")
    func closeFlushesAll() async {
        let mock = MockAggregationDestination()
        let config = AggregationConfig(windowSeconds: 60, minCountToAggregate: 2)
        let aggregator = AggregatingDestination(wrapping: mock, config: config)

        await aggregator.log(makeMessage(message: "Still tracked"))
        await aggregator.log(makeMessage(message: "Still tracked"))

        // Messages still in window, close should force flush
        await aggregator.close()

        let messages = await mock.getMessages()
        #expect(messages.count == 1)
    }

    // MARK: - Configuration

    @Test("Default config exists")
    func defaultConfigExists() {
        let config = AggregationConfig.default
        #expect(config.windowSeconds == 60)
        #expect(config.minCountToAggregate == 2)
    }

    @Test("Aggressive config has shorter window")
    func aggressiveConfigExists() {
        let config = AggregationConfig.aggressive
        #expect(config.windowSeconds == 30)
        #expect(config.minCountToAggregate == 1)
    }
}
