import Foundation

/// Performance metrics for logging operations.
public struct LogMetricsSnapshot: Sendable {
    /// Total number of messages logged since start.
    public let totalMessages: Int

    /// Messages logged per second (rolling average).
    public let messagesPerSecond: Double

    /// Average time to process a log message in milliseconds.
    public let averageLatencyMs: Double

    /// Number of messages currently buffered (across all destinations).
    public let bufferedMessages: Int

    /// Number of messages dropped due to errors.
    public let droppedMessages: Int

    /// Breakdown by log level.
    public let byLevel: [LogLevel: Int]

    /// Uptime since metrics collection started.
    public let uptimeSeconds: TimeInterval

    /// Timestamp of this snapshot.
    public let timestamp: Date
}

/// Collects and reports logging performance metrics.
public actor LogMetrics {
    /// Shared metrics instance.
    public static let shared = LogMetrics()

    private var totalMessages: Int = 0
    private var droppedMessages: Int = 0
    private var byLevel: [LogLevel: Int] = [:]

    private var latencySum: Double = 0
    private var latencyCount: Int = 0

    private var recentMessages: [Date] = []
    private let recentWindow: TimeInterval = 60 // 1 minute rolling window

    private let startTime: Date = Date()

    private init() {}

    // MARK: - Recording

    /// Records a logged message.
    /// - Parameters:
    ///   - level: The log level.
    ///   - latencyMs: Time taken to process the message in milliseconds.
    public func recordMessage(level: LogLevel, latencyMs: Double) {
        totalMessages += 1
        byLevel[level, default: 0] += 1

        latencySum += latencyMs
        latencyCount += 1

        let now = Date()
        recentMessages.append(now)

        // Prune old messages outside the window
        let cutoff = now.addingTimeInterval(-recentWindow)
        recentMessages.removeAll { $0 < cutoff }
    }

    /// Records a dropped message.
    public func recordDropped() {
        droppedMessages += 1
    }

    // MARK: - Reporting

    /// Gets a snapshot of current metrics.
    /// - Parameter bufferedCount: Current buffered message count from destinations.
    /// - Returns: A metrics snapshot.
    public func snapshot(bufferedCount: Int = 0) -> LogMetricsSnapshot {
        let now = Date()
        let uptime = now.timeIntervalSince(startTime)

        // Calculate messages per second from recent window
        let cutoff = now.addingTimeInterval(-recentWindow)
        let recentCount = recentMessages.filter { $0 >= cutoff }.count
        let windowSeconds = min(uptime, recentWindow)
        let mps = windowSeconds > 0 ? Double(recentCount) / windowSeconds : 0

        // Average latency
        let avgLatency = latencyCount > 0 ? latencySum / Double(latencyCount) : 0

        return LogMetricsSnapshot(
            totalMessages: totalMessages,
            messagesPerSecond: mps,
            averageLatencyMs: avgLatency,
            bufferedMessages: bufferedCount,
            droppedMessages: droppedMessages,
            byLevel: byLevel,
            uptimeSeconds: uptime,
            timestamp: now
        )
    }

    /// Resets all metrics.
    public func reset() {
        totalMessages = 0
        droppedMessages = 0
        byLevel = [:]
        latencySum = 0
        latencyCount = 0
        recentMessages = []
    }
}

// MARK: - Logger Integration

extension Logger {
    /// Gets a metrics snapshot from the shared metrics collector.
    public func metricsSnapshot() async -> LogMetricsSnapshot {
        await LogMetrics.shared.snapshot()
    }
}

// MARK: - CustomStringConvertible

extension LogMetricsSnapshot: CustomStringConvertible {
    public var description: String {
        var lines: [String] = []
        lines.append("=== Log Metrics ===")
        lines.append("Uptime: \(String(format: "%.1f", uptimeSeconds))s")
        lines.append("Total Messages: \(totalMessages)")
        lines.append("Messages/sec: \(String(format: "%.2f", messagesPerSecond))")
        lines.append("Avg Latency: \(String(format: "%.3f", averageLatencyMs))ms")
        lines.append("Buffered: \(bufferedMessages)")
        lines.append("Dropped: \(droppedMessages)")

        if !byLevel.isEmpty {
            lines.append("By Level:")
            for level in LogLevel.allCases {
                if let count = byLevel[level], count > 0 {
                    lines.append("  \(level): \(count)")
                }
            }
        }

        return lines.joined(separator: "\n")
    }
}
