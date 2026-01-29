import Foundation

/// Configuration for log aggregation behavior.
public struct AggregationConfig: Sendable {
    /// Time window for grouping similar messages.
    public let windowSeconds: TimeInterval

    /// Maximum number of unique messages to track.
    public let maxTrackedMessages: Int

    /// Minimum count before aggregating (1 = aggregate immediately on repeat).
    public let minCountToAggregate: Int

    /// Creates aggregation configuration.
    public init(
        windowSeconds: TimeInterval = 60,
        maxTrackedMessages: Int = 1000,
        minCountToAggregate: Int = 2
    ) {
        self.windowSeconds = windowSeconds
        self.maxTrackedMessages = maxTrackedMessages
        self.minCountToAggregate = minCountToAggregate
    }

    /// Default configuration.
    public static let `default` = AggregationConfig()

    /// Aggressive aggregation for high-volume scenarios.
    public static let aggressive = AggregationConfig(
        windowSeconds: 30,
        maxTrackedMessages: 500,
        minCountToAggregate: 1
    )
}

/// A destination that aggregates repeated log messages.
///
/// When the same message is logged multiple times within a time window,
/// it outputs a single aggregated message with the count.
public actor AggregatingDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel

    private let wrapped: any LogDestination
    private let config: AggregationConfig

    private var messageTracker: [String: TrackedMessage] = [:]
    private var flushTask: Task<Void, Never>?
    private var isFlushTaskStarted: Bool = false
    private var isClosed: Bool = false

    /// Creates an aggregating destination.
    /// - Parameters:
    ///   - destination: The destination to wrap.
    ///   - config: Aggregation configuration.
    public init(
        wrapping destination: any LogDestination,
        config: AggregationConfig = .default
    ) {
        self.wrapped = destination
        self.minimumLevel = destination.minimumLevel
        self.config = config
    }

    public func log(_ message: LogMessage) async {
        guard !isClosed else { return }

        // Start periodic flush on first log
        if !isFlushTaskStarted {
            isFlushTaskStarted = true
            flushTask = Task { [weak self] in
                await self?.runPeriodicFlush()
            }
        }

        let key = makeKey(for: message)
        let now = Date()

        if var tracked = messageTracker[key] {
            // Update existing tracked message
            tracked.count += 1
            tracked.lastSeen = now

            // Update metadata with latest values
            if let metadata = message.metadata {
                for (k, v) in metadata {
                    tracked.latestMetadata[k] = v
                }
            }

            messageTracker[key] = tracked
        } else {
            // New message, track it
            messageTracker[key] = TrackedMessage(
                original: message,
                count: 1,
                firstSeen: now,
                lastSeen: now,
                latestMetadata: message.metadata ?? [:]
            )

            // Evict oldest if over limit
            if messageTracker.count > config.maxTrackedMessages {
                evictOldest()
            }
        }
    }

    /// Flushes all tracked messages to the wrapped destination.
    public func flush() async {
        let now = Date()
        let cutoff = now.addingTimeInterval(-config.windowSeconds)

        // Collect messages to flush
        var toFlush: [TrackedMessage] = []

        for (key, tracked) in messageTracker {
            // Flush if window expired
            if tracked.firstSeen < cutoff {
                toFlush.append(tracked)
                messageTracker.removeValue(forKey: key)
            }
        }

        // Output aggregated messages
        for tracked in toFlush {
            await outputAggregated(tracked)
        }
    }

    /// Closes the destination, flushing all remaining messages.
    public func close() async {
        isClosed = true
        flushTask?.cancel()

        // Flush all remaining tracked messages
        for tracked in messageTracker.values {
            await outputAggregated(tracked)
        }
        messageTracker.removeAll()
    }

    // MARK: - Private

    private func makeKey(for message: LogMessage) -> String {
        // Key based on level, source, and message text
        "\(message.level.rawValue):\(message.source):\(message.message)"
    }

    private func evictOldest() {
        guard let oldest = messageTracker.min(by: { $0.value.firstSeen < $1.value.firstSeen }) else {
            return
        }
        messageTracker.removeValue(forKey: oldest.key)
    }

    private func outputAggregated(_ tracked: TrackedMessage) async {
        if tracked.count >= config.minCountToAggregate && tracked.count > 1 {
            // Create aggregated message
            let aggregatedMessage = createAggregatedMessage(from: tracked)
            await wrapped.log(aggregatedMessage)
        } else {
            // Output original message
            await wrapped.log(tracked.original)
        }
    }

    private func createAggregatedMessage(from tracked: TrackedMessage) -> LogMessage {
        var metadata = tracked.latestMetadata
        metadata["_aggregated_count"] = .int(tracked.count)
        metadata["_aggregated_first"] = .string(ISO8601DateFormatter().string(from: tracked.firstSeen))
        metadata["_aggregated_last"] = .string(ISO8601DateFormatter().string(from: tracked.lastSeen))

        return LogMessage(
            level: tracked.original.level,
            message: "[\(tracked.count)x] \(tracked.original.message)",
            metadata: metadata,
            source: tracked.original.source,
            file: tracked.original.file,
            function: tracked.original.function,
            line: tracked.original.line,
            timestamp: tracked.lastSeen
        )
    }

    private func runPeriodicFlush() async {
        while !Task.isCancelled && !isClosed {
            try? await Task.sleep(for: .seconds(10))

            guard !Task.isCancelled && !isClosed else { break }

            await flush()
        }
    }
}

// MARK: - Tracked Message

private struct TrackedMessage {
    let original: LogMessage
    var count: Int
    let firstSeen: Date
    var lastSeen: Date
    var latestMetadata: LogMetadata
}

// MARK: - Logger Extension

extension Logger {
    /// Adds a destination with log aggregation.
    /// - Parameters:
    ///   - destination: The destination to wrap.
    ///   - config: Aggregation configuration.
    public func addAggregatingDestination(
        _ destination: any LogDestination,
        config: AggregationConfig = .default
    ) async {
        let aggregating = AggregatingDestination(wrapping: destination, config: config)
        await addDestination(aggregating)
    }
}
