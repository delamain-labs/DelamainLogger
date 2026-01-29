import Testing
import Foundation
@testable import DelamainLogger

@Suite("LogMetrics Tests", .serialized)
struct LogMetricsTests {

    @Test("Metrics records messages")
    func recordsMessages() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        await metrics.recordMessage(level: .info, latencyMs: 1.0)
        await metrics.recordMessage(level: .error, latencyMs: 2.0)

        let snapshot = await metrics.snapshot()
        #expect(snapshot.totalMessages == 2)
    }

    @Test("Metrics tracks by level")
    func tracksByLevel() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        await metrics.recordMessage(level: .info, latencyMs: 1.0)
        await metrics.recordMessage(level: .info, latencyMs: 1.0)
        await metrics.recordMessage(level: .error, latencyMs: 1.0)

        let snapshot = await metrics.snapshot()
        #expect(snapshot.byLevel[.info] == 2)
        #expect(snapshot.byLevel[.error] == 1)
        #expect(snapshot.byLevel[.debug] == nil)
    }

    @Test("Metrics calculates average latency")
    func calculatesAverageLatency() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        await metrics.recordMessage(level: .info, latencyMs: 1.0)
        await metrics.recordMessage(level: .info, latencyMs: 3.0)

        let snapshot = await metrics.snapshot()
        #expect(snapshot.averageLatencyMs == 2.0)
    }

    @Test("Metrics tracks dropped messages")
    func tracksDropped() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        await metrics.recordDropped()
        await metrics.recordDropped()

        let snapshot = await metrics.snapshot()
        #expect(snapshot.droppedMessages == 2)
    }

    @Test("Metrics calculates messages per second")
    func calculatesMessagesPerSecond() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        // Log 10 messages
        for _ in 0..<10 {
            await metrics.recordMessage(level: .info, latencyMs: 0.1)
        }

        let snapshot = await metrics.snapshot()
        // Should be roughly 10 messages in very short time
        #expect(snapshot.messagesPerSecond > 0)
    }

    @Test("Metrics reset clears all data")
    func resetClearsData() async {
        let metrics = LogMetrics.shared
        await metrics.recordMessage(level: .info, latencyMs: 1.0)
        await metrics.recordDropped()

        await metrics.reset()

        let snapshot = await metrics.snapshot()
        #expect(snapshot.totalMessages == 0)
        #expect(snapshot.droppedMessages == 0)
        #expect(snapshot.byLevel.isEmpty)
    }

    @Test("Metrics snapshot has timestamp")
    func snapshotHasTimestamp() async {
        let before = Date()
        let metrics = LogMetrics.shared
        await metrics.reset()

        let snapshot = await metrics.snapshot()
        let after = Date()

        #expect(snapshot.timestamp >= before)
        #expect(snapshot.timestamp <= after)
    }

    @Test("Metrics snapshot has uptime")
    func snapshotHasUptime() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        let snapshot = await metrics.snapshot()
        #expect(snapshot.uptimeSeconds >= 0)
    }

    @Test("Metrics snapshot accepts buffered count")
    func snapshotAcceptsBufferedCount() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        let snapshot = await metrics.snapshot(bufferedCount: 42)
        #expect(snapshot.bufferedMessages == 42)
    }

    @Test("Metrics snapshot is CustomStringConvertible")
    func snapshotIsDescribable() async {
        let metrics = LogMetrics.shared
        await metrics.reset()

        await metrics.recordMessage(level: .info, latencyMs: 1.0)

        let snapshot = await metrics.snapshot()
        let description = snapshot.description

        #expect(description.contains("Log Metrics"))
        #expect(description.contains("Total Messages"))
    }
}
