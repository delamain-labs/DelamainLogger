import Foundation

/// A thread-safe, async-first logger for Swift applications.
///
/// Logger routes messages to multiple destinations (console, file, OSLog, etc.)
/// and supports structured logging with rich metadata types.
///
/// ## Usage
/// ```swift
/// let logger = Logger(subsystem: "com.example", category: "networking")
/// await logger.addDestination(ConsoleDestination())
///
/// // Simple string metadata
/// await logger.info("Request started", metadata: ["url": "/api/users"])
///
/// // Rich typed metadata
/// await logger.error("Request failed", metadata: [
///     "statusCode": 500,
///     "retryCount": 3,
///     "headers": ["content-type": "application/json"]
/// ])
/// ```
public actor Logger {
    /// The shared default logger instance.
    public static let shared = Logger(subsystem: "app", category: "default")

    /// The subsystem identifier (typically reverse-DNS).
    public let subsystem: String

    /// The category within the subsystem.
    public let category: String

    /// Combined source identifier.
    public var source: String { "\(subsystem).\(category)" }

    /// Whether logging is enabled.
    private var isEnabled: Bool = true

    /// Registered log destinations.
    private var destinations: [any LogDestination] = []

    /// Creates a new logger.
    /// - Parameters:
    ///   - subsystem: The subsystem identifier.
    ///   - category: The category within the subsystem.
    public init(subsystem: String, category: String) {
        self.subsystem = subsystem
        self.category = category
    }

    // MARK: - Configuration

    /// Adds a destination to receive log messages.
    /// - Parameter destination: The destination to add.
    public func addDestination(_ destination: any LogDestination) {
        destinations.append(destination)
    }

    /// Removes all registered destinations.
    public func removeAllDestinations() {
        destinations.removeAll()
    }

    /// Enables or disables logging.
    /// - Parameter enabled: Whether logging should be enabled.
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }

    // MARK: - Logging Methods

    /// Logs a trace-level message.
    public func trace(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .trace, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a debug-level message.
    public func debug(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .debug, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an info-level message.
    public func info(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .info, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a warning-level message.
    public func warning(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .warning, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs an error-level message.
    public func error(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .error, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    /// Logs a critical-level message.
    public func critical(
        _ message: String,
        metadata: LogMetadata? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) async {
        await log(level: .critical, message: message, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Private

    private func log(
        level: LogLevel,
        message: String,
        metadata: LogMetadata?,
        file: String,
        function: String,
        line: Int
    ) async {
        guard isEnabled else { return }

        let logMessage = LogMessage(
            level: level,
            message: message,
            metadata: metadata,
            source: source,
            file: file,
            function: function,
            line: line
        )

        for destination in destinations {
            if await destination.shouldLog(level: level) {
                await destination.log(logMessage)
            }
        }
    }
}
