import Foundation

/// Protocol for log output destinations.
///
/// Destinations receive log messages and output them to their target
/// (console, file, remote service, etc.). All destinations must be actors
/// for thread safety.
public protocol LogDestination: Actor {
    /// The minimum log level this destination will accept.
    nonisolated var minimumLevel: LogLevel { get }

    /// Optional filter for this destination.
    var filter: (any LogFilter)? { get }

    /// Outputs a log message to the destination.
    /// - Parameter message: The message to log.
    func log(_ message: LogMessage) async

    /// Determines if a message at the given level should be logged.
    /// - Parameter level: The log level to check.
    /// - Returns: `true` if the level should be logged.
    func shouldLog(level: LogLevel) async -> Bool

    /// Determines if a message should be logged based on level and filters.
    /// - Parameter message: The log message to check.
    /// - Returns: `true` if the message should be logged.
    func shouldLog(message: LogMessage) async -> Bool
}

/// Default implementation for shouldLog based on minimumLevel.
public extension LogDestination {
    var filter: (any LogFilter)? { nil }

    func shouldLog(level: LogLevel) async -> Bool {
        level >= minimumLevel
    }

    func shouldLog(message: LogMessage) async -> Bool {
        guard message.level >= minimumLevel else { return false }
        if let filter {
            return filter.shouldLog(message)
        }
        return true
    }
}
