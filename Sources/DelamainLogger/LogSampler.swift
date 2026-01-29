import Foundation

/// Sampling strategy for log messages.
public enum SamplingStrategy: Sendable {
    /// Sample at a fixed rate (0.0 to 1.0).
    /// - Parameter rate: Probability of logging (0.1 = 10% of messages).
    case rate(Double)

    /// Sample 1 in N messages.
    /// - Parameter n: Log every Nth message.
    case oneInN(Int)

    /// Sample based on log level.
    /// - Parameter rates: Rate for each level (missing levels default to 1.0).
    case byLevel([LogLevel: Double])

    /// Always log (no sampling).
    case none
}

/// A filter that probabilistically samples log messages.
///
/// Useful for high-volume logging scenarios where you want to reduce
/// log output while maintaining statistical representation.
public struct SamplingFilter: LogFilter, @unchecked Sendable {
    private let strategy: SamplingStrategy
    private let counter: Counter
    private let alwaysLogLevels: Set<LogLevel>

    /// Creates a sampling filter.
    /// - Parameters:
    ///   - strategy: The sampling strategy to use.
    ///   - alwaysLogLevels: Levels that bypass sampling (default: error, critical).
    public init(
        strategy: SamplingStrategy,
        alwaysLogLevels: Set<LogLevel> = [.error, .critical]
    ) {
        self.strategy = strategy
        self.alwaysLogLevels = alwaysLogLevels
        self.counter = Counter()
    }

    public func shouldLog(_ message: LogMessage) -> Bool {
        // Always log high-severity messages
        if alwaysLogLevels.contains(message.level) {
            return true
        }

        switch strategy {
        case .rate(let rate):
            return shouldSampleAtRate(rate)

        case .oneInN(let n):
            return shouldSampleOneInN(n)

        case .byLevel(let rates):
            let rate = rates[message.level] ?? 1.0
            return shouldSampleAtRate(rate)

        case .none:
            return true
        }
    }

    private func shouldSampleAtRate(_ rate: Double) -> Bool {
        guard rate < 1.0 else { return true }
        guard rate > 0.0 else { return false }
        return Double.random(in: 0..<1) < rate
    }

    private func shouldSampleOneInN(_ n: Int) -> Bool {
        guard n > 1 else { return true }
        let count = counter.increment()
        return count % n == 0
    }
}

// MARK: - Thread-safe Counter

private final class Counter: @unchecked Sendable {
    private var value: Int = 0
    private let lock = NSLock()

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

// MARK: - Convenience Constructors

extension SamplingFilter {
    /// Creates a filter that logs approximately the given percentage of messages.
    /// - Parameter percent: Percentage to log (1-100).
    public static func percent(_ percent: Int) -> SamplingFilter {
        SamplingFilter(strategy: .rate(Double(max(0, min(100, percent))) / 100.0))
    }

    /// Creates a filter that logs 1 in every N messages.
    /// - Parameter n: Log every Nth message.
    public static func oneIn(_ n: Int) -> SamplingFilter {
        SamplingFilter(strategy: .oneInN(max(1, n)))
    }

    /// Creates a filter with different rates per log level.
    /// - Parameter rates: Dictionary of level to sample rate.
    public static func byLevel(_ rates: [LogLevel: Double]) -> SamplingFilter {
        SamplingFilter(strategy: .byLevel(rates))
    }

    /// Creates a filter optimized for production.
    /// - trace/debug: 1%
    /// - info: 10%
    /// - warning: 50%
    /// - error/critical: 100%
    public static var production: SamplingFilter {
        SamplingFilter(strategy: .byLevel([
            .trace: 0.01,
            .debug: 0.01,
            .info: 0.10,
            .warning: 0.50
        ]))
    }

    /// Creates a filter optimized for development (no sampling).
    public static var development: SamplingFilter {
        SamplingFilter(strategy: .none)
    }
}

// MARK: - Sampled Destination Wrapper

/// A destination wrapper that applies sampling before logging.
public actor SampledDestination: LogDestination {
    public nonisolated let minimumLevel: LogLevel

    private let wrapped: any LogDestination
    private let sampler: SamplingFilter

    /// Creates a sampled destination.
    /// - Parameters:
    ///   - destination: The destination to wrap.
    ///   - sampler: The sampling filter to apply.
    public init(
        wrapping destination: any LogDestination,
        sampler: SamplingFilter
    ) {
        self.wrapped = destination
        self.minimumLevel = destination.minimumLevel
        self.sampler = sampler
    }

    public func log(_ message: LogMessage) async {
        guard sampler.shouldLog(message) else { return }
        await wrapped.log(message)
    }
}

// MARK: - Logger Extension

extension Logger {
    /// Adds a destination with sampling applied.
    /// - Parameters:
    ///   - destination: The destination to add.
    ///   - sampler: The sampling filter to use.
    public func addSampledDestination(
        _ destination: any LogDestination,
        sampler: SamplingFilter
    ) async {
        let sampled = SampledDestination(wrapping: destination, sampler: sampler)
        await addDestination(sampled)
    }
}
